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

    // 4. 로그 확인: 동기화 로그 추가
    print("📡 [Sync] Fetching latest lenses from DB...");

    try {
      final response = await supabase.from('lenses').select();

      _lenses = (response as List<dynamic>).map((data) {
        return Lens.fromJson(data as Map<String, dynamic>);
      }).toList();

      // 2. 빈 데이터 처리: 더미 데이터 로직 완전히 제거
      if (_lenses.isEmpty) {
        debugPrint('Supabase에 렌즈 데이터가 없습니다.');
      } else {
        print("🎉 [Data] Lenses fetched successfully: ${_lenses.length}");
      }
    } catch (e) {
      debugPrint('❌ [Data Error] 데이터를 가져오는 중 에러 발생: $e');
      _lenses = []; // 에러 시 빈 리스트로 초기화
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. 삭제 후 즉시 반영: deleteLens 로직 보강
  Future<void> deleteLens(String lensId) async {
    try {
      await supabase.from('lenses').delete().eq('id', lensId);
      // 리스트에서 즉시 제거하여 UI 반영
      _lenses.removeWhere((l) => l.id == lensId);
      if (_selectedLens?.id == lensId) _selectedLens = null;
      notifyListeners();
      print("✅ [Data] Lens deleted successfully: $lensId");
    } catch (e) {
      debugPrint('❌ [Delete Error] 렌즈 삭제 중 에러 발생: $e');
      rethrow;
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

  // 더미 데이터 생성 로직 삭제 (사용하지 않음)

  void selectLens(Lens lens) {
    _selectedLens = lens;
    notifyListeners();
  }
}
