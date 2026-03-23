import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/meal_planning_provider.dart';
import '../models/meal_plan.dart';
import 'add_edit_meal_screen.dart';
import 'manage_categories_screen.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeletons/meal_card_skeleton.dart';

class MealPlanningScreen extends ConsumerStatefulWidget {
  const MealPlanningScreen({super.key});

  @override
  ConsumerState<MealPlanningScreen> createState() => _MealPlanningScreenState();
}

class _MealPlanningScreenState extends ConsumerState<MealPlanningScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final datesWithPlansAsync = ref.watch(datesWithPlansProvider);
    final mealsForDayAsync = ref.watch(mealPlansForDateProvider);
    final Map<CalendarFormat, String> calendarFormat = {
      CalendarFormat.month: "Mes",
      CalendarFormat.twoWeeks: "2 Semanas",
      CalendarFormat.week: "Semana"
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planificación Alimentaria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Gestionar categorías',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
            ).then((_) => ref.invalidate(mealCategoriesProvider)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar
          Card(
            margin: const EdgeInsets.all(8),
            child: TableCalendar(
              locale: 'es_Es',
              startingDayOfWeek: StartingDayOfWeek.monday,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: selectedDate,
              calendarFormat: _calendarFormat,
              availableCalendarFormats: calendarFormat,
              selectedDayPredicate: (day) => isSameDay(selectedDate, day),
              onDaySelected: (selected, focused) {
                ref.read(selectedDateProvider.notifier).state =
                    DateTime(selected.year, selected.month, selected.day);
              },
              onFormatChanged: (format) =>
                  setState(() => _calendarFormat = format),
              eventLoader: (day) {
                final dates = datesWithPlansAsync.valueOrNull ?? {};
                final key = DateTime(day.year, day.month, day.day);
                return dates.contains(key) ? ['event'] : [];
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
              ),
            ),
          ),
          // Day header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, d MMMM', 'es').format(selectedDate),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: () => _addMeal(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
          ),
          // Meals for selected day
          Expanded(
            child: mealsForDayAsync.when(
              data: (meals) {
                if (meals.isEmpty) {
                  return EmptyState(
                    icon: Icons.no_meals_outlined,
                    title: 'Sin comidas planificadas',
                    subtitle: 'Toca "Agregar" para planificar una comida',
                    actionLabel: 'Agregar comida',
                    onAction: () => _addMeal(context),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: meals.length,
                  itemBuilder: (_, i) => _MealCard(
                    meal: meals[i],
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditMealScreen(meal: meals[i]),
                      ),
                    ).then((_) => ref.invalidate(mealPlansProvider)),
                    onDelete: () => _deleteMeal(context, ref, meals[i]),
                  ),
                );
              },
              loading: () => const MealListSkeleton(),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_meal_planning',
        onPressed: () => _addMeal(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addMeal(BuildContext context) {
    final selectedDate = ref.read(selectedDateProvider);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditMealScreen(initialDate: selectedDate),
      ),
    ).then((_) => ref.invalidate(mealPlansProvider));
  }

  Future<void> _deleteMeal(
      BuildContext context, WidgetRef ref, MealPlan meal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar comida'),
        content: Text(
            '¿Eliminar la comida de "${meal.categoryName ?? 'esta categoría'}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(mealPlansProvider.notifier).deleteMealPlan(meal.id);
    }
  }
}

class _MealCard extends StatelessWidget {
  final MealPlan meal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MealCard(
      {required this.meal, required this.onEdit, required this.onDelete});

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.grey;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = _parseColor(meal.categoryColor);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: catColor.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: catColor.withAlpha(100)),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.restaurant, color: catColor, size: 22),
        ),
        title: Text(
          meal.categoryName ?? 'Sin categoría',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: catColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...meal.items.map((item) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(
                        item.recipeId != null
                            ? Icons.menu_book_outlined
                            : Icons.circle,
                        size: item.recipeId != null ? 12 : 5,
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  theme.colorScheme.onSurface.withAlpha(180)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
            if (meal.notes != null) ...[
              const SizedBox(height: 4),
              Text(
                meal.notes!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        isThreeLine: meal.items.length > 1 || meal.notes != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
              color: Colors.grey.shade600,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onDelete,
              color: Colors.red.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
