import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../models/nutrition_summary.dart';

/// Returns the [NutritionSummary] for a given [DateTime] (day only).
final dailyNutritionProvider =
    FutureProvider.family<NutritionSummary, DateTime>((ref, date) async {
  return _computeForDate(date);
});

Future<NutritionSummary> _computeForDate(DateTime date) async {
  final db = await DatabaseHelper.instance.database;
  final dateStr = date.toIso8601String().split('T').first;

  // Load meals with their items
  final planRows = await db.rawQuery('''
    SELECT
      mc.name        AS category_name,
      mpi.title      AS item_title,
      mpi.recipe_id
    FROM meal_plans mp
    LEFT JOIN meal_categories mc ON mp.category_id = mc.id
    LEFT JOIN meal_plan_items mpi ON mpi.meal_plan_id = mp.id
    WHERE mp.date = ?
    ORDER BY mp.id, mpi.sort_order
  ''', [dateStr]);

  if (planRows.isEmpty) return const NutritionSummary();

  final meals = <MealNutrition>[];

  for (final row in planRows) {
    final recipeId = row['recipe_id'] as String?;
    final itemTitle = row['item_title'] as String? ?? '';
    final categoryName = row['category_name'] as String?;

    if (recipeId == null) {
      meals.add(MealNutrition(
        mealTitle: itemTitle,
        categoryName: categoryName,
      ));
      continue;
    }

    // Aggregate nutrients for this recipe's ingredients
    final totals = await db.rawQuery('''
      SELECT
        SUM(nv.kcal        * ri.quantity / nv.serving_size) AS kcal,
        SUM(nv.proteins    * ri.quantity / nv.serving_size) AS proteins,
        SUM(nv.carbs       * ri.quantity / nv.serving_size) AS carbs,
        SUM(nv.total_fats  * ri.quantity / nv.serving_size) AS fats,
        SUM(nv.fiber       * ri.quantity / nv.serving_size) AS fiber,
        SUM(nv.sodium      * ri.quantity / nv.serving_size) AS sodium
      FROM recipe_ingredients ri
      JOIN nutritional_values nv ON nv.product_id = ri.product_id
      WHERE ri.recipe_id = ?
        AND nv.serving_size IS NOT NULL
        AND nv.serving_size > 0
    ''', [recipeId]);

    double val(Map<Object?, Object?> r, String key) =>
        (r[key] as num?)?.toDouble() ?? 0;

    final t = totals.isNotEmpty ? totals.first : <Object?, Object?>{};

    meals.add(MealNutrition(
      mealTitle: itemTitle,
      categoryName: categoryName,
      kcal: val(t, 'kcal'),
      proteins: val(t, 'proteins'),
      carbs: val(t, 'carbs'),
      fats: val(t, 'fats'),
      fiber: val(t, 'fiber'),
      sodium: val(t, 'sodium'),
    ));
  }

  // Sum totals across all meals
  double totalKcal = 0, totalProteins = 0, totalCarbs = 0,
      totalFats = 0, totalFiber = 0, totalSodium = 0;

  for (final m in meals) {
    totalKcal += m.kcal;
    totalProteins += m.proteins;
    totalCarbs += m.carbs;
    totalFats += m.fats;
    totalFiber += m.fiber;
    totalSodium += m.sodium;
  }

  return NutritionSummary(
    kcal: totalKcal,
    proteins: totalProteins,
    carbs: totalCarbs,
    fats: totalFats,
    fiber: totalFiber,
    sodium: totalSodium,
    meals: meals,
  );
}
