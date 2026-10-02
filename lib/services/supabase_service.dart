import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static Future<void> initialize() async {
    if (!SupabaseConfig.configured) return;
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  }

  static bool get configured => SupabaseConfig.configured;
  static SupabaseClient get client => Supabase.instance.client;
  static User? get user => configured ? client.auth.currentUser : null;
}
