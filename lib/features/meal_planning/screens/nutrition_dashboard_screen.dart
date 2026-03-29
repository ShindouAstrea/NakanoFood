import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/nutrition_provider.dart';
import '../models/nutrition_summary.dart';

// WHO daily reference values
const _rdaKcal = 2000.0;
const _rdaProteins = 50.0;
const _rdaCarbs = 260.0;
const _rdaFats = 70.0;
const _rdaFiber = 25.0;
const _rdaSodium = 2300.0; // mg

class NutritionDashboardScreen extends ConsumerStatefulWidget {
  const NutritionDashboardScreen({super.key});

  @override
  ConsumerState<NutritionDashboardScreen> createState() =>
      _NutritionDashboardScreenState();
}

class _NutritionDashboardScreenState
    extends ConsumerState<NutritionDashboardScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _changeDay(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryAsync =
        ref.watch(dailyNutritionProvider(_selectedDate));
    final today = DateTime.now();
    final isToday = _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrición del día'),
      ),
      body: Column(
        children: [
          // Date navigator
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                    color: theme.colorScheme.onSurface.withAlpha(15)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _changeDay(-1),
                ),
                GestureDetector(
                  onTap: isToday
                      ? null
                      : () {
                          final now = DateTime.now();
                          setState(() => _selectedDate =
                              DateTime(now.year, now.month, now.day));
                        },
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEEE', 'es').format(_selectedDate),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        isToday
                            ? 'Hoy · ${DateFormat('d MMM', 'es').format(_selectedDate)}'
                            : DateFormat('d MMM yyyy', 'es')
                                .format(_selectedDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: isToday ? null : () => _changeDay(1),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: summaryAsync.when(
              data: (summary) => summary.isEmpty
                  ? _EmptyNutrition(date: _selectedDate)
                  : _NutritionContent(summary: summary),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNutrition extends StatelessWidget {
  final DateTime date;
  const _EmptyNutrition({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_meals_outlined,
                size: 48, color: colorScheme.onSurface.withAlpha(60)),
            const SizedBox(height: 16),
            Text(
              'Sin comidas planificadas',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega comidas al plan de este día\npara ver el resumen nutricional.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withAlpha(120), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionContent extends StatelessWidget {
  final NutritionSummary summary;
  const _NutritionContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Calories card
        _CaloriesCard(summary: summary),
        const SizedBox(height: 12),

        // Macros
        _MacrosCard(summary: summary),
        const SizedBox(height: 12),

        // Other nutrients
        _OtherNutrientsCard(summary: summary),
        const SizedBox(height: 12),

        // Meal breakdown
        if (summary.meals.isNotEmpty) _MealBreakdownCard(summary: summary),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Calories card ─────────────────────────────────────────────────────────────

class _CaloriesCard extends StatelessWidget {
  final NutritionSummary summary;
  const _CaloriesCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (summary.kcal / _rdaKcal).clamp(0.0, 1.0);
    final pct = (summary.kcal / _rdaKcal * 100).round();
    final color = _progressColor(progress);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    color: color, size: 20),
                const SizedBox(width: 8),
                Text('Calorías',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  '${summary.kcal.round()} / ${_rdaKcal.round()} kcal',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(140)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor:
                    theme.colorScheme.onSurface.withAlpha(15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              pct >= 100
                  ? 'Objetivo alcanzado ($pct%)'
                  : 'Falta ${(_rdaKcal - summary.kcal).round()} kcal para el objetivo ($pct%)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(120)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Macros card ───────────────────────────────────────────────────────────────

class _MacrosCard extends StatelessWidget {
  final NutritionSummary summary;
  const _MacrosCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Macronutrientes',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _MacroRow(
              label: 'Proteínas',
              value: summary.proteins,
              rda: _rdaProteins,
              unit: 'g',
              color: Colors.blue.shade600,
            ),
            const SizedBox(height: 8),
            _MacroRow(
              label: 'Carbohidratos',
              value: summary.carbs,
              rda: _rdaCarbs,
              unit: 'g',
              color: Colors.orange.shade600,
            ),
            const SizedBox(height: 8),
            _MacroRow(
              label: 'Grasas',
              value: summary.fats,
              rda: _rdaFats,
              unit: 'g',
              color: Colors.purple.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final double value;
  final double rda;
  final String unit;
  final Color color;

  const _MacroRow({
    required this.label,
    required this.value,
    required this.rda,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (value / rda).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(1)} / ${rda.toStringAsFixed(0)} $unit',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(130)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor:
                theme.colorScheme.onSurface.withAlpha(12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Other nutrients card ──────────────────────────────────────────────────────

class _OtherNutrientsCard extends StatelessWidget {
  final NutritionSummary summary;
  const _OtherNutrientsCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (summary.fiber == 0 && summary.sodium == 0) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Otros nutrientes',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (summary.fiber > 0)
              _MacroRow(
                label: 'Fibra',
                value: summary.fiber,
                rda: _rdaFiber,
                unit: 'g',
                color: Colors.green.shade600,
              ),
            if (summary.fiber > 0 && summary.sodium > 0)
              const SizedBox(height: 8),
            if (summary.sodium > 0)
              _MacroRow(
                label: 'Sodio',
                value: summary.sodium,
                rda: _rdaSodium,
                unit: 'mg',
                color: Colors.red.shade400,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Meal breakdown card ───────────────────────────────────────────────────────

class _MealBreakdownCard extends StatelessWidget {
  final NutritionSummary summary;
  const _MealBreakdownCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mealsWithData = summary.meals.where((m) => m.hasData).toList();
    if (mealsWithData.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Desglose por comida',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...mealsWithData.map((meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (meal.categoryName != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                meal.categoryName!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              meal.mealTitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${meal.kcal.round()} kcal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _progressColor(
                                  meal.kcal / _rdaKcal),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'P: ${meal.proteins.toStringAsFixed(1)}g  '
                        'C: ${meal.carbs.toStringAsFixed(1)}g  '
                        'G: ${meal.fats.toStringAsFixed(1)}g',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withAlpha(110)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

Color _progressColor(double progress) {
  if (progress >= 1.0) return Colors.green.shade600;
  if (progress >= 0.6) return Colors.orange.shade600;
  return Colors.blue.shade500;
}
