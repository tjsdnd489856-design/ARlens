import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart'; 
import '../models/store_model.dart';
import '../services/supabase_service.dart';

class StoreProvider extends ChangeNotifier {
  List<Store> _stores = [];
  bool _isLoading = false;

  List<Store> get stores => _stores;
  bool get isLoading => _isLoading;

  SupabaseClient get supabase => SupabaseService.client;

  Future<void> fetchStores({String? brandId, Position? userPosition}) async {
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

      if (userPosition != null) {
        _stores.sort((a, b) {
          double distanceA = Geolocator.distanceBetween(
            userPosition.latitude, userPosition.longitude, a.latitude, a.longitude
          );
          double distanceB = Geolocator.distanceBetween(
            userPosition.latitude, userPosition.longitude, b.latitude, b.longitude
          );
          return distanceA.compareTo(distanceB);
        });
        debugPrint('📍 [O2O] 매장 목록 거리순 정렬 완료');
      }
    } catch (e) {
      debugPrint('❌ [Store Error] 매장 목록 로드 실패: $e');
      _stores = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStore(Map<String, dynamic> storeData) async {
    try {
      await supabase.from('stores').insert(storeData);
      await fetchStores(brandId: storeData['brand_id']);
    } catch (e) {
      debugPrint('❌ [Store Error] 매장 등록 실패: $e');
      rethrow;
    }
  }

  Future<void> updateStore(String id, Map<String, dynamic> updatedData, {String? brandId}) async {
    try {
      await supabase.from('stores').update(updatedData).eq('id', id);
      await fetchStores(brandId: brandId);
    } catch (e) {
      debugPrint('❌ [Store Error] 매장 수정 실패: $e');
      rethrow;
    }
  }

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

  /// [신규] 상태 초기화 (로그아웃 시 사용)
  void clear() {
    _stores = [];
    _isLoading = false;
    notifyListeners();
  }
}
