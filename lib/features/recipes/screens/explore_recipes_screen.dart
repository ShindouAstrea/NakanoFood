import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../models/recipe_suggestion.dart';
import '../providers/explore_recipes_provider.dart';
import '../providers/recipe_provider.dart';

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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 11, color: colorScheme.tertiary),
                  const SizedBox(width: 3),
                  Text(
                    'IA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.tertiary,
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
          // Banner "Próximamente"
          _AiBanner(),

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

// ── Banner IA próximamente ───────────────────────────────────────────────────

class _AiBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.tertiary.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 18, color: colorScheme.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Las recomendaciones con IA estarán disponibles próximamente. '
              'Por ahora se muestran recetas populares de muestra.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withAlpha(160),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loading ─────────────────────────────────────────────────────────

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        height: 110,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(12),
        ),
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
      final recipe = Recipe(
        id: _uuid.v4(),
        name: s.name,
        type: s.type,
        description: s.description,
        portions: 1,
        prepTime: s.estimatedMinutes != null
            ? (s.estimatedMinutes! ~/ 2)
            : null,
        cookTime: s.estimatedMinutes != null
            ? (s.estimatedMinutes! - s.estimatedMinutes! ~/ 2)
            : null,
        notes: s.reason,
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
        child: Padding(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            const SizedBox(height: 10),

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
                          color: _difficultyColor(s.difficulty!, colorScheme),
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
                              size: 16,
                              color: Colors.green.shade600),
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
                                  color: colorScheme.onSecondaryContainer,
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
        Text(label, style: TextStyle(fontSize: 11, color: color)),
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

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
                        background:
                            colorScheme.onSurface.withAlpha(15),
                      ),
                    if (s.difficulty != null)
                      _DetailChip(
                        icon: Icons.bar_chart_rounded,
                        label: s.difficulty!,
                        color: _difficultyColor(s.difficulty!, colorScheme),
                        background:
                            _difficultyColor(s.difficulty!, colorScheme)
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

                // Ingredientes y pasos (placeholder IA)
                const SizedBox(height: 24),
                Text('Ingredientes y preparación',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withAlpha(80),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: colorScheme.outline.withAlpha(40)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 32,
                          color: colorScheme.onSurface.withAlpha(60)),
                      const SizedBox(height: 8),
                      Text(
                        'Disponible cuando la IA esté conectada',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withAlpha(100),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Si agregas la receta ahora, podrás completar los ingredientes y pasos manualmente.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colorScheme.onSurface.withAlpha(80),
                        ),
                      ),
                    ],
                  ),
                ),

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
                        onPressed: loading ? null : () {
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
