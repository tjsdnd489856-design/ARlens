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
        url: 'https://zelxqkkasuomhbamzfrz.supabase.co'.trim(),
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InplbHhxa2thc3VvbWhiYW16ZnJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyOTU4MzIsImV4cCI6MjA4ODg3MTgzMn0.rkC7X7gNRBrozt4jIrAB7g5GZovz455AaM-CBf1belE'
                .trim(),
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
