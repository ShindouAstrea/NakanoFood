import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shopping_provider.dart';
import '../providers/pantry_provider.dart';
import '../providers/consumption_prediction_provider.dart';
import '../models/shopping_session.dart';
import '../widgets/shopping_item_tile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/utils/currency.dart';
import 'shopping_history_screen.dart';

String _fmtN(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ir de Compras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ShoppingHistoryScreen()),
            ),
          ),
        ],
      ),
      body: sessionAsync.when(
        data: (session) => session == null
            ? _NoActiveSession(
                onStart: () async {
                  await ref
                      .read(activeSessionProvider.notifier)
                      .startNewSession();
                },
              )
            : _ActiveSession(session: session),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── Sin sesión activa ────────────────────────────────────────────────────────

class _NoActiveSession extends ConsumerWidget {
  final VoidCallback onStart;
  const _NoActiveSession({required this.onStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final predictionsAsync = ref.watch(consumptionPredictionsProvider);

    final urgent = predictionsAsync.valueOrNull
            ?.where((p) =>
                p.urgency == StockUrgency.critical ||
                p.urgency == StockUrgency.warning)
            .toList() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withAlpha(12),
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 38,
              color: colorScheme.primary.withAlpha(140),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sin lista activa',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Se incluirán todos los productos de tu despensa,\npriorizando los que están por agotarse.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withAlpha(120),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Iniciar nueva compra'),
          ),

          // Prediction summary panel
          if (urgent.isNotEmpty) ...[
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Productos urgentes (${urgent.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...urgent.take(5).map((p) {
              final isCritical = p.urgency == StockUrgency.critical;
              final color =
                  isCritical ? Colors.red.shade600 : Colors.orange.shade700;
              final label = p.daysUntilEmpty != null
                  ? p.daysUntilEmpty == 0
                      ? 'Se agotó'
                      : 'Queda ${p.daysUntilEmpty} día${p.daysUntilEmpty == 1 ? '' : 's'}'
                  : 'Stock bajo';

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      isCritical
                          ? Icons.error_outline_rounded
                          : Icons.warning_amber_rounded,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.product.name,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (urgent.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${urgent.length - 5} más',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withAlpha(120),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Sesión activa ────────────────────────────────────────────────────────────

class _ActiveSession extends ConsumerStatefulWidget {
  final ShoppingSession session;
  const _ActiveSession({required this.session});

  @override
  ConsumerState<_ActiveSession> createState() => _ActiveSessionState();
}

class _ActiveSessionState extends ConsumerState<_ActiveSession> {
  // null = first incomplete category (resolved at build time)
  String? _selectedCatName;
  bool _catInitialized = false;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsByCatAsync = ref.watch(shoppingItemsByCategoryProvider);
    final session = widget.session;

    final progress =
        session.totalCount > 0 ? session.purchasedCount / session.totalCount : 0.0;
    final isDone = progress >= 1.0 && session.totalCount > 0;
    final purchasedTotal = session.items
        .where((i) => i.isPurchased)
        .fold(0.0, (sum, i) => sum + i.totalCost);

    final categoriesAsync = ref.watch(categoriesProvider);
    final categoryColorMap = <String, Color>{};
    categoriesAsync.whenData((cats) {
      for (final cat in cats) {
        if (cat.color != null) {
          try {
            categoryColorMap[cat.id] =
                Color(int.parse(cat.color!.replaceFirst('#', '0xFF')));
          } catch (_) {}
        }
      }
    });

    return Column(
      children: [
        // ── Global progress ──────────────────────────────────────────────
        _ProgressStrip(
          session: session,
          progress: progress,
          isDone: isDone,
          purchasedTotal: purchasedTotal,
        ),

        // ── Search field ─────────────────────────────────────────────────
        _SearchField(
          controller: _searchCtrl,
          query: _searchQuery,
          onClear: () {
            _searchCtrl.clear();
            setState(() => _searchQuery = '');
          },
        ),

        // ── Body ─────────────────────────────────────────────────────────
        Expanded(
          child: itemsByCatAsync.when(
            data: (byCat) {
              if (byCat.isEmpty) {
                return const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Sin productos',
                  subtitle: 'No hay productos en la lista de compras',
                );
              }

              // Initialize selected category to first incomplete one
              if (!_catInitialized) {
                final firstIncomplete = byCat.keys.firstWhere(
                  (name) {
                    final items =
                        byCat[name]!.values.expand((l) => l).toList();
                    return items.any((i) => !i.isPurchased);
                  },
                  orElse: () => byCat.keys.first,
                );
                _selectedCatName = firstIncomplete;
                _catInitialized = true;
              }

              if (_searchQuery.isNotEmpty) {
                return _SearchResultsView(
                  query: _searchQuery,
                  byCat: byCat,
                  categoryColorMap: categoryColorMap,
                  onItemTap: (item) => _handleItemTap(context, ref, item),
                  onSwipeMark: (item) => ref
                      .read(activeSessionProvider.notifier)
                      .markItemUnpurchased(item.id),
                );
              }

              return _AisleView(
                byCat: byCat,
                categoryColorMap: categoryColorMap,
                selectedCatName: _selectedCatName ?? byCat.keys.first,
                onCategorySelected: (name) =>
                    setState(() => _selectedCatName = name),
                onItemTap: (item) => _handleItemTap(context, ref, item),
                onSwipeMark: (item) => ref
                    .read(activeSessionProvider.notifier)
                    .markItemUnpurchased(item.id),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),

        _BottomActions(session: session),
      ],
    );
  }

  Future<void> _handleItemTap(
      BuildContext context, WidgetRef ref, ShoppingItem item) async {
    if (item.isPurchased) {
      await ref
          .read(activeSessionProvider.notifier)
          .markItemUnpurchased(item.id);
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PurchaseSheet(
        item: item,
        onConfirm: (qty, price) async {
          await ref.read(activeSessionProvider.notifier).markItemPurchased(
                itemId: item.id,
                actualQuantity: qty,
                actualPrice: price,
              );
        },
      ),
    );
  }
}

// ── Progress strip ───────────────────────────────────────────────────────────

class _ProgressStrip extends StatelessWidget {
  final ShoppingSession session;
  final double progress;
  final bool isDone;
  final double purchasedTotal;

  const _ProgressStrip({
    required this.session,
    required this.progress,
    required this.isDone,
    required this.purchasedTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progressColor =
        isDone ? Colors.green.shade500 : colorScheme.primary;

    final costLabel = purchasedTotal > 0
        ? clp(purchasedTotal)
        : session.calculatedTotal > 0
            ? 'Est. ${clp(session.calculatedTotal)}'
            : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.withAlpha(10) : colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.onSurface.withAlpha(12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: '${session.purchasedCount}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDone
                            ? Colors.green.shade600
                            : colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${session.totalCount} productos',
                      style: TextStyle(
                        color: colorScheme.onSurface.withAlpha(140),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isDone)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: Colors.green.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '¡Listo!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                )
              else if (costLabel != null)
                Text(
                  costLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withAlpha(160),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: colorScheme.onSurface.withAlpha(15),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.query,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Buscar en todos los pasillos...',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: colorScheme.onSurface.withAlpha(30)),
            ),
            filled: true,
            fillColor: colorScheme.onSurface.withAlpha(6),
          ),
        ),
      ),
    );
  }
}

// ── Aisle view (category chips + filtered items) ─────────────────────────────

class _AisleView extends StatelessWidget {
  final Map<String, Map<String, List<ShoppingItem>>> byCat;
  final Map<String, Color> categoryColorMap;
  final String selectedCatName;
  final ValueChanged<String> onCategorySelected;
  final void Function(ShoppingItem) onItemTap;
  final Future<void> Function(ShoppingItem) onSwipeMark;

  const _AisleView({
    required this.byCat,
    required this.categoryColorMap,
    required this.selectedCatName,
    required this.onCategorySelected,
    required this.onItemTap,
    required this.onSwipeMark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category chips
        _CategoryChipsBar(
          byCat: byCat,
          categoryColorMap: categoryColorMap,
          selectedCatName: selectedCatName,
          onSelected: onCategorySelected,
        ),

        // Items for selected category
        Expanded(
          child: _CategoryItemsView(
            bySub: byCat[selectedCatName] ?? {},
            onItemTap: onItemTap,
            onSwipeMark: onSwipeMark,
          ),
        ),
      ],
    );
  }
}

// ── Category chips bar ────────────────────────────────────────────────────────

class _CategoryChipsBar extends StatelessWidget {
  final Map<String, Map<String, List<ShoppingItem>>> byCat;
  final Map<String, Color> categoryColorMap;
  final String selectedCatName;
  final ValueChanged<String> onSelected;

  const _CategoryChipsBar({
    required this.byCat,
    required this.categoryColorMap,
    required this.selectedCatName,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.onSurface.withAlpha(12)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: byCat.length,
        itemBuilder: (context, index) {
          final catName = byCat.keys.elementAt(index);
          final items =
              byCat[catName]!.values.expand((l) => l).toList();
          final purchased = items.where((i) => i.isPurchased).length;
          final total = items.length;
          final isDone = purchased >= total;
          final isSelected = catName == selectedCatName;

          final firstItem = byCat[catName]!.values.first.first;
          final catColor = categoryColorMap[firstItem.categoryId] ??
              colorScheme.primary;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _CategoryChip(
              name: catName,
              color: catColor,
              purchased: purchased,
              total: total,
              isDone: isDone,
              isSelected: isSelected,
              onTap: () => onSelected(catName),
            ),
          );
        },
      ),
    );
  }
}

// ── Individual category chip ──────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String name;
  final Color color;
  final int purchased;
  final int total;
  final bool isDone;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.name,
    required this.color,
    required this.purchased,
    required this.total,
    required this.isDone,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = isDone ? Colors.green.shade500 : color;
    final bgColor = isSelected
        ? chipColor
        : isDone
            ? Colors.green.withAlpha(15)
            : chipColor.withAlpha(14);
    final textColor = isSelected
        ? Colors.white
        : isDone
            ? Colors.green.shade600
            : chipColor;
    final borderColor = isSelected
        ? Colors.transparent
        : isDone
            ? Colors.green.withAlpha(60)
            : chipColor.withAlpha(50);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot indicator (only when not selected)
            if (!isSelected) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: chipColor.withAlpha(isDone ? 180 : 200),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Category name
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),

            // Cart count badge
            if (isDone) ...[
              const SizedBox(width: 5),
              Icon(
                Icons.check_rounded,
                size: 13,
                color: isSelected ? Colors.white : Colors.green.shade500,
              ),
            ] else if (purchased > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha(50)
                      : chipColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$purchased',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : chipColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Items view for a single category ─────────────────────────────────────────

class _CategoryItemsView extends StatelessWidget {
  final Map<String, List<ShoppingItem>> bySub;
  final void Function(ShoppingItem) onItemTap;
  final Future<void> Function(ShoppingItem) onSwipeMark;

  const _CategoryItemsView({
    required this.bySub,
    required this.onItemTap,
    required this.onSwipeMark,
  });

  @override
  Widget build(BuildContext context) {
    // Single subcategory with default name — flat list
    if (bySub.length == 1 && bySub.keys.first == 'Sin subcategoría') {
      final items = bySub.values.first;
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => _SwipeableTile(
          key: ValueKey(items[i].id),
          item: items[i],
          onTap: () => onItemTap(items[i]),
          onSwipeMark: () => onSwipeMark(items[i]),
        ),
      );
    }

    // Multiple subcategories — use sections
    final sections = <Widget>[];
    for (final subEntry in bySub.entries) {
      final subName = subEntry.key;
      final subItems = subEntry.value;
      final pending = subItems.where((i) => !i.isPurchased).length;

      sections.add(_SubcategorySection(
        subcategoryName: subName,
        pending: pending,
        children: subItems
            .map((item) => _SwipeableTile(
                  key: ValueKey(item.id),
                  item: item,
                  onTap: () => onItemTap(item),
                  onSwipeMark: () => onSwipeMark(item),
                ))
            .toList(),
      ));
    }

    return ListView(children: sections);
  }
}

// ── Search results view ───────────────────────────────────────────────────────

class _SearchResultsView extends StatelessWidget {
  final String query;
  final Map<String, Map<String, List<ShoppingItem>>> byCat;
  final Map<String, Color> categoryColorMap;
  final void Function(ShoppingItem) onItemTap;
  final Future<void> Function(ShoppingItem) onSwipeMark;

  const _SearchResultsView({
    required this.query,
    required this.byCat,
    required this.categoryColorMap,
    required this.onItemTap,
    required this.onSwipeMark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final q = query.toLowerCase();

    final matches = <_SearchMatch>[];
    for (final catEntry in byCat.entries) {
      final firstItem = catEntry.value.values.first.first;
      final catColor = categoryColorMap[firstItem.categoryId];
      for (final subEntry in catEntry.value.entries) {
        for (final item in subEntry.value) {
          if (item.productName.toLowerCase().contains(q)) {
            matches.add(_SearchMatch(
              item: item,
              catName: catEntry.key,
              subName: subEntry.key,
              catColor: catColor,
            ));
          }
        }
      }
    }

    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: colorScheme.onSurface.withAlpha(80)),
            const SizedBox(height: 8),
            Text(
              'Sin resultados para "$query"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(120),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (ctx, i) {
        final m = matches[i];
        final color = m.catColor ?? colorScheme.primary;
        final breadcrumb = m.subName == 'Sin subcategoría'
            ? m.catName
            : '${m.catName} › ${m.subName}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(52, 6, 16, 0),
              child: Text(
                breadcrumb,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withAlpha(200),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _SwipeableTile(
              key: ValueKey(m.item.id),
              item: m.item,
              onTap: () => onItemTap(m.item),
              onSwipeMark: () => onSwipeMark(m.item),
            ),
          ],
        );
      },
    );
  }
}

// ── Search match data ─────────────────────────────────────────────────────────

class _SearchMatch {
  final ShoppingItem item;
  final String catName;
  final String subName;
  final Color? catColor;

  const _SearchMatch({
    required this.item,
    required this.catName,
    required this.subName,
    required this.catColor,
  });
}

// ── Subcategory expandable section ────────────────────────────────────────────

class _SubcategorySection extends StatelessWidget {
  final String subcategoryName;
  final int pending;
  final List<Widget> children;

  const _SubcategorySection({
    required this.subcategoryName,
    required this.pending,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final done = pending == 0;

    return ExpansionTile(
      initiallyExpanded: !done,
      tilePadding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
      backgroundColor: colorScheme.onSurface.withAlpha(4),
      title: Text(
        subcategoryName,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface.withAlpha(done ? 80 : 150),
          letterSpacing: 0.2,
        ),
      ),
      trailing: done
          ? Icon(Icons.check_rounded, size: 14, color: Colors.green.shade400)
          : Text(
              '$pending',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withAlpha(120),
              ),
            ),
      children: children,
    );
  }
}

