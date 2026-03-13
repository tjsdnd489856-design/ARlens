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

  // [신규] 빌드 타임에 주입된 BRAND_ID로 초기화
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

  void setBrand(Brand brand) {
    _currentBrand = brand;
    notifyListeners();
  }

  void resetToDefault() {
    _currentBrand = Brand.defaultBrand;
    notifyListeners();
  }
}
