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

    try {
      final response = await supabase.from('lenses').select();

      _lenses = (response as List<dynamic>).map((data) {
        return Lens.fromJson(data as Map<String, dynamic>);
      }).toList();

      if (_lenses.isEmpty) {
        debugPrint('Supabase에 렌즈 데이터가 없습니다. 더미 데이터를 주입합니다.');
        _lenses = _getDummyLenses();
      } else {
        print("🎉 [Data] Lenses fetched successfully: ${_lenses.length}");
      }
    } catch (e) {
      debugPrint('❌ [Data Error] 데이터를 가져오는 중 에러 발생: $e');
      _lenses = _getDummyLenses();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 렌즈 삭제 기능 추가
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

  List<Lens> _getDummyLenses() {
    return [
      Lens(
        id: 'dummy_1',
        name: '체리밤 핑크 (더미)',
        description: '통통 튀는 핫핑크 Y2K 감성 필터',
        tags: ['Y2K', 'Pink'],
        thumbnailUrl:
            'https://via.placeholder.com/150/FF1493/FFFFFF?text=Cherry',
        arTextureUrl: '',
      ),
      Lens(
        id: 'dummy_2',
        name: '네온 블루 (더미)',
        description: '사이버펑크 느낌의 파란색 필터',
        tags: ['Neon', 'Blue'],
        thumbnailUrl: 'https://via.placeholder.com/150/0000FF/FFFFFF?text=Neon',
        arTextureUrl: '',
      ),
      Lens(
        id: 'dummy_3',
        name: '사이버 그레이 (더미)',
        description: '세련된 메탈릭 그레이 필터',
        tags: ['Metallic', 'Gray'],
        thumbnailUrl:
            'https://via.placeholder.com/150/808080/FFFFFF?text=Cyber',
        arTextureUrl: '',
      ),
    ];
  }

  void selectLens(Lens lens) {
    _selectedLens = lens;
    notifyListeners();
  }
}
