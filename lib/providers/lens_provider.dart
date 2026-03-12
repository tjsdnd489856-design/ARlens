import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lens_model.dart';
import '../services/supabase_service.dart';

class LensProvider extends ChangeNotifier {
  List<Lens> _lenses = [];
  Lens? _selectedLens;
  bool _isLoading = false;

  List<Lens> get lenses => _lenses;
  Lens? get selectedLens => _selectedLens;
  bool get isLoading => _isLoading;

  SupabaseClient get supabase => SupabaseService.client;

  LensProvider();

  Future<void> fetchLensesFromSupabase() async {
    _isLoading = true;
    notifyListeners();

    print("📡 [Sync] Fetching latest lenses from DB...");

    try {
      final response = await supabase.from('lenses').select();

      _lenses = (response as List<dynamic>).map((data) {
        return Lens.fromJson(data as Map<String, dynamic>);
      }).toList();

      if (_lenses.isEmpty) {
        debugPrint('Supabase에 렌즈 데이터가 없습니다.');
      } else {
        print("🎉 [Data] Lenses fetched successfully: ${_lenses.length}");
      }
    } catch (e) {
      debugPrint('❌ [Data Error] 데이터를 가져오는 중 에러 발생: $e');
      _lenses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 렌즈 및 관련 스토리지 파일 삭제
  Future<void> deleteLens(Lens lens) async {
    try {
      // 1. Storage에서 이미지 파일들 삭제 시도
      await _deleteStorageFileFromUrl(lens.thumbnailUrl);
      await _deleteStorageFileFromUrl(lens.arTextureUrl);

      // 2. DB에서 데이터 삭제
      await supabase.from('lenses').delete().eq('id', lens.id);

      // 3. UI 갱신
      _lenses.removeWhere((l) => l.id == lens.id);
      if (_selectedLens?.id == lens.id) _selectedLens = null;
      notifyListeners();

      print("✅ [Storage/DB] Lens and assets deleted successfully: ${lens.id}");
    } catch (e) {
      debugPrint('❌ [Delete Error] 렌즈/에셋 삭제 중 에러 발생: $e');
      rethrow;
    }
  }

  // URL에서 스토리지 경로를 추출하여 파일을 삭제하는 헬퍼 함수
  Future<void> _deleteStorageFileFromUrl(String url) async {
    if (url.isEmpty || !url.contains('lens-assets/')) return;

    try {
      // URL에서 파일 경로 부분만 추출합니다.
      // 예: .../public/lens-assets/thumbnails/123_asset.png -> thumbnails/123_asset.png
      final String path = url.split('lens-assets/').last;

      print("🗑️ [Storage] 파일 삭제 시도: $path");
      await supabase.storage.from('lens-assets').remove([path]);
    } catch (e) {
      debugPrint('⚠️ [Storage Error] 파일 삭제 실패 (무시됨): $e');
    }
  }

  // 렌즈 정보 수정 기능 추가
  Future<void> updateLens(
    String lensId,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      await supabase.from('lenses').update(updatedData).eq('id', lensId);
      // 로컬 데이터 갱신을 위해 다시 불러오기
      await fetchLensesFromSupabase();
      print("✅ [Data] Lens updated successfully: $lensId");
    } catch (e) {
      debugPrint('❌ [Update Error] 렌즈 수정 중 에러 발생: $e');
      rethrow;
    }
  }

  void selectLens(Lens lens) {
    _selectedLens = lens;
    notifyListeners();
  }
}
