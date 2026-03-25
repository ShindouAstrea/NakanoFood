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
          name: 'Empanadas de Pino',
          type: 'Snack',
          description:
              'Masa horneada rellena de pino (carne molida, cebolla, huevo duro, aceitunas y pasas). Ícono de las Fiestas Patrias.',
          estimatedMinutes: 90,
          difficulty: 'Medio',
          reason: 'Ícono culinario de las Fiestas Patrias',
        ),
        const RecipeSuggestion(
          name: 'Pastel de Choclo',
          type: 'Comida Principal',
          description:
              'Costra de choclo fresco molido sobre pino de carne y pollo, con huevo duro y aceitunas, gratinado al horno con azúcar.',
          estimatedMinutes: 85,
          difficulty: 'Medio',
          reason: 'Favorito del verano chileno',
        ),
        const RecipeSuggestion(
          name: 'Sopaipillas',
          type: 'Snack',
          description:
              'Masa frita de harina y zapallo, crocante por fuera y suave por dentro. Se sirve con pebre, salsa de tomate o chancaca.',
          estimatedMinutes: 40,
          difficulty: 'Fácil',
          reason: 'Snack callejero más popular de Chile',
        ),
        const RecipeSuggestion(
          name: 'Leche Asada',
          type: 'Postre',
          description:
              'Crema suave horneada al baño maría con caramelo en el fondo. El postre casero chileno más clásico y reconfortante.',
          estimatedMinutes: 60,
          difficulty: 'Fácil',
          reason: 'Postre casero chileno más clásico',
        ),
        const RecipeSuggestion(
          name: 'Charquicán',
          type: 'Comida Principal',
          description:
              'Guiso seco de papas, zapallo y carne desmenuzada salteada con verduras. Se sirve con un huevo frito encima.',
          estimatedMinutes: 45,
          difficulty: 'Fácil',
          reason: 'Receta chilena de la abuela',
        ),
        const RecipeSuggestion(
          name: 'Mote con Huesillo',
          type: 'Bebida',
          description:
              'Bebida fría de mote de trigo con duraznos deshidratados en almíbar especiado con canela y clavo. Refresco nacional de Chile.',
          estimatedMinutes: 30,
          difficulty: 'Fácil',
          reason: 'Bebida veraniega nacional de Chile',
        ),
        const RecipeSuggestion(
          name: 'Humitas',
          type: 'Snack',
          description:
              'Pasta de choclo fresco con albahaca y cebolla, envuelta en hojas de maíz y cocida al vapor. Tradición culinaria de verano.',
          estimatedMinutes: 90,
          difficulty: 'Difícil',
          reason: 'Tradición culinaria chilena de verano',
        ),
        const RecipeSuggestion(
          name: 'Panqueques con Manjar',
          type: 'Postre',
          description:
              'Panqueques delgados rellenos de manjar (dulce de leche chileno), enrollados o doblados y espolvoreados con azúcar flor.',
          estimatedMinutes: 25,
          difficulty: 'Fácil',
          reason: 'Postre favorito de la once en Chile',
        ),
        const RecipeSuggestion(
          name: 'Anticuchos de Vacuno',
          type: 'Snack',
          description:
              'Brochetas de corazón o filete de vacuno marinadas en ají panca, ajo y comino, asadas a la parrilla. Clásico de la cocina criolla.',
          estimatedMinutes: 35,
          difficulty: 'Fácil',
          reason: 'Popular en fondas y asados chilenos',
        ),
        const RecipeSuggestion(
          name: 'Milhojas de Crema',
          type: 'Postre',
          description:
              'Capas de hojaldre crujiente rellenas de crema pastelera y manjar, cubiertas con azúcar flor. Postre de pastelería chilena.',
          estimatedMinutes: 60,
          difficulty: 'Difícil',
          reason: 'Postre estrella de las pastelerías chilenas',
        ),
      ];

  static List<RecipeSuggestion> _mockSuggestions(
      List<String> existingNames) =>
      [
        const RecipeSuggestion(
          name: 'Cupcake Proteinico',
          type: 'Postre',
          description:
              'Cupcacke a base de platano con mantequilla de mani y berries',
          estimatedMinutes: 30,
          difficulty: 'Fácil',
          reason: 'Postre o Snack Nutritivo y saludable',
        ),
        ..._mockPopular().take(9),
      ];
}
