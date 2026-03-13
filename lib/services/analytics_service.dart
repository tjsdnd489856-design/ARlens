import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';

/// 딥 트래킹(Deep Tracking) 엔진: 사용자의 정밀 행동 데이터를 수집하는 서비스
class AnalyticsService {
  AnalyticsService._privateConstructor();
  static final AnalyticsService _instance = AnalyticsService._privateConstructor();
  static AnalyticsService get instance => _instance;

  SupabaseClient get supabase => SupabaseService.client;
  String? _anonymousId;

  /// 익명 사용자용 고유 ID 발급 및 캐싱
  Future<String> _getAnonymousId() async {
    if (_anonymousId != null) return _anonymousId!;
    
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('anonymous_device_id');
    
    if (storedId == null) {
      storedId = const Uuid().v4();
      await prefs.setString('anonymous_device_id', storedId);
    }
    
    _anonymousId = storedId;
    return _anonymousId!;
  }

  /// 행동 로그 기록
  /// [actionType]의 예: 'select'(렌즈 착용), 'capture'(사진 촬영), 'long_press'(상세보기)
  /// [durationMs]: 행동 지속 시간(밀리초), 예: 렌즈를 착용하고 있던 시간
  Future<void> logEvent({
    required String actionType,
    String? lensId,
    String? brandId,
    int? durationMs,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      final anonId = await _getAnonymousId();
      
      await supabase.from('activity_logs').insert({
        'user_id': user?.id,
        'anonymous_id': user == null ? anonId : null,
        'lens_id': lensId,
        'brand_id': brandId,
        'action_type': actionType,
        'duration_ms': durationMs ?? 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('📈 [Analytics] Event: $actionType | Lens: $lensId | Duration: ${durationMs}ms');
    } catch (e) {
      debugPrint('❌ [Analytics] Event Logging Failed: $e');
    }
  }
}
