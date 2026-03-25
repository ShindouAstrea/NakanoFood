class RecipeSuggestion {
  final String name;
  final String type;
  final String description;
  final int? estimatedMinutes;
  final String? difficulty; // 'Fácil', 'Medio', 'Difícil'
  final String? reason; // Por qué fue recomendada

  const RecipeSuggestion({
    required this.name,
    required this.type,
    required this.description,
    this.estimatedMinutes,
    this.difficulty,
    this.reason,
  });

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    return RecipeSuggestion(
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      estimatedMinutes: json['estimated_minutes'] as int?,
      difficulty: json['difficulty'] as String?,
      reason: json['reason'] as String?,
    );
  }
}
