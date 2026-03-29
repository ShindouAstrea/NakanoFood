class NutritionSummary {
  final double kcal;
  final double proteins;
  final double carbs;
  final double fats;
  final double fiber;
  final double sodium;

  /// Per-meal breakdown: category name → nutrients
  final List<MealNutrition> meals;

  const NutritionSummary({
    this.kcal = 0,
    this.proteins = 0,
    this.carbs = 0,
    this.fats = 0,
    this.fiber = 0,
    this.sodium = 0,
    this.meals = const [],
  });

  bool get isEmpty => kcal == 0 && proteins == 0 && carbs == 0 && fats == 0;

  NutritionSummary operator +(NutritionSummary other) => NutritionSummary(
        kcal: kcal + other.kcal,
        proteins: proteins + other.proteins,
        carbs: carbs + other.carbs,
        fats: fats + other.fats,
        fiber: fiber + other.fiber,
        sodium: sodium + other.sodium,
        meals: [...meals, ...other.meals],
      );
}

class MealNutrition {
  final String mealTitle;
  final String? categoryName;
  final double kcal;
  final double proteins;
  final double carbs;
  final double fats;
  final double fiber;
  final double sodium;

  const MealNutrition({
    required this.mealTitle,
    this.categoryName,
    this.kcal = 0,
    this.proteins = 0,
    this.carbs = 0,
    this.fats = 0,
    this.fiber = 0,
    this.sodium = 0,
  });

  bool get hasData => kcal > 0 || proteins > 0 || carbs > 0 || fats > 0;
}
