import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/number_input.dart';
import '../../meal_planning/providers/meal_plan_needs.dart';
import '../../meal_planning/providers/meal_planning_provider.dart';
import '../../recipes/providers/recipe_provider.dart';
import '../providers/pantry_provider.dart';
import '../providers/shopping_provider.dart';

/// Abre la hoja que arma la lista de compras con lo que falta para cocinar el
/// plan de comidas.
///
/// Es el único sitio donde se cruzan los tres módulos: el calendario dice qué
/// se va a cocinar, las recetas qué lleva cada cosa, y la despensa qué hay ya.
Future<void> startShoppingForPlan(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const PlanShoppingSheet(),
  );
}

/// Elige el rango de días y muestra qué habría que comprar para cubrirlo.
///
/// Queda pública para poder montarla en un test de widget.
class PlanShoppingSheet extends ConsumerStatefulWidget {
  const PlanShoppingSheet({super.key});

  @override
  ConsumerState<PlanShoppingSheet> createState() => _PlanShoppingSheetState();
}

class _PlanShoppingSheetState extends ConsumerState<PlanShoppingSheet> {
  static const _rangeOptions = [3, 7, 14];

  int _days = 7;

  /// Productos que el usuario destildó. Se guarda la exclusión y no la
  /// inclusión para que cambiar el rango no pierda lo que ya decidió.
  final _excluded = <String>{};

  bool _creating = false;

  DateTime get _from {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _to => _from.add(Duration(days: _days - 1));

  String get _rangeLabel {
    final format = DateFormat('d MMM', 'es');
    return '${format.format(_from)} – ${format.format(_to)}';
  }

  Future<void> _create(MealPlanNeeds plan) async {
    final selected =
        plan.toBuy.where((n) => !_excluded.contains(n.product.id));
    setState(() => _creating = true);
    await ref.read(activeSessionProvider.notifier).startSessionFromPlan(
          shoppingQuantities(selected),
          notes: 'Plan de comidas · $_rangeLabel',
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final media = MediaQuery.of(context);

    final plansAsync = ref.watch(mealPlansProvider);
    final recipesAsync = ref.watch(recipesProvider);
    final productsAsync = ref.watch(productsProvider);

    final plan = (plansAsync.valueOrNull == null ||
            recipesAsync.valueOrNull == null ||
            productsAsync.valueOrNull == null)
        ? null
        : MealPlanNeeds.build(
            plans: plansAsync.value!,
            recipes: recipesAsync.value!,
            products: productsAsync.value!,
            from: _from,
            to: _to,
          );

    final selectedCount = plan == null
        ? 0
        : plan.toBuy.where((n) => !_excluded.contains(n.product.id)).length;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(theme, cs, plan),
            Flexible(
              child: plan == null
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _body(theme, cs, plan),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: selectedCount == 0 || _creating
                        ? null
                        : () => _create(plan!),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(selectedCount == 0
                        ? 'Nada que comprar'
                        : 'Crear lista ($selectedCount)'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, ColorScheme cs, MealPlanNeeds? plan) {
    final subtitle = plan == null
        ? _rangeLabel
        : '$_rangeLabel · ${plan.mealsPlanned} '
            '${plan.mealsPlanned == 1 ? 'comida' : 'comidas'} con receta';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comprar para el plan',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurface.withAlpha(150)),
          ),
          const SizedBox(height: 12),
          // Wrap y no Row: con el texto en tamaño grande los tres chips no
          // caben en una línea de teléfono, y una fila fija se desborda.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final days in _rangeOptions)
                ChoiceChip(
                  label: Text('$days días'),
                  selected: _days == days,
                  onSelected: (_) => setState(() => _days = days),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(ThemeData theme, ColorScheme cs, MealPlanNeeds plan) {
    if (plan.hasNothingPlanned) {
      return _emptyMessage(
        theme,
        cs,
        icon: Icons.event_busy_rounded,
        title: 'Nada planificado en estos días',
        detail: plan.mealsWithoutRecipe > 0
            ? 'Hay ${plan.mealsWithoutRecipe} comidas anotadas, pero ninguna '
                'está vinculada a una receta, así que no se sabe qué lleva.'
            : 'Planifica comidas con recetas y aquí saldrá qué te falta.',
      );
    }

    if (!plan.hasSomethingToBuy && plan.skipped.isEmpty) {
      return _emptyMessage(
        theme,
        cs,
        icon: Icons.check_circle_outline_rounded,
        title: 'Ya tienes todo',
        detail: 'La despensa cubre las ${plan.mealsPlanned} comidas '
            'planificadas de estos días.',
      );
    }

    final covered = plan.covered;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final need in plan.toBuy) _needTile(theme, cs, need),
        if (covered.isNotEmpty) ...[
          _sectionTitle(theme, cs, 'Ya tienes (${covered.length})'),
          for (final need in covered) _coveredTile(theme, cs, need),
        ],
        if (plan.skipped.isNotEmpty) ...[
          _sectionTitle(theme, cs, 'No se pueden agregar'),
          for (final ingredient in plan.skipped)
            _skippedTile(theme, cs, ingredient),
        ],
        if (plan.mealsWithoutRecipe > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text(
              '${plan.mealsWithoutRecipe} '
              '${plan.mealsWithoutRecipe == 1 ? 'comida anotada' : 'comidas anotadas'} '
              'sin receta no se pudieron calcular.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withAlpha(130)),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _needTile(ThemeData theme, ColorScheme cs, PlannedNeed need) {
    final included = !_excluded.contains(need.product.id);
    final unit = need.product.unit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        children: [
          Checkbox(
            value: included,
            onChanged: (value) => setState(() {
              if (value ?? false) {
                _excluded.remove(need.product.id);
              } else {
                _excluded.add(need.product.id);
              }
            }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  need.product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: included ? null : cs.onSurface.withAlpha(110),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Tienes ${formatQuantity(need.available)} de '
                  '${formatQuantity(need.needed)} $unit · '
                  '${need.meals} ${need.meals == 1 ? 'comida' : 'comidas'}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurface.withAlpha(140)),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${formatQuantity(need.missing)} $unit',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: included ? cs.primary : cs.onSurface.withAlpha(110),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coveredTile(ThemeData theme, ColorScheme cs, PlannedNeed need) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Row(
        children: [
          Icon(Icons.check_rounded, size: 16, color: cs.onSurface.withAlpha(90)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              need.product.name,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withAlpha(150)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'necesitas ${formatQuantity(need.needed)} ${need.product.unit}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurface.withAlpha(130)),
          ),
        ],
      ),
    );
  }

  Widget _skippedTile(
      ThemeData theme, ColorScheme cs, UnplannedIngredient ingredient) {
    // Los dos motivos se arreglan en sitios distintos, así que se dicen por
    // separado: uno creando el producto, el otro declarando su equivalencia.
    final reason = ingredient.isMissingFromPantry
        ? 'no está en la despensa'
        : 'no consta cuántos ${ingredient.recipeUnit} rinde '
            '1 ${ingredient.productUnit}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.remove_rounded,
              size: 16, color: cs.onSurface.withAlpha(90)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: ingredient.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: ' — $reason'),
                ],
              ),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withAlpha(150)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, ColorScheme cs, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: cs.onSurface.withAlpha(150)),
      ),
    );
  }

  Widget _emptyMessage(
    ThemeData theme,
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: cs.onSurface.withAlpha(90)),
          const SizedBox(height: 12),
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurface.withAlpha(140), height: 1.4),
          ),
        ],
      ),
    );
  }
}
