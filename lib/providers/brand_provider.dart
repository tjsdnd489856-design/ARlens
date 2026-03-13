import 'package:flutter/foundation.dart';
import '../models/brand_model.dart';

class BrandProvider extends ChangeNotifier {
  Brand _currentBrand = Brand.defaultBrand;

  Brand get currentBrand => _currentBrand;

  // 브랜드 변경 함수 (B2B 모드 스위칭)
  void setBrand(Brand brand) {
    _currentBrand = brand;
    notifyListeners();
  }

  // 기본 상태로 복귀
  void resetToDefault() {
    _currentBrand = Brand.defaultBrand;
    notifyListeners();
  }
}
