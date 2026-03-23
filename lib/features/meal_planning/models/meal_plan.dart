class MealPlan {
  final String id;
  final DateTime date;
  final String categoryId;
  final String title;
  final String? notes;
  final String? recipeId;

  // Joined
  final String? categoryName;
  final String? categoryColor;
  final String? recipeName;

  const MealPlan({
    required this.id,
    required this.date,
    required this.categoryId,
    required this.title,
    this.notes,
    this.recipeId,
    this.categoryName,
    this.categoryColor,
    this.recipeName,
  });

  factory MealPlan.fromMap(Map<String, dynamic> map) {
    return MealPlan(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      categoryId: map['category_id'] as String,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      recipeId: map['recipe_id'] as String?,
      categoryName: map['category_name'] as String?,
      categoryColor: map['category_color'] as String?,
      recipeName: map['recipe_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String().split('T').first,
      'category_id': categoryId,
      'title': title,
      'notes': notes,
      'recipe_id': recipeId,
    };
  }

  MealPlan copyWith({
    String? id,
    DateTime? date,
    String? categoryId,
    String? title,
    String? notes,
    String? recipeId,
    String? categoryName,
    String? categoryColor,
    String? recipeName,
  }) {
    return MealPlan(
      id: id ?? this.id,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      recipeId: recipeId ?? this.recipeId,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      recipeName: recipeName ?? this.recipeName,
    );
  }
}
