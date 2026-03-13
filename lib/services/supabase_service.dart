import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
      // .env 파일에서 정보를 안전하게 가져옵니다.
      final String url = dotenv.get('SUPABASE_URL').trim();
      final String anonKey = dotenv.get('SUPABASE_ANON_KEY').trim();

      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      isReady = true;
      debugPrint("🚀 [System] Supabase Engine Initialized Successfully from Env");
    } catch (e) {
      isReady = false;
      debugPrint("❌ [System] Supabase Init Error: $e");
      rethrow;
    }
  }
}
