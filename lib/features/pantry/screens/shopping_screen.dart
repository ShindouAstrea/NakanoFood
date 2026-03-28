import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shopping_provider.dart';
import '../providers/pantry_provider.dart';
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
            tooltip: 'Historial de compras',
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

class _NoActiveSession extends StatelessWidget {
  final VoidCallback onStart;
  const _NoActiveSession({required this.onStart});

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
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withAlpha(15),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: colorScheme.primary.withAlpha(100),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin lista de compras activa',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(180),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicia una nueva sesión de compras.\nSe incluirán todos los productos de tu despensa,\npriorizando los que están por agotarse.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(120),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Iniciar nueva compra'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sesión activa ────────────────────────────────────────────────────────────

class _ActiveSession extends ConsumerWidget {
  final ShoppingSession session;
  const _ActiveSession({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsByCatAsync = ref.watch(shoppingItemsByCategoryProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final progress = session.totalCount > 0
        ? session.purchasedCount / session.totalCount
        : 0.0;
    final isDone = progress >= 1.0 && session.totalCount > 0;
    // Only sum items that have actually been purchased (not estimates)
    final purchasedTotal = session.items
        .where((i) => i.isPurchased)
        .fold(0.0, (sum, item) => sum + item.totalCost);
    final progressColor =
        isDone ? Colors.green.shade600 : colorScheme.primary;

    // Build categoryId → Color map for section headers
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
        // Progress header
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: isDone
                ? Colors.green.withAlpha(12)
                : colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: isDone
                    ? Colors.green.withAlpha(40)
                    : colorScheme.onSurface.withAlpha(20),
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.purchasedCount} / ${session.totalCount} productos',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDone ? Colors.green.shade700 : null,
                        ),
                      ),
                      Row(
                        children: [
                          if (isDone) ...[
                            Icon(Icons.check_circle_rounded,
                                size: 13, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            isDone ? '¡Todo listo!' : 'Comprados',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDone
                                  ? Colors.green.shade600
                                  : colorScheme.onSurface.withAlpha(120),
                              fontWeight: isDone ? FontWeight.w600 : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: progressColor.withAlpha(15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      purchasedTotal > 0
                          ? 'Gastado: ${clp(purchasedTotal)}'
                          : 'Estimado: ${clp(session.calculatedTotal)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            colorScheme.onSurface.withAlpha(20),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDone
                          ? Colors.green.shade600
                          : colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Items by category / subcategory
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
              return ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: byCat.entries.map((catEntry) {
                  final catName = catEntry.key;
                  final bySub = catEntry.value;
                  final catPending = byCat[catName]!.values
                      .expand((l) => l)
                      .where((i) => !i.isPurchased)
                      .length;

                  // Resolve category color from the first item's categoryId
                  final firstItem =
                      bySub.values.first.first;
                  final catColor =
                      categoryColorMap[firstItem.categoryId];

                  return _CategorySection(
                    categoryName: catName,
                    categoryColor: catColor,
                    pending: catPending,
                    children: bySub.entries.map((subEntry) {
                      final subName = subEntry.key;
                      final items = subEntry.value;
                      final subPending =
                          items.where((i) => !i.isPurchased).length;

                      Widget buildTile(ShoppingItem item) =>
                          _SwipeableTile(
                            key: ValueKey(item.id),
                            item: item,
                            onTap: () =>
                                _handleItemTap(context, ref, item),
                            onSwipeMark: () => ref
                                .read(activeSessionProvider.notifier)
                                .markItemUnpurchased(item.id),
                          );

                      if (bySub.length == 1 &&
                          subName == 'Sin subcategoría') {
                        return Column(
                          children:
                              items.map(buildTile).toList(),
                        );
                      }

                      return _SubcategorySection(
                        subcategoryName: subName,
                        pending: subPending,
                        children: items.map(buildTile).toList(),
                      );
                    }).toList(),
                  );
                }).toList(),
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

// ── Category expandable section ──────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String categoryName;
  final Color? categoryColor;
  final int pending;
  final List<Widget> children;

  const _CategorySection({
    required this.categoryName,
    required this.pending,
    required this.children,
    this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final done = pending == 0;
    final color = categoryColor ?? colorScheme.primary;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withAlpha(50)),
      ),
      child: ExpansionTile(
        initiallyExpanded: !done,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.category_outlined, size: 18, color: color),
        ),
        title: Text(
          categoryName,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PendingBadge(pending: pending),
            const SizedBox(width: 4),
          ],
        ),
        children: children,
      ),
    );
  }
}

// ── Subcategory expandable section ───────────────────────────────────────────

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
      tilePadding: const EdgeInsets.fromLTRB(32, 0, 14, 0),
      backgroundColor: colorScheme.onSurface.withAlpha(5),
      leading: Icon(
        Icons.subdirectory_arrow_right_rounded,
        size: 16,
        color: colorScheme.onSurface.withAlpha(100),
      ),
      title: Text(
        subcategoryName,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface.withAlpha(180),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PendingBadge(pending: pending),
          const SizedBox(width: 4),
        ],
      ),
      children: children,
    );
  }
}

