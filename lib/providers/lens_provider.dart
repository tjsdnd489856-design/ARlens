import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lens_model.dart';

class LensProvider extends ChangeNotifier {
  List<Lens> _lenses = [];
  Lens? _selectedLens;
  bool _isLoading = false;

  List<Lens> get lenses => _lenses;
  Lens? get selectedLens => _selectedLens;
  bool get isLoading => _isLoading;

  // Supabase 클라이언트를 lazy하게 가져오도록 getter 설정
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      return null;
    }
  }

  LensProvider() {
    fetchLensesFromSupabase();
  }

  Future<void> fetchLensesFromSupabase() async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase가 초기화되지 않았습니다.');
      }

      final response = await client.from('Lenses').select();

      _lenses = (response as List<dynamic>).map((data) {
        final mapData = data as Map<String, dynamic>;
        mapData['id'] =
            mapData['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        return Lens.fromJson(mapData);
      }).toList();

      if (_lenses.isEmpty) {
        debugPrint('Supabase에 렌즈 데이터가 없습니다. 더미 데이터를 주입합니다.');
        _lenses = _getDummyLenses();
      } else {
        debugPrint('Supabase 렌즈 데이터 로딩 완료: ${_lenses.length}개');
      }
    } catch (e) {
      debugPrint('Supabase 렌즈 가져오기 에러 (더미 데이터로 대체): $e');
      _lenses = _getDummyLenses();
    } finally {
      _isLoading = false;
      notifyListeners();
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
