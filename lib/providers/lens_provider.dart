import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lens_model.dart';
import '../services/supabase_service.dart';
import '../services/analytics_service.dart';
import '../services/cache_service.dart'; 
import '../services/audit_service.dart';

/// Isolate에서 실행될 디코딩 함수
Future<ui.Image> _decodeImageIsolate(Uint8List bytes) async {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, (ui.Image img) {
    completer.complete(img);
  });
  return completer.future;
}

class LensProvider extends ChangeNotifier {
  List<Lens> _lenses = [];
  Lens? _selectedLens;
  ui.Image? _loadedLensImage;
  bool _isLoading = false;
  bool _isImageLoading = false; 

  // [Ultimate Golden Master] 리소스 정합성 및 GC 가드
  int _loadingToken = 0;

  final int _pageSize = 20;
  bool _hasMore = true;
  String? _currentBrandId;
  String _currentSearchQuery = '';
  String _currentSortOption = '최신순'; 

  String? _lastCreatedAt;
  String? _lastId;
  String? _lastName;
  int? _lastTryOnCount;

  final Map<String, DateTime> _lastTryOnTimes = {};
  DateTime? _lensSelectedAt;

  List<Lens> get lenses => _lenses;
  Lens? get selectedLens => _selectedLens;
  ui.Image? get loadedLensImage => _loadedLensImage;
  bool get isLoading => _isLoading;
  bool get isImageLoading => _isImageLoading;
  bool get hasMore => _hasMore;
  
  DateTime? get lensSelectedAt => _lensSelectedAt;
  String? get currentBrandId => _currentBrandId;

  SupabaseClient get supabase => SupabaseService.client;

  LensProvider();

  String getOptimizedThumbnail(String url, {int width = 150, int height = 150, int quality = 50}) {
    if (url.isEmpty || !url.contains('supabase.co')) return url;
    return '$url?width=$width&height=$height&quality=$quality&resize=contain';
  }

  String _sanitize(String? value) {
    if (value == null) return '';
    return value.replaceAll("'", "''").replaceAll("(", "\\(").replaceAll(")", "\\)");
  }

