import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Leídos en compile-time desde --dart-define (producción web/CI)
  static const _dartUrl = String.fromEnvironment('SUPABASE_URL');
  static const _dartKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _dartPublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Lee del .env sin poder lanzar nunca.
  ///
  /// El getter `dotenv.env` tira `NotInitializedError` si `load()` no llegó a
  /// completar — pasa con un .env ausente o vacío. Como este archivo se
  /// consulta durante el arranque, esa excepción impedía llegar a `runApp` y
  /// la app se quedaba congelada en el splash nativo, sin ningún mensaje.
  static String? _fromEnv(String key) {
    if (!dotenv.isInitialized) return null;
    return dotenv.env[key];
  }

  static String get url => _firstNonEmpty([
        _fromEnv('SUPABASE_URL'),
        _dartUrl,
      ]);

  /// Supabase renombró la "anon key" a "publishable key" (`sb_publishable_…`).
  /// Aceptamos ambos nombres para no depender de cuál esté en el .env.
  static String get anonKey => _firstNonEmpty([
        _fromEnv('SUPABASE_PUBLISHABLE_KEY'),
        _fromEnv('SUPABASE_ANON_KEY'),
        _dartPublishableKey,
        _dartKey,
      ]);

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static String _firstNonEmpty(List<String?> values) => values.firstWhere(
        (v) => v != null && v.isNotEmpty,
        orElse: () => '',
      )!;
}
