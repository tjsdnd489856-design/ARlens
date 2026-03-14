import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; 
import '../providers/user_provider.dart';
import '../providers/brand_provider.dart';
import '../providers/lens_provider.dart';
import '../providers/store_provider.dart';
import 'analytics_service.dart';
import 'geocoding_service.dart';
import 'supabase_service.dart';

// [Final Golden Master] 전역 빌드 컨텍스트 상수 참조 (main.dart와 동일)
const String _buildBrandId = String.fromEnvironment('BRAND_ID', defaultValue: 'default');

class GlobalResetService {
  /// [Final Golden Master] 원자적 초기화 및 빌드 컨텍스트(buildBrandId) 복구
  static Future<void> resetAll(BuildContext context) async {
    debugPrint('🔄 [GlobalResetService] Initiating Golden Master Sequence...');
    
    // 1. Supabase 로그아웃 우선 완료 (통신 안정성)
    try {
      await SupabaseService.client.auth.signOut();
    } catch (e) {
      debugPrint('⚠️ [Auth] Sign out error: $e');
    }
    
    // 2. 엔진 레벨 메모리 정화
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // 3. 디스크 캐시 정화
    await DefaultCacheManager().emptyCache();
    
    // 4. Provider 상태 초기화 및 빌드 아이덴티티 복구
    // [Golden Master] 파라미터가 없어도 시스템 초기 빌드 브랜드를 찾아 자동 복구
    context.read<UserProvider>().clear();
    context.read<BrandProvider>().clear();
    await context.read<BrandProvider>().initializeWithBrandId(_buildBrandId);
    
    context.read<LensProvider>().clear();
    context.read<StoreProvider>().clear();

    // 5. 싱글톤 서비스 리셋
    AnalyticsService.instance.reset();
    GeocodingService.instance.clearCache();
    
    debugPrint('✅ [GlobalResetService] Context restored to: $_buildBrandId');
  }
}
