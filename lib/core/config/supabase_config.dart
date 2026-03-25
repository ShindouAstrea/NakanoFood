import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Leídos en compile-time desde --dart-define (producción web/CI)
  static const _dartUrl = String.fromEnvironment('SUPABASE_URL');
  static const _dartKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url => dotenv.env['SUPABASE_URL'] ?? _dartUrl;
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? _dartKey;

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
