import '../models/recipe_suggestion.dart';

/// Servicio para obtener recomendaciones de recetas.
///
/// TODO: Cuando el token de OpenAI esté disponible, reemplazar [_mockSuggestions]
/// y [_mockPopular] con una llamada real a la API usando el prompt adecuado.
///
/// Prompt sugerido para recomendaciones personalizadas:
/// "Dado que el usuario ya tiene estas recetas: [lista], recomienda 10 recetas
/// nuevas complementarias. Devuelve JSON con campos: name, type, description,
/// estimated_minutes, difficulty, reason."
///
/// Prompt sugerido para top populares:
/// "Recomienda las 10 recetas más populares de [país]. Devuelve JSON con
/// campos: name, type, description, estimated_minutes, difficulty, reason."
class RecipeExploreService {
  /// Devuelve sugerencias de recetas.
  /// - Si [existingRecipeNames] está vacío → top populares del país.
  /// - Si hay recetas → recomendaciones personalizadas basadas en ellas.
  static Future<List<RecipeSuggestion>> getSuggestions({
    required List<String> existingRecipeNames,
    String? typeFilter,
  }) async {
    // Simula latencia de API
    await Future.delayed(const Duration(milliseconds: 800));

    // TODO: Reemplazar con llamada real a OpenAI:
    // final prompt = existingRecipeNames.isEmpty
    //     ? _buildPopularPrompt()
    //     : _buildPersonalizedPrompt(existingRecipeNames);
    // final response = await OpenAIService.complete(prompt);
    // final suggestions = (jsonDecode(response) as List)
    //     .map((e) => RecipeSuggestion.fromJson(e))
    //     .toList();

    final suggestions = existingRecipeNames.isEmpty
        ? _mockPopular()
        : _mockSuggestions(existingRecipeNames);

    if (typeFilter != null) {
      return suggestions.where((s) => s.type == typeFilter).toList();
    }
    return suggestions;
  }

  // ── Mock data (reemplazar con OpenAI) ─────────────────────────────────────

  static List<RecipeSuggestion> _mockPopular() => [
        const RecipeSuggestion(
          name: 'Cazuela de Vacuno',
          type: 'Sopa',
          description:
              'Caldo contundente con trozos de vacuno, papas, zapallo, choclo y verduras de temporada.',
          estimatedMinutes: 90,
          difficulty: 'Fácil',
          reason: 'Plato tradicional chileno más popular',
        ),
        const RecipeSuggestion(
          name: 'Empanadas de Pino',
          type: 'Snack',
          description:
              'Masa horneada rellena de pino (carne molida, cebolla, huevo duro, aceitunas y pasas).',
          estimatedMinutes: 75,
          difficulty: 'Medio',
          reason: 'Ícono de las Fiestas Patrias',
        ),
        const RecipeSuggestion(
          name: 'Pastel de Choclo',
          type: 'Comida Principal',
          description:
              'Costra de choclo molido sobre pino de carne, pollo, huevo duro y aceitunas, gratinado al horno.',
          estimatedMinutes: 80,
          difficulty: 'Medio',
          reason: 'Favorito de verano en Chile',
        ),
        const RecipeSuggestion(
          name: 'Porotos con Riendas',
          type: 'Comida Principal',
          description:
              'Porotos guisados con longaniza y fideos largos, plato campesino reconfortante.',
          estimatedMinutes: 60,
          difficulty: 'Fácil',
          reason: 'Plato del campo chileno más querido',
        ),
        const RecipeSuggestion(
          name: 'Charquicán',
          type: 'Comida Principal',
          description:
              'Guiso de papas, zapallo y carne desmenuzada con verduras salteadas y un huevo frito encima.',
          estimatedMinutes: 45,
          difficulty: 'Fácil',
          reason: 'Receta chilena de la abuela',
        ),
        const RecipeSuggestion(
          name: 'Sopaipillas',
          type: 'Snack',
          description:
              'Masa frita de harina y zapallo, crocante por fuera y suave por dentro, acompañada de pebre o chancaca.',
          estimatedMinutes: 40,
          difficulty: 'Fácil',
          reason: 'Snack callejero más popular de Chile',
        ),
        const RecipeSuggestion(
          name: 'Leche Asada',
          type: 'Postre',
          description:
              'Crema horneada de leche, huevos y vainilla con una costra dorada y caramelo en el fondo.',
          estimatedMinutes: 50,
          difficulty: 'Fácil',
          reason: 'Postre casero chileno más clásico',
        ),
        const RecipeSuggestion(
          name: 'Mote con Huesillo',
          type: 'Bebida',
          description:
              'Bebida fría de mote de trigo con duraznos deshidratados en almíbar especiado con canela.',
          estimatedMinutes: 30,
          difficulty: 'Fácil',
          reason: 'Bebida veraniega nacional de Chile',
        ),
        const RecipeSuggestion(
          name: 'Humitas',
          type: 'Snack',
          description:
              'Pasta de choclo fresco con albahaca y cebolla, envuelta en hojas de maíz y cocida al vapor.',
          estimatedMinutes: 90,
          difficulty: 'Difícil',
          reason: 'Tradición culinaria chilena de verano',
        ),
        const RecipeSuggestion(
          name: 'Panqueques con Manjar',
          type: 'Postre',
          description:
              'Panqueques delgados rellenos con manjar (dulce de leche chileno) y enrollados o doblados.',
          estimatedMinutes: 25,
          difficulty: 'Fácil',
          reason: 'Postre favorito de once en Chile',
        ),
      ];

  static List<RecipeSuggestion> _mockSuggestions(
      List<String> existingNames) =>
      [
        RecipeSuggestion(
          name: 'Variación de tus favoritas',
          type: 'Comida Principal',
          description:
              'Basado en tus recetas (${existingNames.take(2).join(', ')}...), '
              'podrías explorar versiones con ingredientes similares.',
          estimatedMinutes: 30,
          difficulty: 'Fácil',
          reason: 'Complementa tus recetas actuales',
        ),
        ..._mockPopular().take(9),
      ];
}