  Future<void> fetchLensesFromSupabase({
    String? brandId, 
    String searchQuery = '', 
    String sortOption = '최신순',
    bool isRefresh = true
  }) async {
    if (_isLoading) return;
    
    if (isRefresh) {
      _lenses = [];
      _hasMore = true;
      _currentBrandId = brandId;
      _currentSearchQuery = searchQuery;
      _currentSortOption = sortOption;
      _lastCreatedAt = null;
      _lastId = null;
      _lastName = null;
      _lastTryOnCount = null;
    }
    
    if (!_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      var query = supabase.from('lenses').select();

      if (_currentBrandId != null && _currentBrandId != 'admin' && _currentBrandId!.isNotEmpty) {
        query = query.eq('brandId', _currentBrandId!);
      }

      if (_currentSearchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_currentSearchQuery%');
      }

      if (_lastCreatedAt != null && _lastId != null) {
        final safeDate = _lastCreatedAt!;
        final safeId = _lastId!;
        final safeName = _sanitize(_lastName);
        final safeCount = _lastTryOnCount ?? 0;

        if (_currentSortOption == '최신순') {
          query = query.or('createdAt.lt.$safeDate,and(createdAt.eq.$safeDate,id.lt.$safeId)');
        } else if (_currentSortOption == '이름순') {
          query = query.or('name.gt.$safeName,and(name.eq.$safeName,id.gt.$safeId)');
        } else if (_currentSortOption == '인기순') {
          query = query.or('tryOnCount.lt.$safeCount,and(tryOnCount.eq.$safeCount,id.lt.$safeId)');
        }
      }

      if (_currentSortOption == '이름순') {
        query = query.order('name', ascending: true).order('id', ascending: true);
      } else if (_currentSortOption == '인기순') {
        query = query.order('tryOnCount', ascending: false, nullsFirst: false).order('id', ascending: false);
      } else {
        query = query.order('createdAt', ascending: false).order('id', ascending: false);
      }
      
      final response = await query.limit(_pageSize);

      final List<Lens> newLenses = (response as List<dynamic>).map((data) {
        return Lens.fromJson(data as Map<String, dynamic>);
      }).toList();

      if (newLenses.length < _pageSize) {
        _hasMore = false;
      }

      if (newLenses.isNotEmpty) {
        final last = newLenses.last;
        _lastCreatedAt = last.createdAt;
        _lastId = last.id;
        _lastName = last.name;
        _lastTryOnCount = last.tryOnCount;
      }

      _lenses.addAll(newLenses);
    } catch (e) {
      debugPrint('❌ 데이터 로드 실패: $e');
      if (isRefresh) _lenses = [];
      _hasMore = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreLenses() async {
    await fetchLensesFromSupabase(
      brandId: _currentBrandId, 
      searchQuery: _currentSearchQuery, 
      sortOption: _currentSortOption,
      isRefresh: false
    );
  }

  Future<void> selectLens(Lens? lens, {String? currentBrandId}) async {
    final int requestToken = ++_loadingToken;

    // [GC Guard] 기존 리소스 즉시 해제
    if (_loadedLensImage != null) {
      _loadedLensImage!.dispose();
      _loadedLensImage = null;
    }

    if (_selectedLens != null && _selectedLens?.id != lens?.id) {
      if (_lensSelectedAt != null) {
        final durationMs = DateTime.now().difference(_lensSelectedAt!).inMilliseconds;
        AnalyticsService.instance.logEvent(
          actionType: 'unselect',
          lensId: _selectedLens!.id,
          brandId: currentBrandId,
          durationMs: durationMs,
        );
      }
    }

    if (_selectedLens?.id == lens?.id && lens != null) return;

    _selectedLens = lens;
    _lensSelectedAt = lens != null ? DateTime.now() : null;
    notifyListeners();

    if (lens != null && lens.arTextureUrl.isNotEmpty) {
      await _precacheLensImageWithCacheManager(lens.arTextureUrl, requestToken);
      incrementTryOnCount(lens.id, currentBrandId ?? lens.brandId);
    }
  }

  /// [Ultimate Golden Master] Isolate 디코딩 및 명시적 리소스 관리
  Future<void> _precacheLensImageWithCacheManager(String url, int token) async {
    _isImageLoading = true;
    notifyListeners();

    try {
      final fileInfo = await ARTextureCacheManager.instance.getSingleFile(url);
      final Uint8List bytes = await fileInfo.readAsBytes();
      
      // [Master Point] compute를 활용한 Isolate 디코딩 (UI Jank 방지)
      final ui.Image decodedImage = await compute(_decodeImageIsolate, bytes);

      // [Master Guard] 토큰 검증 및 즉시 해제
      if (token == _loadingToken && _selectedLens?.arTextureUrl == url) {
        _loadedLensImage = decodedImage;
        debugPrint('✅ [Master Guard] Sequential resource synced.');
      } else {
        // 유효하지 않은 이미지 즉시 해제하여 OOM 방지
        decodedImage.dispose();
        debugPrint('⚠️ [Master Guard] Outdated resource disposed.');
      }
    } catch (e) {
      debugPrint('❌ 리소스 로딩 실패: $e');
      _loadedLensImage = null;
    } finally {
      if (token == _loadingToken) {
        _isImageLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> incrementTryOnCount(String lensId, String? brandId) async {
    final now = DateTime.now();
    final lastTime = _lastTryOnTimes[lensId];
    if (lastTime != null && now.difference(lastTime).inSeconds < 3) return;
    _lastTryOnTimes[lensId] = now;

    try {
      final index = _lenses.indexWhere((l) => l.id == lensId);
      if (index != -1) {
        final currentCount = _lenses[index].tryOnCount;
        _lenses[index] = _lenses[index].copyWith(tryOnCount: currentCount + 1);
        notifyListeners();
        
        await supabase.from('lenses').update({'tryOnCount': currentCount + 1}).eq('id', lensId);
        await AnalyticsService.instance.logEvent(actionType: 'select', lensId: lensId, brandId: brandId);
      }
    } catch (e) {
      debugPrint('❌ 통계 업데이트 실패: $e');
    }
  }

  Future<void> deleteLens(Lens lens) async {
    try {
      final oldData = lens.toJson();
      await _deleteStorageFileFromUrl(lens.thumbnailUrl);
      await _deleteStorageFileFromUrl(lens.arTextureUrl);
      await supabase.from('lenses').delete().eq('id', lens.id);
      
      await AuditService.instance.logAdminAction(action: 'DELETE_LENS', targetId: lens.id, oldData: oldData);

      _lenses.removeWhere((l) => l.id == lens.id);
      if (_selectedLens?.id == lens.id) {
        _selectedLens = null;
        if (_loadedLensImage != null) {
          _loadedLensImage!.dispose();
          _loadedLensImage = null;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 삭제 실패: $e');
      rethrow;
    }
  }

  Future<void> _deleteStorageFileFromUrl(String url) async {
    if (url.isEmpty || !url.contains('lens-assets/')) return;
    try {
      final String path = url.split('lens-assets/').last;
      await supabase.storage.from('lens-assets').remove([path]);
    } catch (e) {
      debugPrint('⚠️ [Storage] 삭제 실패: $e');
    }
  }

  void clear() {
    _lenses = [];
    _selectedLens = null;
    _loadingToken++; 
    if (_loadedLensImage != null) {
      _loadedLensImage!.dispose();
      _loadedLensImage = null;
    }
    _isLoading = false;
    _isImageLoading = false;
    _hasMore = true;
    _currentBrandId = null;
    _currentSearchQuery = '';
    _currentSortOption = '최신순';
    _lastCreatedAt = null;
    _lastId = null;
    _lastName = null;
    _lastTryOnCount = null;
    _lensSelectedAt = null; 
    notifyListeners();
  }
}
