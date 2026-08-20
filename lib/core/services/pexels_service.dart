import 'package:supabase_flutter/supabase_flutter.dart';

/// Busca fotos de comida dado un query en inglés. La llamada real a Pexels
/// ocurre en la Edge Function `pexels-photo`, que guarda la API key y elige
/// la foto de mejor relación 16:9.
///
/// Las fotos son opcionales: ante cualquier fallo devuelve null y quien
/// llama sigue sin imagen, sin romper el flujo.
class PexelsService {
  static const _function = 'pexels-photo';

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<String?> searchPhoto(String query) async {
    try {
      final response = await _client.functions.invoke(
        _function,
        body: {'query': query},
      );

      final data = response.data;
      if (data is! Map) return null;

      final url = data['url'];
      return url is String && url.isNotEmpty ? url : null;
    } catch (_) {
      return null;
    }
  }
}