// ── Swipeable tile ─────────────────────────────────────────────────────────────

class _SwipeableTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onTap;
  final Future<void> Function() onSwipeMark;

  const _SwipeableTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onSwipeMark,
  });

  @override
  Widget build(BuildContext context) {
    final isPurchased = item.isPurchased;

    return Dismissible(
      key: ValueKey(item.id),
      direction: isPurchased
          ? DismissDirection.endToStart
          : DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        if (isPurchased) {
          await onSwipeMark();
        } else {
          onTap();
        }
        return false;
      },
      background: Container(
        color: Colors.green.withAlpha(35),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: Colors.green.shade600),
            const SizedBox(width: 8),
            Text(
              'Marcar comprado',
              style: TextStyle(
                  color: Colors.green.shade700, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.orange.withAlpha(35),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Desmarcar',
              style: TextStyle(
                  color: Colors.orange.shade700, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Icon(Icons.undo_rounded, color: Colors.orange.shade700),
          ],
        ),
      ),
      child: ShoppingItemTile(item: item, onTap: onTap),
    );
  }
}

// ── Panel de compra (bottom sheet) ────────────────────────────────────────────

class _PurchaseSheet extends StatefulWidget {
  final ShoppingItem item;
  final Future<void> Function(double qty, double price) onConfirm;
  const _PurchaseSheet({required this.item, required this.onConfirm});

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _qtyCtrl = TextEditingController(text: _fmtN(item.plannedQuantity));
    _priceCtrl = TextEditingController(
        text: item.plannedPrice > 0
            ? (item.plannedPrice * item.plannedQuantity).round().toString()
            : '');
    _qtyCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Widget _buildPriceComparison(ColorScheme colorScheme) {
    final item = widget.item;
    if (item.plannedPrice <= 0) return const SizedBox.shrink();
    final totalPaid = double.tryParse(_priceCtrl.text);
    final qty = double.tryParse(_qtyCtrl.text);
    if (totalPaid == null || totalPaid == 0 || qty == null || qty == 0) {
      return const SizedBox.shrink();
    }
    final newPPU = totalPaid / qty;
    final pct = (newPPU - item.plannedPrice) / item.plannedPrice * 100;

    final IconData icon;
    final Color color;
    final String label;

    if (pct.abs() < 2) {
      icon = Icons.remove_rounded;
      color = colorScheme.onSurface.withAlpha(120);
      label = 'Precio similar al anterior';
    } else if (pct > 0) {
      icon = Icons.trending_up_rounded;
      color = Colors.red.shade600;
      label = '+${pct.toStringAsFixed(0)}% más caro que la última vez';
    } else {
      icon = Icons.trending_down_rounded;
      color = Colors.green.shade600;
      label = '${pct.toStringAsFixed(0)}% más barato que la última vez';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final item = widget.item;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withAlpha(40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Comprar',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            item.productName,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Planificado: ${_fmtN(item.plannedQuantity)} ${item.unit}'
            '${item.plannedPrice > 0 ? ' · Est. ${clp(item.plannedPrice * item.plannedQuantity)}' : ''}',
            style: TextStyle(
                color: colorScheme.onSurface.withAlpha(140), fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _qtyCtrl,
            decoration: InputDecoration(
              labelText: 'Cantidad comprada',
              suffixText: item.unit,
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(
              labelText: 'Precio total pagado',
              prefixText: '\$ ',
              hintText: '0',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: false),
          ),
          _buildPriceComparison(colorScheme),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final qty = double.tryParse(_qtyCtrl.text) ??
                    widget.item.plannedQuantity;
                final totalPaid = double.tryParse(_priceCtrl.text) ?? 0;
                final pricePerUnit =
                    qty > 0 && totalPaid > 0 ? totalPaid / qty : 0.0;
                await widget.onConfirm(qty, pricePerUnit);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirmar compra'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Acciones inferiores ───────────────────────────────────────────────────────

class _BottomActions extends ConsumerWidget {
  final ShoppingSession session;
  const _BottomActions({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border:
            Border(top: BorderSide(color: colorScheme.onSurface.withAlpha(15))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Tooltip(
              message: 'Cancelar compra',
              child: OutlinedButton(
                onPressed: () => _cancelSession(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.cancel_outlined, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: session.purchasedCount == 0
                  ? null
                  : () => _completeSession(context, ref),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Builder(builder: (context) {
                final total = session.items
                    .where((i) => i.isPurchased)
                    .fold(0.0, (s, i) => s + i.totalCost);
                return Text(
                    total > 0 ? 'Finalizar · ${clp(total)}' : 'Finalizar compra');
              }),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSession(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Compra'),
        content: const Text(
            '¿Estás seguro de cancelar esta compra? No se actualizará el inventario.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, continuar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(activeSessionProvider.notifier).cancelSession();
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _completeSession(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Compra'),
        content: const Text(
            'Se actualizará el inventario con los productos comprados. ¿Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Revisar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(activeSessionProvider.notifier).completeSession();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Compra finalizada! Inventario actualizado.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
