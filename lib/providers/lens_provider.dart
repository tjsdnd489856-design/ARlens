import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lens_model.dart';
import '../services/supabase_service.dart';
import '../services/analytics_service.dart';
import '../services/cache_service.dart'; // 캐시 서비스 추가

class LensProvider extends ChangeNotifier {
  List<Lens> _lenses = [];
  Lens? _selectedLens;
  ui.Image? _loadedLensImage;
  bool _isLoading = false;
  bool _isImageLoading = false;

  // 페이지네이션 상태
  int _pageSize = 20;
  bool _hasMore = true;
  String? _currentBrandId;

  // 착용 통계 중복 카운트 방지를 위한 타이머
  final Map<String, DateTime> _lastTryOnTimes = {};
  DateTime? _lensSelectedAt;

  List<Lens> get lenses => _lenses;
  Lens? get selectedLens => _selectedLens;
  ui.Image? get loadedLensImage => _loadedLensImage;
  bool get isLoading => _isLoading;
  bool get isImageLoading => _isImageLoading;
  bool get hasMore => _hasMore;

  SupabaseClient get supabase => SupabaseService.client;

  LensProvider();

  // Supabase 이미지 리사이징 헬퍼 (B2B 대역폭 최적화)
  String getOptimizedThumbnail(String url, {int width = 200, int height = 200}) {
    if (url.isEmpty || !url.contains('supabase.co')) return url;
    // Supabase의 리사이징 파라미터 적용 (?width=X&height=Y&resize=contain)
    return '$url?width=$width&height=$height';
  }

  /// 렌즈 목록 로드 (초기화 및 페이지네이션 대응)
  Future<void> fetchLensesFromSupabase({String? brandId, bool isRefresh = true}) async {
    if (_isLoading) return;
    
    if (isRefresh) {
      _lenses = [];
      _hasMore = true;
      _currentBrandId = brandId;
    }
    
    if (!_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final offset = _lenses.length;
      var query = supabase.from('lenses')
          .select()
          .order('createdAt', ascending: false)
          .range(offset, offset + _pageSize - 1);

      if (_currentBrandId != null && _currentBrandId != 'admin' && _currentBrandId!.isNotEmpty) {
        query = query.eq('brandId', _currentBrandId!);
      }
      
      final response = await query;
      final List<Lens> newLenses = (response as List<dynamic>).map((data) {
        return Lens.fromJson(data as Map<String, dynamic>);
      }).toList();

      if (newLenses.length < _pageSize) {
        _hasMore = false;
      }

      _lenses.addAll(newLenses);
    } catch (e) {
      debugPrint('❌ [Data Error] 렌즈 목록 로드 실패: $e');
      if (isRefresh) _lenses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 더 많은 렌즈 불러오기 (무한 스크롤용)
  Future<void> loadMoreLenses() async {
    await fetchLensesFromSupabase(brandId: _currentBrandId, isRefresh: false);
  }

  /// 렌즈 선택 및 텍스처 메모리 관리
  Future<void> selectLens(Lens? lens, {String? currentBrandId}) async {
    // 1. 이전 텍스처 메모리 해제 (Lifecycle Management)
    if (_loadedLensImage != null) {
      _loadedLensImage!.dispose(); // 명시적 dispose로 메모리 누수 방지
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
      // 2. 지능형 캐시를 통한 원본 텍스처 로딩 (실제 착용 시에만 고화질 스트리밍)
      await _precacheLensImageWithCacheManager(lens.arTextureUrl);
      incrementTryOnCount(lens.id, currentBrandId ?? lens.brandId);
    }
  }

  /// 커스텀 캐시 매니저를 사용한 이미지 로딩
  Future<void> _precacheLensImageWithCacheManager(String url) async {
    _isImageLoading = true;
    notifyListeners();

    try {
      // 1. CacheManager를 통해 파일 가져오기
      final fileInfo = await ARTextureCacheManager.instance.getSingleFile(url);
      final Uint8List bytes = await fileInfo.readAsBytes();
      
      // 2. 바이트 데이터를 ui.Image로 디코딩
      final Completer<ui.Image> completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (ui.Image img) {
        completer.complete(img);
      });
      
      _loadedLensImage = await completer.future;
      print("🎨 [Cache] AR Texture loaded via CacheManager: $url");
    } catch (e) {
      debugPrint('❌ [Cache Error] 렌즈 이미지 로딩 실패: $e');
      _loadedLensImage = null;
    } finally {
      _isImageLoading = false;
      notifyListeners();
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
        
        await supabase.from('lenses').update({
          'try_on_count': currentCount + 1
        }).eq('id', lensId);
        
        await AnalyticsService.instance.logEvent(
          actionType: 'select',
          lensId: lensId,
          brandId: brandId,
        );
      }
    } catch (e) {
      debugPrint('❌ [Insight Error] 통계 증가 실패: $e');
    }
  }

  Future<void> deleteLens(Lens lens) async {
    try {
      await _deleteStorageFileFromUrl(lens.thumbnailUrl);
      await _deleteStorageFileFromUrl(lens.arTextureUrl);
      await supabase.from('lenses').delete().eq('id', lens.id);

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
      debugPrint('❌ [Delete Error]: $e');
      rethrow;
    }
  }

  Future<void> _deleteStorageFileFromUrl(String url) async {
    if (url.isEmpty || !url.contains('lens-assets/')) return;
    try {
      final String path = url.split('lens-assets/').last;
      await supabase.storage.from('lens-assets').remove([path]);
    } catch (e) {
      debugPrint('⚠️ [Storage Error] 삭제 실패: $e');
    }
  }

  Future<void> updateLens(String lensId, Map<String, dynamic> updatedData) async {
    try {
      await supabase.from('lenses').update(updatedData).eq('id', lensId);
      await fetchLensesFromSupabase(brandId: _currentBrandId);
    } catch (e) {
      debugPrint('❌ [Update Error]: $e');
      rethrow;
    }
  }
  
  @override
  void dispose() {
    if (_loadedLensImage != null) {
      _loadedLensImage!.dispose();
    }
    super.dispose();
  }
}
