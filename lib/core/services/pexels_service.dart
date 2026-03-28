import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Busca fotos de comida en Pexels dado un query en inglés.
/// Obtiene los 3 primeros resultados y elige el de mejor relación
/// ancho/alto (más cercano a 16:9), descartando verticales.
class PexelsService {
  static const _baseUrl = 'https://api.pexels.com/v1/search';

  static String get _apiKey => dotenv.env['PEXELS_API_KEY'] ?? '';

  static Future<String?> searchPhoto(String query) async {
    if (_apiKey.isEmpty) return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'query': query,
        'per_page': '3',
        'orientation': 'landscape',
        'size': 'medium',
      });

      final response = await http
          .get(uri, headers: {'Authorization': _apiKey})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final photos = data['photos'] as List<dynamic>?;
      if (photos == null || photos.isEmpty) return null;

      // Elegir la foto cuya relación ancho/alto se acerque más a 16:9
      Map<String, dynamic>? best;
      double bestScore = double.infinity;

      for (final photo in photos) {
        final p = photo as Map<String, dynamic>;
        final w = (p['width'] as num?)?.toDouble() ?? 1;
        final h = (p['height'] as num?)?.toDouble() ?? 1;
        final ratio = w / h;
        final score = (ratio - (16 / 9)).abs();
        if (score < bestScore) {
          bestScore = score;
          best = p;
        }
      }

      if (best == null) return null;
      return best['src']?['medium'] as String?;
    } catch (_) {
      return null;
    }
  }
}
