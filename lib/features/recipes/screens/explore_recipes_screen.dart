import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../models/recipe_suggestion.dart';
import '../providers/explore_recipes_provider.dart';
import '../providers/recipe_provider.dart';
import '../../../shared/widgets/skeletons/shimmer_box.dart';

const _uuid = Uuid();

class ExploreRecipesScreen extends ConsumerWidget {
  const ExploreRecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(exploreSuggestionsProvider);
    final typeFilter = ref.watch(exploreTypeFilterProvider);
    final savedNames = ref
            .watch(recipesProvider)
            .valueOrNull
            ?.map((r) => r.name.toLowerCase())
            .toSet() ??
        {};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Explorar recetas'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.tertiary.withAlpha(80),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(Icons.auto_awesome_rounded,
                      size: 11),
                   SizedBox(width: 3),
                   Text(
                    'IA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,

                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recargar',
            onPressed: suggestionsAsync.isLoading
                ? null
                : () =>
                    ref.read(exploreSuggestionsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _AiBanner(isLoading: suggestionsAsync.isLoading),

          // Filtro por tipo
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('Todos'),
                    selected: typeFilter == null,
                    onSelected: (_) =>
                        ref.read(exploreTypeFilterProvider.notifier).state =
                            null,
                  ),
                ),
                ...recipeTypes.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(type),
                        selected: typeFilter == type,
                        onSelected: (_) => ref
                            .read(exploreTypeFilterProvider.notifier)
                            .state = typeFilter == type ? null : type,
                      ),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Lista de sugerencias
          Expanded(
            child: suggestionsAsync.when(
              loading: () => const _LoadingList(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: colorScheme.error),
                    const SizedBox(height: 12),
                    Text('No se pudieron cargar sugerencias',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => ref
                          .read(exploreSuggestionsProvider.notifier)
                          .refresh(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (suggestions) {
                if (suggestions.isEmpty) {
                  return Center(
                    child: Text(
                      'Sin sugerencias para este tipo',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: suggestions.length,
                  itemBuilder: (_, i) => _SuggestionCard(
                    suggestion: suggestions[i],
                    alreadySaved: savedNames
                        .contains(suggestions[i].name.toLowerCase()),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner IA ────────────────────────────────────────────────────────────────

class _AiBanner extends StatelessWidget {
  final bool isLoading;
  const _AiBanner({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(isLoading),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.tertiary.withAlpha(isLoading ? 30 : 20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.tertiary.withAlpha(60)),
        ),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.tertiary,
                ),
              )
            else
              Icon(Icons.auto_awesome_rounded,
                  size: 18, color: colorScheme.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLoading
                    ? 'Consultando IA, generando recomendaciones...'
                    : 'Recomendaciones personalizadas generadas con IA según tus recetas guardadas.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withAlpha(isLoading ? 200 : 160),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton loading ─────────────────────────────────────────────────────────

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: 5,
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen skeleton
          const ShimmerBox(width: double.infinity, height: 130, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título + tipo chip
                const Row(
                  children: [
                    ShimmerBox(width: 160, height: 14, borderRadius: 6),
                    Spacer(),
                    ShimmerBox(width: 60, height: 22, borderRadius: 20),
                  ],
                ),
                const SizedBox(height: 10),
                // Descripción línea 1
                const ShimmerBox(
                    width: double.infinity, height: 11, borderRadius: 6),
                const SizedBox(height: 6),
                // Descripción línea 2
                ShimmerBox(
                  width: MediaQuery.of(context).size.width * 0.55,
                  height: 11,
                  borderRadius: 6,
                ),
                const SizedBox(height: 12),
                // Chips + botón
                const Row(
                  children: [
                    ShimmerBox(width: 70, height: 14, borderRadius: 6),
                    SizedBox(width: 12),
                    ShimmerBox(width: 60, height: 14, borderRadius: 6),
                    Spacer(),
                    ShimmerBox(width: 72, height: 30, borderRadius: 20),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de sugerencia ────────────────────────────────────────────────────

class _SuggestionCard extends ConsumerStatefulWidget {
  final RecipeSuggestion suggestion;
  final bool alreadySaved;

  const _SuggestionCard({
    required this.suggestion,
    required this.alreadySaved,
  });

  @override
  ConsumerState<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<_SuggestionCard> {
  late bool _saved;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.alreadySaved;
  }

  Future<void> _add() async {
    if (_saved || _loading) return;
    setState(() => _loading = true);

    try {
      final s = widget.suggestion;
      final now = DateTime.now();
      final recipeId = _uuid.v4();
      final ingredients = s.ingredients
          .map((i) => RecipeIngredient(
                id: _uuid.v4(),
                recipeId: recipeId,
                productName: i.name,
                quantity: i.quantity,
                unit: i.unit,
              ))
          .toList();
      final steps = s.steps
          .map((st) => RecipeStep(
                id: _uuid.v4(),
                recipeId: recipeId,
                stepNumber: st.step,
                description: st.description,
              ))
          .toList();
      final recipe = Recipe(
        id: recipeId,
        name: s.name,
        type: s.type,
        description: s.description,
        portions: 2,
        prepTime: s.estimatedMinutes != null
            ? (s.estimatedMinutes! ~/ 2)
            : null,
        cookTime: s.estimatedMinutes != null
            ? (s.estimatedMinutes! - s.estimatedMinutes! ~/ 2)
            : null,
        notes: s.reason,
        mainImagePath: s.imageUrl,
        ingredients: ingredients,
        steps: steps,
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(recipesProvider.notifier).addRecipe(recipe);

      if (mounted) {
        setState(() {
          _saved = true;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${s.name}" agregada a tus recetas'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo agregar la receta.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = widget.suggestion;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen de referencia
            if (s.imageUrl != null)
              Image.network(
                s.imageUrl!,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                frameBuilder: (_, child, frame, __) => AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 350),
                  child: child,
                ),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),

            // Contenido
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + tipo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s.type,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Descripción
                  Text(
                    s.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withAlpha(160),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Indicador ingredientes + pasos
                  if (s.ingredients.isNotEmpty || s.steps.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 13,
                              color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          Text(
                            [
                              if (s.ingredients.isNotEmpty)
                                '${s.ingredients.length} ingredientes',
                              if (s.steps.isNotEmpty)
                                '${s.steps.length} pasos',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Meta + botón agregar
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            if (s.estimatedMinutes != null)
                              _Chip(
                                icon: Icons.timer_outlined,
                                label: '${s.estimatedMinutes} min',
                                color: colorScheme.onSurface.withAlpha(130),
                              ),
                            if (s.difficulty != null)
                              _Chip(
                                icon: Icons.bar_chart_rounded,
                                label: s.difficulty!,
                                color:
                                    _difficultyColor(s.difficulty!, colorScheme),
                              ),
                            if (s.reason != null)
                              _Chip(
                                icon: Icons.auto_awesome_rounded,
                                label: s.reason!,
                                color: colorScheme.tertiary.withAlpha(180),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botón agregar / guardada
                      _saved
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 16, color: Colors.green.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  'Guardada',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            )
                          : FilledButton.tonal(
                              onPressed: _loading ? null : _add,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: _loading
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            colorScheme.onSecondaryContainer,
                                      ),
                                    )
                                  : const Text('Agregar',
                                      style: TextStyle(fontSize: 12)),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final s = widget.suggestion;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SuggestionDetailSheet(
        suggestion: s,
        saved: _saved,
        loading: _loading,
        onAdd: _add,
      ),
    );
  }

  Color _difficultyColor(String difficulty, ColorScheme cs) {
    switch (difficulty) {
      case 'Fácil':
        return Colors.green.shade600;
      case 'Difícil':
        return cs.error;
      default:
        return Colors.orange.shade700;
    }
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Bottom sheet de detalle ──────────────────────────────────────────────────

class _SuggestionDetailSheet extends StatelessWidget {
  final RecipeSuggestion suggestion;
  final bool saved;
  final bool loading;
  final VoidCallback onAdd;

  const _SuggestionDetailSheet({
    required this.suggestion,
    required this.saved,
    required this.loading,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = suggestion;

    final hasContent =
        suggestion.ingredients.isNotEmpty || suggestion.steps.isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: hasContent ? 0.85 : 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withAlpha(40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                // Imagen
                if (s.imageUrl != null)
                  Image.network(
                    s.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    frameBuilder: (_, child, frame, __) => AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 350),
                      child: child,
                    ),
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),

                // Contenido
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre
                      Text(
                        s.name,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),

                      // Chips de meta
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _DetailChip(
                            icon: Icons.restaurant_menu_rounded,
                            label: s.type,
                            color: colorScheme.primary,
                            background: colorScheme.primary.withAlpha(20),
                          ),
                          if (s.estimatedMinutes != null)
                            _DetailChip(
                              icon: Icons.timer_outlined,
                              label: '${s.estimatedMinutes} min',
                              color: colorScheme.onSurface.withAlpha(160),
                              background: colorScheme.onSurface.withAlpha(15),
                            ),
                          if (s.difficulty != null)
                            _DetailChip(
                              icon: Icons.bar_chart_rounded,
                              label: s.difficulty!,
                              color: _difficultyColor(s.difficulty!, colorScheme),
                              background: _difficultyColor(s.difficulty!, colorScheme)
                                  .withAlpha(20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Descripción
                      Text('Descripción',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        s.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withAlpha(180),
                          height: 1.5,
                        ),
                      ),

                      // Razón IA
                      if (s.reason != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: colorScheme.tertiary.withAlpha(60)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  size: 16, color: colorScheme.tertiary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.reason!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withAlpha(160),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Ingredientes
                      if (s.ingredients.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Ingredientes',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...s.ingredients.map((i) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Icon(Icons.fiber_manual_record,
                                      size: 6,
                                      color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      i.name,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  Text(
                                    '${i.quantity % 1 == 0 ? i.quantity.toInt() : i.quantity} ${i.unit}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          colorScheme.onSurface.withAlpha(150),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],

                      // Pasos
                      if (s.steps.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Preparación',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...s.steps.map((st) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.primary.withAlpha(18),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${st.step}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      st.description,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface
                                            .withAlpha(180),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],

                      const SizedBox(height: 24),

                      // Botón agregar
                      saved
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.green.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  'Ya está en tus recetas',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            )
                          : FilledButton.icon(
                              onPressed: loading
                                  ? null
                                  : () {
                                      onAdd();
                                      Navigator.pop(context);
                                    },
                              icon: loading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.add_rounded),
                              label: const Text('Agregar a mis recetas'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _difficultyColor(String difficulty, ColorScheme cs) {
    switch (difficulty) {
      case 'Fácil':
        return Colors.green.shade600;
      case 'Difícil':
        return cs.error;
      default:
        return Colors.orange.shade700;
    }
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
