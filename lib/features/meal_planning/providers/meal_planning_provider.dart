import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_write_helper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/sync_service.dart';
import '../models/meal_category.dart';
import '../models/meal_plan.dart';
import '../models/meal_plan_item.dart';

const _uuid = Uuid();

// ─── Meal Categories ──────────────────────────────────────────────────────────

final mealCategoriesProvider =
    AsyncNotifierProvider<MealCategoriesNotifier, List<MealCategory>>(
  MealCategoriesNotifier.new,
);

class MealCategoriesNotifier extends AsyncNotifier<List<MealCategory>> {
  @override
  Future<List<MealCategory>> build() => _load();

  String? get _uid => ref.read(currentUserIdProvider);

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
    await db.insert('meal_categories', withSync(category.toMap(), _uid));
    for (final day in category.daysOfWeek) {
      await db.insert('meal_category_days', withSync({
        'id': _uuid.v4(),
        'category_id': category.id,
        'day_of_week': day,
      }, _uid));
    }
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> updateCategory(MealCategory category) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'meal_categories',
      withSync(category.toMap(), _uid),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    await db.delete('meal_category_days',
        where: 'category_id = ?', whereArgs: [category.id]);
    for (final day in category.daysOfWeek) {
      await db.insert('meal_category_days', withSync({
        'id': _uuid.v4(),
        'category_id': category.id,
        'day_of_week': day,
      }, _uid));
    }
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> deleteCategory(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('meal_categories', where: 'id = ?', whereArgs: [id]);
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
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

  String? get _uid => ref.read(currentUserIdProvider);

  Future<List<MealPlan>> _loadAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.rawQuery('''
      SELECT mp.*,
             mc.name as category_name,
             mc.color as category_color
      FROM meal_plans mp
      LEFT JOIN meal_categories mc ON mp.category_id = mc.id
      ORDER BY mp.date ASC, mc.default_time ASC
    ''');

    final plans = <MealPlan>[];
    for (final m in maps) {
      final plan = MealPlan.fromMap(m);
      final itemMaps = await db.rawQuery('''
        SELECT mpi.*, r.name as recipe_name
        FROM meal_plan_items mpi
        LEFT JOIN recipes r ON mpi.recipe_id = r.id
        WHERE mpi.meal_plan_id = ?
        ORDER BY mpi.sort_order ASC
      ''', [plan.id]);
      final items = itemMaps.map(MealPlanItem.fromMap).toList();
      plans.add(plan.copyWith(items: items));
    }
    return plans;
  }

  Future<void> addMealPlan(MealPlan plan) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('meal_plans', withSync(plan.toMap(), _uid));
    for (final item in plan.items) {
      await db.insert('meal_plan_items', withSync(item.toMap(), _uid));
    }
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> updateMealPlan(MealPlan plan) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'meal_plans',
      withSync(plan.toMap(), _uid),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
    await db.delete('meal_plan_items',
        where: 'meal_plan_id = ?', whereArgs: [plan.id]);
    for (final item in plan.items) {
      await db.insert('meal_plan_items', withSync(item.toMap(), _uid));
    }
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> deleteMealPlan(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('meal_plans', where: 'id = ?', whereArgs: [id]);
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }
}

// ─── Derived providers ────────────────────────────────────────────────────────

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

final datesWithPlansProvider = Provider<AsyncValue<Set<DateTime>>>((ref) {
  final plans = ref.watch(mealPlansProvider);
  return plans.whenData((list) => list
      .map((p) => DateTime(p.date.year, p.date.month, p.date.day))
      .toSet());
});
