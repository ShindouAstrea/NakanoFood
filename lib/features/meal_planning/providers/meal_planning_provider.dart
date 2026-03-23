import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../models/meal_category.dart';
import '../models/meal_plan.dart';

const _uuid = Uuid();

// ─── Meal Categories ──────────────────────────────────────────────────────────

final mealCategoriesProvider =
    AsyncNotifierProvider<MealCategoriesNotifier, List<MealCategory>>(
  MealCategoriesNotifier.new,
);

class MealCategoriesNotifier extends AsyncNotifier<List<MealCategory>> {
  @override
  Future<List<MealCategory>> build() => _load();

  Future<List<MealCategory>> _load() async {
    final db = await DatabaseHelper.instance.database;
    final catMaps = await db.query('meal_categories', orderBy: 'name ASC');
    final dayMaps = await db.query('meal_category_days');

    return catMaps.map((m) {
      final cat = MealCategory.fromMap(m);
      final days = dayMaps
          .where((d) => d['category_id'] == cat.id)
          .map((d) => d['day_of_week'] as int)
          .toList();
      return cat.copyWith(daysOfWeek: days);
    }).toList();
  }

  Future<void> addCategory(MealCategory category) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('meal_categories', category.toMap());
    for (final day in category.daysOfWeek) {
      await db.insert('meal_category_days', {
        'id': _uuid.v4(),
        'category_id': category.id,
        'day_of_week': day,
      });
    }
    ref.invalidateSelf();
  }

  Future<void> updateCategory(MealCategory category) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'meal_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    await db.delete('meal_category_days',
        where: 'category_id = ?', whereArgs: [category.id]);
    for (final day in category.daysOfWeek) {
      await db.insert('meal_category_days', {
        'id': _uuid.v4(),
        'category_id': category.id,
        'day_of_week': day,
      });
    }
    ref.invalidateSelf();
  }

  Future<void> deleteCategory(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('meal_categories', where: 'id = ?', whereArgs: [id]);
    ref.invalidateSelf();
  }
}

// ─── Meal Plans ───────────────────────────────────────────────────────────────

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final mealPlansProvider =
    AsyncNotifierProvider<MealPlansNotifier, List<MealPlan>>(
  MealPlansNotifier.new,
);

class MealPlansNotifier extends AsyncNotifier<List<MealPlan>> {
  @override
  Future<List<MealPlan>> build() => _loadAll();

  Future<List<MealPlan>> _loadAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.rawQuery('''
      SELECT mp.*,
             mc.name as category_name,
             mc.color as category_color,
             r.name as recipe_name
      FROM meal_plans mp
      LEFT JOIN meal_categories mc ON mp.category_id = mc.id
      LEFT JOIN recipes r ON mp.recipe_id = r.id
      ORDER BY mp.date ASC, mc.default_time ASC
    ''');
    return maps.map(MealPlan.fromMap).toList();
  }

  Future<void> addMealPlan(MealPlan plan) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('meal_plans', plan.toMap());
    ref.invalidateSelf();
  }

  Future<void> updateMealPlan(MealPlan plan) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('meal_plans', plan.toMap(),
        where: 'id = ?', whereArgs: [plan.id]);
    ref.invalidateSelf();
  }

  Future<void> deleteMealPlan(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('meal_plans', where: 'id = ?', whereArgs: [id]);
    ref.invalidateSelf();
  }
}

// Plans for selected date
final mealPlansForDateProvider = Provider<AsyncValue<List<MealPlan>>>((ref) {
  final plans = ref.watch(mealPlansProvider);
  final selected = ref.watch(selectedDateProvider);

  return plans.whenData(
    (list) => list
        .where((p) =>
            p.date.year == selected.year &&
            p.date.month == selected.month &&
            p.date.day == selected.day)
        .toList(),
  );
});

// Dates that have meal plans (for calendar markers)
final datesWithPlansProvider = Provider<AsyncValue<Set<DateTime>>>((ref) {
  final plans = ref.watch(mealPlansProvider);
  return plans.whenData((list) => list
      .map((p) => DateTime(p.date.year, p.date.month, p.date.day))
      .toSet());
});
