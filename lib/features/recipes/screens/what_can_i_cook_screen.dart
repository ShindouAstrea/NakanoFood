import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cookable_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/recipe_image.dart';
import 'recipe_detail_screen.dart';

/// Cruza la despensa con las recetas guardadas y muestra qué se puede cocinar
/// ahora mismo, qué está cerca y qué no se pudo comprobar.
class WhatCanICookScreen extends ConsumerWidget {
  const WhatCanICookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cookableAsync = ref.watch(cookableRecipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('¿Qué puedo cocinar?')),
      body: cookableAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No se pudieron revisar tus recetas.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Sin recetas guardadas',
              subtitle: 'Guarda recetas y te diremos cuáles puedes cocinar',
            );
          }

          final ready = items.where((c) => c.canCook).toList();
          final close = items.where((c) => c.isClose).toList();
          final rest = items
              .where((c) => !c.canCook && !c.isClose)
              .toList();

          // Si nada se pudo cruzar, el problema no son las recetas.
          final allUnlinked = items.every((c) => c.isUnlinked);

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            children: [
              if (allUnlinked) const _UnlinkedNotice(),
              if (ready.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Puedes cocinarlas ya',
                  count: ready.length,
                  color: Theme.of(context).colorScheme.primary,
                ),
                ...ready.map((c) => _CookableCard(cookable: c)),
              ],
              if (close.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Te falta poco',
                  count: close.length,
                  color: const Color(0xFFB26B00),
                ),
                ...close.map((c) => _CookableCard(cookable: c)),
              ],
              if (rest.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Más lejos',
                  count: rest.length,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                ),
                ...rest.map((c) => _CookableCard(cookable: c)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _UnlinkedNotice extends StatelessWidget {
  const _UnlinkedNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.link_off_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sin recetas vinculadas',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Para saber qué puedes cocinar, agrega productos a tu '
                    'despensa con los mismos nombres que usas en las recetas.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(130),
                ),
          ),
        ],
      ),
    );
  }
}

class _CookableCard extends StatelessWidget {
  final Cookable cookable;

  const _CookableCard({required this.cookable});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final recipe = cookable.recipe;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: RecipeImage(
                    imagePath: recipe.mainImagePath,
                    fit: BoxFit.cover,
                    placeholderBuilder: (cs) => Container(
                      color: cs.primaryContainer,
                      child: Icon(Icons.restaurant_rounded,
                          color: cs.onPrimaryContainer, size: 22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _statusLine(theme, cs),
                  ],
                ),
              ),
              if (cookable.canCook)
                Icon(Icons.check_circle_rounded, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusLine(ThemeData theme, ColorScheme cs) {
    final style = theme.textTheme.bodySmall;

    if (cookable.recipe.ingredients.isEmpty) {
      return Text('Esta receta no tiene ingredientes',
          style: style?.copyWith(color: cs.onSurface.withAlpha(130)));
    }
    if (cookable.canCook) {
      return Text('Tienes todo',
          style: style?.copyWith(color: cs.primary, fontWeight: FontWeight.w600));
    }
    if (cookable.isUnlinked) {
      return Text('Sin recetas vinculadas',
          style: style?.copyWith(color: cs.onSurface.withAlpha(130)));
    }

    // "Faltan ingredientes" con el detalle de cuáles, hasta tres.
    final names = cookable.missing.take(3).map((i) => i.productName).join(', ');
    final extra = cookable.missing.length > 3
        ? ' y ${cookable.missing.length - 3} más'
        : '';
    return Text(
      cookable.missing.isEmpty
          ? 'Faltan ingredientes por comprobar'
          : 'Faltan ingredientes: $names$extra',
      style: style?.copyWith(color: cs.error),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
