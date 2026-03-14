import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/store_model.dart';
import '../services/supabase_service.dart';
import '../services/audit_service.dart';

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
      if (brandId != null && brandId != 'admin') {
        query = query.eq('brandId', brandId);
      }
      
      final response = await query;
      final List<Store> fetchedStores = (response as List).map((data) => Store.fromJson(data)).toList();

      if (userPosition != null) {
        fetchedStores.sort((a, b) {
          double distA = Geolocator.distanceBetween(userPosition.latitude, userPosition.longitude, a.latitude, a.longitude);
          double distB = Geolocator.distanceBetween(userPosition.latitude, userPosition.longitude, b.latitude, b.longitude);
          return distA.compareTo(distB);
        });
      } else {
        fetchedStores.sort((a, b) => a.name.compareTo(b.name));
      }

      _stores = fetchedStores;
    } catch (e) {
      debugPrint('❌ 매장 로드 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStore(Map<String, dynamic> storeData) async {
    try {
      final resp = await supabase.from('stores').insert(storeData).select().single();
      _stores.add(Store.fromJson(resp));
      
      await AuditService.instance.logAdminAction(
        action: 'CREATE_STORE', 
        targetId: resp['id'].toString(), 
        newData: storeData
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 매장 추가 실패: $e');
    }
  }

  Future<void> updateStore(String id, Map<String, dynamic> storeData, {String? brandId}) async {
    try {
      final targetStore = _stores.firstWhere((s) => s.id == id);
      final oldData = targetStore.toJson();

      await supabase.from('stores').update(storeData).eq('id', id);
      
      await AuditService.instance.logAdminAction(
        action: 'UPDATE_STORE', 
        targetId: id, 
        oldData: oldData,
        newData: storeData
      );
      
      await fetchStores(brandId: brandId);
    } catch (e) {
      debugPrint('❌ 매장 수정 실패: $e');
    }
  }

  /// [The Platinum 100%] 매장 삭제 전 전체 데이터 백업 로깅
  Future<void> deleteStore(String id) async {
    try {
      final targetStore = _stores.firstWhere((s) => s.id == id);
      final oldData = targetStore.toJson();

      await supabase.from('stores').delete().eq('id', id);
      
      // [Audit] 삭제 직전의 스냅샷을 백업 기록
      await AuditService.instance.logAdminAction(
        action: 'DELETE_STORE', 
        targetId: id, 
        oldData: oldData
      );
      
      _stores.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 매장 삭제 실패: $e');
    }
  }

  void clear() {
    _stores = [];
    notifyListeners();
  }
}
