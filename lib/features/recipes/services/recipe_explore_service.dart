import 'dart:convert';
import '../../../core/services/openai_service.dart';
import '../../../core/services/pexels_service.dart';
import '../../pantry/models/product.dart';
import '../models/recipe.dart';
import '../models/recipe_suggestion.dart';

/// Servicio de sugerencias de recetas con IA.
///
/// Contexto que se envía a OpenAI:
/// - Recetas guardadas (nombre + tipo, máx 30)
/// - Stock disponible en despensa (qty > 0, máx 40)
/// - Historial de cocción de las últimas 4 semanas
///
/// Si la API falla, devuelve el mock local automáticamente.
class RecipeExploreService {
  static const _systemPrompt =
      'Eres un asistente culinario inteligente integrado en una app de gestión '
      'de recetas y despensa. Tu única función es analizar el contexto del usuario '
      'y devolver sugerencias de recetas útiles, variadas y realizables. '
      'Responde SIEMPRE con un JSON válido con la key "suggestions".';

  static Future<List<RecipeSuggestion>> getSuggestions({
    required List<Recipe> savedRecipes,
    required List<Product> pantryProducts,
    String? typeFilter,
  }) async {
    try {
      final suggestions = await _fetchFromAI(
        savedRecipes: savedRecipes,
        pantryProducts: pantryProducts,
        typeFilter: typeFilter,
      );
      if (typeFilter != null) {
        return suggestions.where((s) => s.type == typeFilter).toList();
      }
      return suggestions;
    } catch (_) {
      final fallback = savedRecipes.isEmpty ? _mockPopular() : _mockPersonalized();
      if (typeFilter != null) {
        return fallback.where((s) => s.type == typeFilter).toList();
      }
      return fallback;
    }
  }

  // ─── Lógica de IA ──────────────────────────────────────────────────────────

  static Future<List<RecipeSuggestion>> _fetchFromAI({
    required List<Recipe> savedRecipes,
    required List<Product> pantryProducts,
    String? typeFilter,
  }) async {
    final prompt = _buildPrompt(
      savedRecipes: savedRecipes,
      pantryProducts: pantryProducts,
      typeFilter: typeFilter,
    );

    final raw = await OpenAIService.complete(prompt, systemPrompt: _systemPrompt);

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['suggestions'] as List<dynamic>? ?? [];
    final suggestions = list
        .whereType<Map<String, dynamic>>()
        .map(RecipeSuggestion.fromJson)
        .toList();

    // Buscar imágenes en paralelo — dos intentos si el query específico falla
    return Future.wait(
      suggestions.map((s) async {
        final specificQuery = (s.imageQuery?.isNotEmpty == true)
            ? s.imageQuery!
            : '${s.name} food dish';
        var url = await PexelsService.searchPhoto(specificQuery);
        url ??= await PexelsService.searchPhoto('${s.type} food dish');
        return s.withImageUrl(url);
      }),
    );
  }

  static String _buildPrompt({
    required List<Recipe> savedRecipes,
    required List<Product> pantryProducts,
    String? typeFilter,
  }) {
    final typeConstraint = typeFilter != null
        ? '\n⚠️ SOLO sugiere recetas de tipo "$typeFilter". No incluyas otros tipos.'
        : '';

    // Contexto compacto para minimizar tokens
    final savedSection = savedRecipes.isEmpty
        ? '(sin recetas guardadas aún)'
        : jsonEncode(
            savedRecipes.take(30).map((r) => {'name': r.name, 'type': r.type}).toList(),
          );

    final pantrySection = pantryProducts.isEmpty
        ? '(despensa vacía)'
        : jsonEncode(
            pantryProducts
                .where((p) => !p.isOut)
                .take(40)
                .map((p) => {'name': p.name, 'qty': p.currentQuantity, 'unit': p.unit})
                .toList(),
          );

    final since = DateTime.now().subtract(const Duration(days: 28));
    final recentCookings = savedRecipes
        .where((r) => r.lastCookedAt != null && r.lastCookedAt!.isAfter(since))
        .map((r) => {
              'name': r.name,
              'type': r.type,
              'date': r.lastCookedAt!.toIso8601String().substring(0, 10),
            })
        .toList();
    final historySection =
        recentCookings.isEmpty ? '(sin historial reciente)' : jsonEncode(recentCookings);

    return '''
Analiza el siguiente contexto culinario y genera entre 4 y 6 sugerencias de recetas.$typeConstraint

### Recetas guardadas del usuario
$savedSection

### Stock disponible en despensa (solo productos con cantidad > 0)
$pantrySection

### Historial de cocción (últimas 4 semanas)
$historySection

---

## PRIORIDADES (en orden)

1. Recetas que aprovechen ingredientes del stock disponible — especialmente los de mayor cantidad.
2. Variedad respecto al historial — evita repetir proteínas, estilos o tipos de los últimos 7 días.
3. Al menos 1 sugerencia de descubrimiento — algo diferente al estilo habitual del usuario.

## REGLAS

- No sugieras recetas con nombre similar a las ya guardadas.
- `type` debe ser exactamente uno de: "Desayuno", "Comida Principal", "Cena", "Snack", "Postre", "Pastelería", "Ensalada", "Sopa", "Bebida", "Otro".
- `difficulty` debe ser exactamente: "Fácil", "Medio" o "Difícil".
- `reason` máximo 100 caracteres; menciona un ingrediente concreto del stock o un patrón del historial.
- `estimated_minutes` debe ser un entero mayor a 10.
- `description` máximo 120 caracteres, apetitosa y concreta.
- `image_query` frase en inglés de 3-5 palabras para buscar la foto en Pexels. Reglas:
  * Describe el plato terminado, no los ingredientes crudos.
  * Incluye el nombre del plato en inglés + 1-2 palabras visuales (color, textura, presentación).
  * Termina siempre con "food" o "dish" o "meal".
  * Ejemplos buenos: "baked Chilean empanadas golden food", "creamy tomato soup bowl food", "grilled salmon lemon dish".
  * Ejemplos malos: "empanadas", "soup ingredients", "meat and vegetables".
- `ingredients`: campo OBLIGATORIO. Lista de 4-10 ingredientes con cantidad realista para 2-4 porciones. NUNCA dejes este campo vacío ni lo omitas.
  * `unit` debe ser uno de: g, kg, ml, L, taza, cucharada, cucharadita, unidad, rodaja, pizca, sobre.
- `steps`: campo OBLIGATORIO. Lista de 4-8 pasos de preparación claros y concisos, en español. NUNCA dejes este campo vacío ni lo omitas.

## FORMATO DE RESPUESTA (obligatorio)

{
  "suggestions": [
    {
      "name": "string",
      "type": "string",
      "description": "string",
      "estimated_minutes": number,
      "difficulty": "string",
      "reason": "string",
      "image_query": "string",
      "ingredients": [
        {"name": "string", "quantity": number, "unit": "string"}
      ],
      "steps": [
        {"step": number, "description": "string"}
      ]
    }
  ]
}
''';
  }

