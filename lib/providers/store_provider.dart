import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store_model.dart';
import '../services/supabase_service.dart';

class StoreProvider extends ChangeNotifier {
  List<Store> _stores = [];
  bool _isLoading = false;

  List<Store> get stores => _stores;
  bool get isLoading => _isLoading;

  SupabaseClient get supabase => SupabaseService.client;

  // 특정 브랜드의 매장 목록 가져오기
  Future<void> fetchStores({String? brandId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      var query = supabase.from('stores').select();
      if (brandId != null && brandId.isNotEmpty && brandId != 'admin') {
        query = query.eq('brand_id', brandId);
      }
      
      final response = await query;
      _stores = (response as List<dynamic>).map((data) {
        return Store.fromJson(data as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      debugPrint('❌ [Store Error] 매장 목록 로드 실패: $e');
      _stores = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 매장 등록
  Future<void> addStore(Map<String, dynamic> storeData) async {
    try {
      await supabase.from('stores').insert(storeData);
      await fetchStores(brandId: storeData['brand_id']);
    } catch (e) {
      debugPrint('❌ [Store Error] 매장 등록 실패: $e');
      rethrow;
    }
  }

  // 매장 수정
  Future<void> updateStore(String id, Map<String, dynamic> updatedData, {String? brandId}) async {
    try {
      await supabase.from('stores').update(updatedData).eq('id', id);
      await fetchStores(brandId: brandId);
    } catch (e) {
      debugPrint('❌ [Store Error] 매장 수정 실패: $e');
      rethrow;
    }
  }

  // 매장 삭제
  Future<void> deleteStore(String id, {String? brandId}) async {
    try {
      await supabase.from('stores').delete().eq('id', id);
      _stores.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [Store Error] 매장 삭제 실패: $e');
      rethrow;
    }
  }
}
