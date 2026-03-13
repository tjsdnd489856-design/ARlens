import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lens_model.dart';
import '../services/supabase_service.dart';
import '../services/analytics_service.dart'; // 딥 트래킹 엔진 추가

class LensProvider extends ChangeNotifier {
  List<Lens> _lenses = [];
  Lens? _selectedLens;
  ui.Image? _loadedLensImage;
  bool _isLoading = false;
  bool _isImageLoading = false;

  // 착용 통계 중복 카운트 방지를 위한 타이머 (디바이스 로컬 상태)
  final Map<String, DateTime> _lastTryOnTimes = {};

  List<Lens> get lenses => _lenses;
  Lens? get selectedLens => _selectedLens;
  ui.Image? get loadedLensImage => _loadedLensImage;
  bool get isLoading => _isLoading;
  bool get isImageLoading => _isImageLoading;

  SupabaseClient get supabase => SupabaseService.client;

  LensProvider();

  Future<void> fetchLensesFromSupabase() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await supabase.from('lenses').select();
      _lenses = (response as List<dynamic>).map((data) {
        return Lens.fromJson(data as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      debugPrint('❌ [Data Error] 렌즈 목록 로드 실패: $e');
      _lenses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectLens(Lens? lens) async {
    if (_selectedLens?.id == lens?.id) return;

    _selectedLens = lens;
    _loadedLensImage = null;
    notifyListeners();

    if (lens != null && lens.arTextureUrl.isNotEmpty) {
      await _precacheLensImage(lens.arTextureUrl);
      
      // 렌즈가 선택되어 화면에 로드될 때 착용 횟수 증가 로직 호출
      incrementTryOnCount(lens.id, lens.brandId);
    }
  }

  // 실시간 렌즈 착용 통계 로직 및 딥 트래킹 기록
  Future<void> incrementTryOnCount(String lensId, String? brandId) async {
    final now = DateTime.now();
    final lastTime = _lastTryOnTimes[lensId];
    
    // 중복 클릭 방지 (3초 이내 같은 렌즈 재선택 시 카운트 안 함)
    if (lastTime != null && now.difference(lastTime).inSeconds < 3) {
      return;
    }
    _lastTryOnTimes[lensId] = now;

    try {
      // 1. 로컬 상태 먼저 업데이트하여 UI 즉각 반응
      final index = _lenses.indexWhere((l) => l.id == lensId);
      if (index != -1) {
        final currentCount = _lenses[index].tryOnCount;
        _lenses[index] = _lenses[index].copyWith(tryOnCount: currentCount + 1);
        notifyListeners();
        
        // 2. 서버 업데이트 (기존 카운트 증가 로직)
        await supabase.from('lenses').update({
          'try_on_count': currentCount + 1
        }).eq('id', lensId);
        
        // 3. [신규] 딥 트래킹 엔진을 통한 상세 활동 로그 기록
        await AnalyticsService.instance.logEvent(
          actionType: 'try_on',
          lensId: lensId,
          brandId: brandId,
        );
        
        debugPrint('📊 [Insight] 렌즈 착용 통계 및 로깅 완료 ($lensId: ${currentCount + 1})');
      }
    } catch (e) {
      debugPrint('❌ [Insight Error] 착용 통계 증가 실패: $e');
    }
  }

  // [수정] Web/Mobile 모두 호환되는 표준 ImageStream 방식 채택
  Future<void> _precacheLensImage(String url) async {
    _isImageLoading = true;
    notifyListeners();

    try {
      final ImageProvider provider = NetworkImage(url);
      final ImageStream stream = provider.resolve(ImageConfiguration.empty);
      final Completer<ui.Image> completer = Completer<ui.Image>();
      
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          completer.complete(info.image);
          stream.removeListener(listener);
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          completer.completeError(exception, stackTrace);
          stream.removeListener(listener);
        },
      );

      stream.addListener(listener);
      _loadedLensImage = await completer.future;
      print("🎨 [Cache] AR Texture loaded successfully (Standard): $url");
    } catch (e) {
      debugPrint('❌ [Cache Error] 렌즈 이미지 캐싱 실패: $e');
      _loadedLensImage = null;
    } finally {
      _isImageLoading = false;
      notifyListeners();
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
        _loadedLensImage = null;
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
      debugPrint('⚠️ [Storage Error] 삭제 실패 무시: $e');
    }
  }

  Future<void> updateLens(String lensId, Map<String, dynamic> updatedData) async {
    try {
      await supabase.from('lenses').update(updatedData).eq('id', lensId);
      await fetchLensesFromSupabase();
    } catch (e) {
      debugPrint('❌ [Update Error]: $e');
      rethrow;
    }
  }
}
