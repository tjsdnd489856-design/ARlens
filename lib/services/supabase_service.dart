import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("dotenv 로드 실패 (무시됨): $e");
    }

    try {
      await Supabase.initialize(
        url:
            dotenv.env['SUPABASE_URL'] ??
            'https://zelxqkkasuomhbamzfrz.supabase.co',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
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
