import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/meal_planning_provider.dart';
import '../models/meal_plan.dart';
import 'add_edit_meal_screen.dart';
import 'manage_categories_screen.dart';
import 'nutrition_dashboard_screen.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeletons/meal_card_skeleton.dart';

class MealPlanningScreen extends ConsumerStatefulWidget {
  const MealPlanningScreen({super.key});

  @override
  ConsumerState<MealPlanningScreen> createState() => _MealPlanningScreenState();
}

class _MealPlanningScreenState extends ConsumerState<MealPlanningScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final datesWithPlansAsync = ref.watch(datesWithPlansProvider);
    final mealsForDayAsync = ref.watch(mealPlansForDateProvider);
    final theme = Theme.of(context);
    final Map<CalendarFormat, String> calendarFormat = {
      CalendarFormat.month: "Mes",
      CalendarFormat.twoWeeks: "2 Semanas",
      CalendarFormat.week: "Semana"
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planificación'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_heart_outlined),
            tooltip: 'Nutrición del día',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NutritionDashboardScreen()),
            ),
          ),
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
            margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outline.withAlpha(40),
              ),
            ),
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
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
                markerSize: 5,
                markerMargin: const EdgeInsets.only(top: 1),
                outsideDaysVisible: false,
                cellMargin: const EdgeInsets.all(4),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withAlpha(80)),
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: theme.textTheme.labelSmall!,
                leftChevronIcon: Icon(Icons.chevron_left,
                    color: theme.colorScheme.onSurface),
                rightChevronIcon: Icon(Icons.chevron_right,
                    color: theme.colorScheme.onSurface),
                headerPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
                weekendStyle: theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.error.withAlpha(160),
                ),
              ),
            ),
          ),

          // Day header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE', 'es').format(selectedDate),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        DateFormat('d \'de\' MMMM, yyyy', 'es').format(selectedDate),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                mealsForDayAsync.maybeWhen(
                  data: (meals) => meals.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${meals.length} comida${meals.length != 1 ? 's' : ''}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _addMeal(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // Meals for selected day
          Expanded(
            child: mealsForDayAsync.when(
              data: (meals) {
                if (meals.isEmpty) {
                  return SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.no_meals_outlined,
                      title: 'Sin comidas planificadas',
                      subtitle: 'Toca "Agregar" para planificar una comida',
                      actionLabel: 'Agregar comida',
                      onAction: () => _addMeal(context),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

  /// Convierte "08:00" → "8:00 AM" / "13:30" → "1:30 PM"
  String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1].padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

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
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Color accent bar
              Container(
                width: 5,
                color: catColor,
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category header row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: catColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.restaurant,
                                color: catColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal.categoryName ?? 'Sin categoría',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: catColor,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (meal.categoryDefaultTime != null) ...[
                                      Icon(
                                        Icons.schedule_outlined,
                                        size: 12,
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(120),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _formatTime(meal.categoryDefaultTime!),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withAlpha(160),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (meal.items.isNotEmpty)
                                        Text(
                                          ' · ',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withAlpha(80),
                                          ),
                                        ),
                                    ],
                                    if (meal.items.isNotEmpty)
                                      Text(
                                        '${meal.items.length} elemento${meal.items.length != 1 ? 's' : ''}',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withAlpha(100),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Actions menu
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                            onSelected: (val) {
                              if (val == 'edit') onEdit();
                              if (val == 'delete') onDelete();
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 16),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Eliminar',
                                        style:
                                            TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Items list
                      if (meal.items.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...meal.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Icon(
                                      item.recipeId != null
                                          ? Icons.menu_book_outlined
                                          : Icons.fiber_manual_record,
                                      size: item.recipeId != null ? 13 : 6,
                                      color: catColor.withAlpha(180),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(200),
                                        height: 1.4,
                                      ),
                                      // Allow wrapping for long text
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      // Notes
                      if (meal.notes != null && meal.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withAlpha(80),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.notes_outlined,
                                size: 13,
                                color: theme.colorScheme.onSurface.withAlpha(120),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  meal.notes!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(160),
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                                  // Allow up to 3 lines for notes
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
