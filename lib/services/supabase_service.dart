import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static bool isReady = false;

  static SupabaseClient get client {
    if (!isReady) {
      throw Exception('❌ [System] Supabase is not initialized yet.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: 'https://zelxqkkasuomhbamzfrz.supabase.co',
        anonKey: '디렉터님의_실제_ANON_KEY_문자열',
      );
      isReady = true;
      debugPrint("🚀 [System] Supabase Engine Initialized Successfully");
    } catch (e) {
      isReady = false;
      debugPrint("❌ [System] Supabase Init Error: $e");
      rethrow;
    }
  }
}
