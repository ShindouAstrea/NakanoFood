import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Capa para pedir texto al modelo. La llamada real a OpenAI ocurre en la
/// Edge Function `openai-complete`, donde vive la API key: la app nunca la
/// conoce, así que no puede filtrarse al descompilar el APK.
class OpenAIService {
  static const _function = 'openai-complete';

  static SupabaseClient get _client => Supabase.instance.client;

  /// Envía [userPrompt] al modelo y devuelve el contenido de la respuesta.
  /// La función fuerza JSON mode, así que el resultado es JSON válido.
  ///
  /// Lanza [OpenAIException], que trae un mensaje apto para mostrar en
  /// pantalla y, aparte, el detalle técnico para los logs.
  static Future<String> complete(
    String userPrompt, {
    String systemPrompt =
        'Eres un asistente experto. Siempre responde en JSON válido.',
    double temperature = 0.8,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        _function,
        body: {
          'prompt': userPrompt,
          'systemPrompt': systemPrompt,
          'temperature': temperature,
        },
      );
    } on FunctionException catch (e) {
      throw OpenAIException._from(
        _detailFrom(e.details) ?? 'La función respondió ${e.status}.',
      );
    } catch (e) {
      throw OpenAIException._from('No se pudo contactar al servicio: $e');
    }

    final data = response.data;
    if (data is! Map) {
      throw OpenAIException._from('Respuesta con formato inesperado.');
    }

    final content = data['content'];
    if (content is! String || content.isEmpty) {
      throw OpenAIException._from(
        _detailFrom(data) ?? 'La respuesta no traía contenido.',
      );
    }
    return content;
  }

  /// Extrae el campo `error` que devuelven las Edge Functions.
  static String? _detailFrom(dynamic details) {
    if (details is Map) {
      final error = details['error'];
      if (error is String && error.isNotEmpty) return error;
    }
    return null;
  }
}

/// Fallo al pedir una respuesta al modelo.
///
/// Separa deliberadamente dos cosas: [message], que es lo único que debe
/// llegar a la pantalla, y [detail], el texto crudo del servicio — que puede
/// traer códigos, URLs de facturación y jerga que no le sirven de nada a
/// quien está usando la app.
class OpenAIException implements Exception {
  /// Apto para mostrar al usuario.
  final String message;

  /// Texto original del servicio, solo para logs.
  final String detail;

  const OpenAIException(this.message, this.detail);

  factory OpenAIException._from(String detail) {
    final d = detail.toLowerCase();

    String friendly;
    if (d.contains('no credits') ||
        d.contains('quota') ||
        d.contains('billing') ||
        d.contains('429')) {
      // Problema de la cuenta del desarrollador: al usuario solo le importa
      // que la función no está disponible, no por qué.
      friendly = 'Las sugerencias con IA no están disponibles en este momento. '
          'Inténtalo más tarde.';
    } else if (d.contains('no está configurada') || d.contains('503')) {
      friendly = 'Las sugerencias con IA aún no están configuradas.';
    } else if (d.contains('tardó demasiado') ||
        d.contains('timeout') ||
        d.contains('504')) {
      friendly = 'El servicio tardó demasiado en responder. '
          'Revisa tu conexión e inténtalo de nuevo.';
    } else if (d.contains('no se pudo contactar') ||
        d.contains('socket') ||
        d.contains('failed host lookup') ||
        d.contains('connection')) {
      friendly = 'Sin conexión con el servicio. Revisa tu internet.';
    } else if (d.contains('401') || d.contains('403')) {
      friendly = 'Las sugerencias con IA no están disponibles en este momento.';
    } else {
      friendly = 'No se pudieron generar sugerencias. Inténtalo de nuevo.';
    }

    debugPrint('[OpenAIService] $detail');
    return OpenAIException(friendly, detail);
  }

  @override
  String toString() => message;
}
