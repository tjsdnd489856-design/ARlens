import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/brand_model.dart';
import '../services/supabase_service.dart';
import '../services/audit_service.dart';

class BrandProvider extends ChangeNotifier {
  Brand _currentBrand = Brand(id: 'default', name: 'ARlens', primaryColor: Colors.pinkAccent);
  bool _isInitialized = false;
  
  // [Final v2] 시뮬레이션 종료 시 잔상 제거를 위한 캐시 관리
  Uint8List? _cachedLogoBytes;

  Brand get currentBrand => _currentBrand;
  bool get isInitialized => _isInitialized;
  Uint8List? get cachedLogoBytes => _cachedLogoBytes;

  SupabaseClient get supabase => SupabaseService.client;

  Future<void> initializeWithBrandId(String brandId) async {
    if (brandId == 'admin') {
      _currentBrand = Brand(id: 'admin', name: 'ARlens Admin', primaryColor: Colors.deepPurple);
      _isInitialized = true;
      notifyListeners();
      return;
    }

    try {
      final data = await supabase.from('brands').select().eq('id', brandId).maybeSingle();
      if (data != null) {
        _currentBrand = Brand.fromJson(data);
        if (_currentBrand.logoUrl != null) {
          // 로고 바이트 선제적 캐싱
          // _cachedLogoBytes = await ... (네트워크 로드 로직)
        }
      }
    } catch (e) {
      debugPrint('❌ 브랜드 초기화 실패: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void setBrand(Brand brand) {
    _currentBrand = brand;
    notifyListeners();
  }

  /// [Final v2] 시뮬레이션 종료 및 모든 메모리 잔상 강제 소거
  void resetToOriginal(Brand originalBrand) {
    _currentBrand = originalBrand;
    _cachedLogoBytes = null; // 파트너사 로고 잔상 제거
    notifyListeners();
    debugPrint('🎨 [Brand] Simulation context fully cleared.');
  }

  Future<void> savePushTemplate(String title, String body) async {
    final List<Map<String, String>> updated = List.from(_currentBrand.pushTemplates);
    updated.add({'title': title, 'body': body});
    
    try {
      await supabase.from('brands').update({'pushTemplates': updated}).eq('id', _currentBrand.id);
      _currentBrand = _currentBrand.copyWith(pushTemplates: updated);
      await AuditService.instance.logAdminAction(action: 'SAVE_PUSH_TEMPLATE', targetId: _currentBrand.id, details: {'title': title});
      notifyListeners();
    } catch (e) { debugPrint('❌ 템플릿 저장 실패: $e'); }
  }

  Future<void> deletePushTemplate(int index) async {
    final List<Map<String, String>> updated = List.from(_currentBrand.pushTemplates);
    final removed = updated.removeAt(index);
    try {
      await supabase.from('brands').update({'pushTemplates': updated}).eq('id', _currentBrand.id);
      _currentBrand = _currentBrand.copyWith(pushTemplates: updated);
      await AuditService.instance.logAdminAction(action: 'DELETE_PUSH_TEMPLATE', targetId: _currentBrand.id, details: {'title': removed['title']});
      notifyListeners();
    } catch (e) { debugPrint('❌ 템플릿 삭제 실패: $e'); }
  }

  void clear() {
    _currentBrand = Brand(id: 'default', name: 'ARlens', primaryColor: Colors.pinkAccent);
    _cachedLogoBytes = null;
    _isInitialized = false;
    notifyListeners();
  }
}
