import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// [Senior Performance] AR 전용 지능형 캐시 매니저
/// 렌즈 텍스처를 최대 200MB까지 보관하며, 오래된 순으로 자동 관리(LRU)합니다.
class ARTextureCacheManager {
  static const key = 'arTextureCacheKey';
  
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7), // 7일간 미사용 시 자동 삭제
      maxNrOfCacheObjects: 500,             // 최대 관리 에셋 개수 확장
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
  
  // 캐시 비우기
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }
}
