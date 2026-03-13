import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// 딥 트래킹(Deep Tracking) 엔진: 사용자의 정밀 행동 데이터를 수집하는 서비스
class AnalyticsService {
  // 싱글톤(Singleton) 패턴 적용
  AnalyticsService._privateConstructor();
  static final AnalyticsService _instance = AnalyticsService._privateConstructor();
  static AnalyticsService get instance => _instance;

  SupabaseClient get supabase => SupabaseService.client;

  /// 행동 로그 기록
  /// [actionType]의 예: 'try_on'(렌즈 착용), 'capture'(사진 촬영), 'share'(공유), 'view_detail'(상세 보기)
  Future<void> logEvent({
    required String actionType,
    String? lensId,
    String? brandId,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      
      await supabase.from('activity_logs').insert({
        'user_id': user?.id,
        'lens_id': lensId,
        'brand_id': brandId,
        'action_type': actionType,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('📈 [Analytics] Event Logged: $actionType (Lens: $lensId, Brand: $brandId)');
    } catch (e) {
      debugPrint('❌ [Analytics] Event Logging Failed: $e');
    }
  }
}
