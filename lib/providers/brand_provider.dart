import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http; 
import '../models/brand_model.dart';
import '../services/supabase_service.dart';

class BrandProvider extends ChangeNotifier {
  Brand _currentBrand = Brand.defaultBrand;
  bool _isInitialized = false;
  Uint8List? _cachedLogoBytes; 

  Brand get currentBrand => _currentBrand;
  bool get isInitialized => _isInitialized;
  Uint8List? get cachedLogoBytes => _cachedLogoBytes; 

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
        if (_currentBrand.logoUrl != null && _currentBrand.logoUrl!.isNotEmpty) {
          await _cacheLogo(_currentBrand.logoUrl!);
        }
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

  Future<void> _cacheLogo(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        _cachedLogoBytes = response.bodyBytes;
        debugPrint('✅ [BrandProvider] 로고 메모리 캐싱 완료');
      }
    } catch (e) {
      debugPrint('⚠️ [BrandProvider] 로고 캐싱 실패: $e');
    }
  }

  Future<void> savePushTemplate(String title, String body) async {
    final List<Map<String, String>> updatedTemplates = List.from(_currentBrand.pushTemplates);
    updatedTemplates.add({'title': title, 'body': body});
    try {
      await supabase.from('brands').update({'push_templates': updatedTemplates}).eq('id', _currentBrand.id);
      _currentBrand = _currentBrand.copyWith(pushTemplates: updatedTemplates);
      notifyListeners();
    } catch (e) { rethrow; }
  }

  Future<void> deletePushTemplate(int index) async {
    final List<Map<String, String>> updatedTemplates = List.from(_currentBrand.pushTemplates);
    updatedTemplates.removeAt(index);
    try {
      await supabase.from('brands').update({'push_templates': updatedTemplates}).eq('id', _currentBrand.id);
      _currentBrand = _currentBrand.copyWith(pushTemplates: updatedTemplates);
      notifyListeners();
    } catch (e) { rethrow; }
  }

  void setBrand(Brand brand) {
    _currentBrand = brand;
    if (brand.logoUrl != null) _cacheLogo(brand.logoUrl!);
    notifyListeners();
  }

  // [Grand Completion] 호환성을 위해 다시 추가 및 clear 연동
  void resetToDefault() {
    clear();
  }

  void clear() {
    _currentBrand = Brand.defaultBrand;
    _isInitialized = false;
    _cachedLogoBytes = null;
    notifyListeners();
  }
}
