class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://uiwtvazhrzsupkvuxxcg.supabase.co');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_420QYxIgQNBzRlWbORXc9g_zb4q_X2X');
  static bool get configured => url.startsWith('https://') && !url.contains('YOUR_PROJECT') && publishableKey.isNotEmpty && !publishableKey.contains('YOUR_SUPABASE');
}
