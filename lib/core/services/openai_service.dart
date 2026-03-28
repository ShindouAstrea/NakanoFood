import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Capa HTTP genérica para llamar a la API de OpenAI.
/// No contiene lógica de dominio — solo envía prompts y devuelve texto.
class OpenAIService {
  static const _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4o-mini';
  static const _maxTokens = 3000;

  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  /// Envía [userPrompt] al modelo y devuelve el contenido de la respuesta.
  /// Usa JSON mode para garantizar JSON válido.
  static Future<String> complete(
    String userPrompt, {
    String systemPrompt =
        'Eres un asistente experto. Siempre responde en JSON válido.',
    double temperature = 0.8,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY no está configurada en .env');
    }

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'response_format': {'type': 'json_object'},
            'temperature': temperature,
            'max_tokens': _maxTokens,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final message = body['error']?['message'] ?? response.body;
      throw Exception('OpenAI ${response.statusCode}: $message');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['choices'][0]['message']['content'] as String;
  }
}