// ── Pending badge ─────────────────────────────────────────────────────────────

class _PendingBadge extends StatelessWidget {
  final int pending;
  const _PendingBadge({required this.pending});

  @override
  Widget build(BuildContext context) {
    final done = pending == 0;
    final color = done ? Colors.green.shade600 : Colors.orange.shade700;
    final bg = done ? Colors.green.withAlpha(25) : Colors.orange.withAlpha(25);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        done
            ? 'Listo'
            : '$pending pendiente${pending != 1 ? 's' : ''}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Panel de compra (bottom sheet) ───────────────────────────────────────────

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

  Widget _buildPriceComparison(ShoppingItem item, ColorScheme colorScheme) {
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
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
    final unit = widget.item.unit;
    final item = widget.item;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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
            'Planificado: ${_fmtN(item.plannedQuantity)} $unit'
            '${item.plannedPrice > 0 ? ' · Est. ${clp(item.plannedPrice * item.plannedQuantity)}' : ''}',
            style: TextStyle(
                color: colorScheme.onSurface.withAlpha(140), fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _qtyCtrl,
            decoration: InputDecoration(
              labelText: 'Cantidad comprada',
              suffixText: unit,
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
          _buildPriceComparison(item, colorScheme),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final qty = double.tryParse(_qtyCtrl.text) ??
                    widget.item.plannedQuantity;
                final totalPaid =
                    double.tryParse(_priceCtrl.text) ?? 0;
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

// ── Swipeable tile ────────────────────────────────────────────────────────────

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
        color: Colors.green.withAlpha(40),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: Colors.green.shade700),
            const SizedBox(width: 8),
            Text(
              'Marcar comprado',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.orange.withAlpha(40),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Desmarcar',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
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

// ── Acciones inferiores ──────────────────────────────────────────────────────

class _BottomActions extends ConsumerWidget {
  final ShoppingSession session;
  const _BottomActions({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.onSurface.withAlpha(20)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel — icon-only outlined button
          SizedBox(
            width: 48,
            height: 48,
            child: Tooltip(
              message: 'Cancelar compra',
              child: OutlinedButton(
                onPressed: () => _cancelSession(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.cancel_outlined, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Finish — takes all remaining space
          Expanded(
            child: ElevatedButton.icon(
              onPressed: session.purchasedCount == 0
                  ? null
                  : () => _completeSession(context, ref),
              icon: const Icon(Icons.check_circle_outline),
              label: Builder(builder: (context) {
                final total = session.items
                    .where((i) => i.isPurchased)
                    .fold(0.0, (s, i) => s + i.totalCost);
                return Text(
                  total > 0
                      ? 'Finalizar · ${clp(total)}'
                      : 'Finalizar compra',
                );
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
