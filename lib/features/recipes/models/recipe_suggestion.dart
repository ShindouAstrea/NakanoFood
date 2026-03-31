class SuggestionIngredient {
  final String name;
  final double quantity;
  final String unit;

  const SuggestionIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory SuggestionIngredient.fromJson(Map<String, dynamic> json) {
    return SuggestionIngredient(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }
}

class SuggestionStep {
  final int step;
  final String description;

  const SuggestionStep({required this.step, required this.description});

  factory SuggestionStep.fromJson(Map<String, dynamic> json) {
    return SuggestionStep(
      step: (json['step'] as num).toInt(),
      description: json['description'] as String,
    );
  }
}

class RecipeSuggestion {
  final String name;
  final String type;
  final String description;
  final int? estimatedMinutes;
  final String? difficulty;
  final String? reason;
  final String? imageQuery;
  final String? imageUrl;
  final List<SuggestionIngredient> ingredients;
  final List<SuggestionStep> steps;

  const RecipeSuggestion({
    required this.name,
    required this.type,
    required this.description,
    this.estimatedMinutes,
    this.difficulty,
    this.reason,
    this.imageQuery,
    this.imageUrl,
    this.ingredients = const [],
    this.steps = const [],
  });

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    return RecipeSuggestion(
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
      difficulty: json['difficulty'] as String?,
      reason: json['reason'] as String?,
      imageQuery: json['image_query'] as String?,
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SuggestionIngredient.fromJson)
          .toList(),
      steps: (json['steps'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SuggestionStep.fromJson)
          .toList(),
    );
  }

  RecipeSuggestion withImageUrl(String? url) => RecipeSuggestion(
        name: name,
        type: type,
        description: description,
        estimatedMinutes: estimatedMinutes,
        difficulty: difficulty,
        reason: reason,
        imageQuery: imageQuery,
        imageUrl: url,
        ingredients: ingredients,
        steps: steps,
      );
}
