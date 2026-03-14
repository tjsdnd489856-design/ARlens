import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuditService {
  static final AuditService instance = AuditService._internal();
  AuditService._internal();

  SupabaseClient get supabase => SupabaseService.client;

  /// [Ultimate Golden Master] DB 타입 충돌 방지를 위한 명시적 직렬화 (JSONB 대응)
  Future<void> logAdminAction({
    required String action,
    required String targetId,
    String? adminName,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    Map<String, dynamic>? extraDetails,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final Map<String, dynamic> payload = {
        if (oldData != null) 'oldData': oldData,
        if (newData != null) 'newData': newData,
        if (extraDetails != null) ...extraDetails,
      };

      await supabase.from('adminAuditLogs').insert({
        'adminId': user.id,
        'adminName': adminName ?? '시스템 관리자',
        'action': action,
        'targetId': targetId,
        // [Master] 명시적 jsonEncode로 DB 텍스트/JSONB 호환성 확보
        'details': jsonEncode(payload),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('⚠️ [Audit] 로깅 실패: $e');
    }
  }
}
