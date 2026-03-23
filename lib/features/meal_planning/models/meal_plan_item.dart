class MealPlanItem {
  final String id;
  final String mealPlanId;
  final String title;
  final String? recipeId;
  final String? recipeName; // joined
  final int sortOrder;

  const MealPlanItem({
    required this.id,
    required this.mealPlanId,
    required this.title,
    this.recipeId,
    this.recipeName,
    this.sortOrder = 0,
  });

  factory MealPlanItem.fromMap(Map<String, dynamic> map) {
    return MealPlanItem(
      id: map['id'] as String,
      mealPlanId: map['meal_plan_id'] as String,
      title: map['title'] as String,
      recipeId: map['recipe_id'] as String?,
      recipeName: map['recipe_name'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meal_plan_id': mealPlanId,
      'title': title,
      'recipe_id': recipeId,
      'sort_order': sortOrder,
    };
  }

  MealPlanItem copyWith({
    String? id,
    String? mealPlanId,
    String? title,
    Object? recipeId = _sentinel,
    Object? recipeName = _sentinel,
    int? sortOrder,
  }) {
    return MealPlanItem(
      id: id ?? this.id,
      mealPlanId: mealPlanId ?? this.mealPlanId,
      title: title ?? this.title,
      recipeId: recipeId == _sentinel ? this.recipeId : recipeId as String?,
      recipeName:
          recipeName == _sentinel ? this.recipeName : recipeName as String?,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

const _sentinel = Object();
