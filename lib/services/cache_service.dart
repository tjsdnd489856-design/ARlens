import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// AR 전용 지능형 캐시 매니저
/// 렌즈 텍스처를 최대 200MB까지 보관하며, 오래된 순으로 자동 관리합니다.
class ARTextureCacheManager {
  static const key = 'arTextureCacheKey';
  
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7), // 7일간 미사용 시 삭제 대상
      maxNrOfCacheObjects: 200,             // 최대 에셋 개수
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
  
  // 캐시 수동 비우기 (필요 시)
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }
}