  // ─── Mock data (fallback sin conexión) ─────────────────────────────────────

  static List<RecipeSuggestion> _mockPopular() => [
        const RecipeSuggestion(
          name: 'Empanadas de Pino',
          type: 'Snack',
          description:
              'Masa horneada rellena de pino (carne molida, cebolla, huevo duro, aceitunas y pasas).',
          estimatedMinutes: 90,
          difficulty: 'Medio',
          reason: 'Ícono culinario de las Fiestas Patrias',
        ),
        const RecipeSuggestion(
          name: 'Pastel de Choclo',
          type: 'Comida Principal',
          description:
              'Costra de choclo fresco sobre pino de carne y pollo, gratinado al horno con azúcar.',
          estimatedMinutes: 85,
          difficulty: 'Medio',
          reason: 'Favorito del verano chileno',
        ),
        const RecipeSuggestion(
          name: 'Sopaipillas',
          type: 'Snack',
          description:
              'Masa frita de harina y zapallo, crocante por fuera. Con pebre, salsa de tomate o chancaca.',
          estimatedMinutes: 40,
          difficulty: 'Fácil',
          reason: 'Snack callejero más popular de Chile',
        ),
        const RecipeSuggestion(
          name: 'Leche Asada',
          type: 'Postre',
          description:
              'Crema suave horneada al baño maría con caramelo. El postre casero chileno más clásico.',
          estimatedMinutes: 60,
          difficulty: 'Fácil',
          reason: 'Postre casero chileno más clásico',
        ),
        const RecipeSuggestion(
          name: 'Charquicán',
          type: 'Comida Principal',
          description:
              'Guiso seco de papas, zapallo y carne desmenuzada con verduras. Se sirve con huevo frito.',
          estimatedMinutes: 45,
          difficulty: 'Fácil',
          reason: 'Receta chilena de la abuela',
        ),
        const RecipeSuggestion(
          name: 'Mote con Huesillo',
          type: 'Bebida',
          description:
              'Mote de trigo con duraznos deshidratados en almíbar de canela y clavo. Refresco nacional.',
          estimatedMinutes: 30,
          difficulty: 'Fácil',
          reason: 'Bebida veraniega nacional de Chile',
        ),
        const RecipeSuggestion(
          name: 'Humitas',
          type: 'Snack',
          description:
              'Pasta de choclo con albahaca y cebolla, envuelta en hojas de maíz y cocida al vapor.',
          estimatedMinutes: 90,
          difficulty: 'Difícil',
          reason: 'Tradición culinaria chilena de verano',
        ),
        const RecipeSuggestion(
          name: 'Panqueques con Manjar',
          type: 'Postre',
          description:
              'Panqueques delgados rellenos de manjar chileno, enrollados y espolvoreados con azúcar flor.',
          estimatedMinutes: 25,
          difficulty: 'Fácil',
          reason: 'Postre favorito de la once en Chile',
        ),
        const RecipeSuggestion(
          name: 'Anticuchos de Vacuno',
          type: 'Snack',
          description:
              'Brochetas de vacuno marinadas en ají panca, ajo y comino, asadas a la parrilla.',
          estimatedMinutes: 35,
          difficulty: 'Fácil',
          reason: 'Popular en fondas y asados chilenos',
        ),
        const RecipeSuggestion(
          name: 'Milhojas de Crema',
          type: 'Postre',
          description:
              'Capas de hojaldre crujiente rellenas de crema pastelera y manjar, cubiertas con azúcar flor.',
          estimatedMinutes: 60,
          difficulty: 'Difícil',
          reason: 'Postre estrella de las pastelerías chilenas',
        ),
      ];

  static List<RecipeSuggestion> _mockPersonalized() => [
        const RecipeSuggestion(
          name: 'Cupcake Proteínico',
          type: 'Postre',
          description: 'Cupcake a base de plátano con mantequilla de maní y berries.',
          estimatedMinutes: 30,
          difficulty: 'Fácil',
          reason: 'Postre nutritivo y saludable',
        ),
        ..._mockPopular().take(9),
      ];
}
