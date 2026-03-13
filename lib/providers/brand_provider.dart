import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/brand_model.dart';
import '../services/supabase_service.dart';

class BrandProvider extends ChangeNotifier {
  Brand _currentBrand = Brand.defaultBrand;
  bool _isInitialized = false;

  Brand get currentBrand => _currentBrand;
  bool get isInitialized => _isInitialized;

  SupabaseClient get supabase => SupabaseService.client;

  Future<void> initializeWithBrandId(String brandId) async {
    if (brandId.isEmpty || brandId == 'default') {
      _currentBrand = Brand.defaultBrand;
      _isInitialized = true;
      notifyListeners();
      return;
    }

    try {
      final response = await supabase
          .from('brands')
          .select()
          .eq('id', brandId)
          .maybeSingle();

      if (response != null) {
        _currentBrand = Brand.fromJson(response);
      } else {
        _currentBrand = Brand.defaultBrand;
      }
    } catch (e) {
      debugPrint('❌ [BrandProvider] 초기화 실패: $e');
      _currentBrand = Brand.defaultBrand;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // [V1.1] 푸시 템플릿 저장 (Supabase 동기화)
  Future<void> savePushTemplate(String title, String body) async {
    final List<Map<String, String>> updatedTemplates = List.from(_currentBrand.pushTemplates);
    updatedTemplates.add({'title': title, 'body': body});
    
    try {
      await supabase.from('brands').update({
        'push_templates': updatedTemplates
      }).eq('id', _currentBrand.id);
      
      _currentBrand = _currentBrand.copyWith(pushTemplates: updatedTemplates);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [BrandProvider] 템플릿 저장 실패: $e');
      rethrow;
    }
  }

  // [V1.1] 푸시 템플릿 삭제
  Future<void> deletePushTemplate(int index) async {
    final List<Map<String, String>> updatedTemplates = List.from(_currentBrand.pushTemplates);
    updatedTemplates.removeAt(index);
    
    try {
      await supabase.from('brands').update({
        'push_templates': updatedTemplates
      }).eq('id', _currentBrand.id);
      
      _currentBrand = _currentBrand.copyWith(pushTemplates: updatedTemplates);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [BrandProvider] 템플릿 삭제 실패: $e');
      rethrow;
    }
  }

  void setBrand(Brand brand) {
    _currentBrand = brand;
    notifyListeners();
  }

  void resetToDefault() {
    _currentBrand = Brand.defaultBrand;
    notifyListeners();
  }
}
