import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'supabase_service.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  AnalyticsService._internal();

  final List<Map<String, dynamic>> _pendingLogs = [];
  bool _isSyncing = false; 
  
  SupabaseClient get supabase => SupabaseService.client;

  Future<void> logEvent({
    required String actionType,
    String? lensId,
    String? brandId,
    int? durationMs,
  }) async {
    final session = supabase.auth.currentSession;
    final log = {
      'userId': session?.user.id,
      'anonymousId': session == null ? 'anon_user' : null,
      'actionType': actionType,
      'lensId': lensId,
      'brandId': brandId,
      'durationMs': durationMs,
      'createdAt': DateTime.now().toIso8601String(),
    };

    _pendingLogs.add(log);
    if (_pendingLogs.length >= 5) {
      await syncSessionData();
    }
  }

  Future<void> syncSessionData({
    String? lensId,
    String? brandId,
    DateTime? startTime,
  }) async {
    if (_isSyncing) return;
    if (_pendingLogs.isEmpty && startTime == null) return;

    _isSyncing = true;
    try {
      if (startTime != null && lensId != null) {
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        _pendingLogs.add({
          'userId': supabase.auth.currentUserId,
          'actionType': 'wear_session_sync',
          'lensId': lensId,
          'brandId': brandId,
          'durationMs': duration,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      if (_pendingLogs.isNotEmpty) {
        final logsToSync = List<Map<String, dynamic>>.from(_pendingLogs);
        await supabase.from('activityLogs').insert(logsToSync);
        _pendingLogs.removeWhere((log) => logsToSync.contains(log));
      }
    } catch (e) {
      debugPrint('⚠️ [Analytics] Sync Failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// [Ultimate Golden Master] Beacon 적재 확인 가드
  void forceSync() {
    if (_pendingLogs.isEmpty || _isSyncing) return;

    if (kIsWeb) {
      final String url = '${supabase.supabaseUrl}/rest/v1/activityLogs';
      final String apiKey = supabase.supabaseKey;
      
      final String payload = jsonEncode(_pendingLogs);
      
      // [Master] Beacon 큐 적재 성공 시에만 메모리 클리어 (데이터 증발 방어)
      final bool isQueued = html.window.navigator.sendBeacon(
        url, 
        html.Blob([payload], 'application/json')
      );
      
      if (isQueued) {
        _pendingLogs.clear();
        debugPrint('🌐 [Web Guard] Beacon successfully queued.');
      } else {
        debugPrint('⚠️ [Web Guard] Beacon queue full. Logs preserved.');
      }
    } else {
      syncSessionData();
    }
  }

  void reset() {
    _pendingLogs.clear();
    _isSyncing = false;
  }
}
