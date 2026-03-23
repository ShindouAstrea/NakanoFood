import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shopping_provider.dart';
import '../models/shopping_session.dart';
import '../widgets/shopping_item_tile.dart';
import 'shopping_history_screen.dart';

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
              MaterialPageRoute(builder: (_) => const ShoppingHistoryScreen()),
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

class _NoActiveSession extends StatelessWidget {
  final VoidCallback onStart;
  const _NoActiveSession({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Sin lista de compras activa',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicia una nueva sesión de compras.\nSe incluirán todos los productos de tu despensa,\npriorizando los que están por agotarse.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade400,
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

class _ActiveSession extends ConsumerWidget {
  final ShoppingSession session;
  const _ActiveSession({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsByAreaAsync = ref.watch(shoppingItemsByAreaProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Progress header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
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
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Comprados',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                  Text(
                    'Total: \$${session.calculatedTotal.toStringAsFixed(0)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: session.totalCount > 0
                      ? session.purchasedCount / session.totalCount
                      : 0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        // Items by area
        Expanded(
          child: itemsByAreaAsync.when(
            data: (itemsByArea) {
              if (itemsByArea.isEmpty) {
                return const Center(
                    child: Text('No hay productos en la lista'));
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: itemsByArea.length,
                itemBuilder: (_, areaIndex) {
                  final area =
                      itemsByArea.keys.elementAt(areaIndex);
                  final items = itemsByArea[area]!;
                  final unpurchased =
                      items.where((i) => !i.isPurchased).length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Area header
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        color: Colors.grey.shade100,
                        child: Row(
                          children: [
                            Icon(Icons.store_outlined,
                                size: 16,
                                color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              area,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: unpurchased > 0
                                    ? Colors.orange.shade100
                                    : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unpurchased pendiente${unpurchased != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: unpurchased > 0
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...items.map((item) => ShoppingItemTile(
                            item: item,
                            onTap: () =>
                                _handleItemTap(context, ref, item),
                          )),
                      const Divider(height: 1),
                    ],
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
        // Bottom action buttons
        _BottomActions(session: session),
      ],
    );
  }

  Future<void> _handleItemTap(
      BuildContext context, WidgetRef ref, ShoppingItem item) async {
    if (item.isPurchased) {
      // Un-purchase it
      await ref.read(activeSessionProvider.notifier).markItemUnpurchased(item.id);
      return;
    }

    // Show purchase dialog
    await showDialog(
      context: context,
      builder: (ctx) => _PurchaseDialog(
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

class _PurchaseDialog extends StatefulWidget {
  final ShoppingItem item;
  final Future<void> Function(double qty, double price) onConfirm;

  const _PurchaseDialog({required this.item, required this.onConfirm});

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: widget.item.plannedQuantity.toString());
    _priceCtrl = TextEditingController(
        text: widget.item.plannedPrice > 0
            ? widget.item.plannedPrice.toString()
            : '');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Comprar: ${widget.item.productName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cantidad planificada: ${widget.item.plannedQuantity} ${widget.item.unit}',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyCtrl,
            decoration: InputDecoration(
              labelText: 'Cantidad comprada',
              suffixText: widget.item.unit,
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(
              labelText: 'Precio por unidad',
              prefixText: '\$ ',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            final qty = double.tryParse(_qtyCtrl.text) ??
                widget.item.plannedQuantity;
            final price = double.tryParse(_priceCtrl.text) ?? 0;
            await widget.onConfirm(qty, price);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Confirmar compra'),
        ),
      ],
    );
  }
}

class _BottomActions extends ConsumerWidget {
  final ShoppingSession session;
  const _BottomActions({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _cancelSession(context, ref),
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              label: const Text('Cancelar compra',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: session.purchasedCount == 0
                  ? null
                  : () => _completeSession(context, ref),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Finalizar compra'),
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
          const SnackBar(
            content: Text('¡Compra finalizada! Inventario actualizado.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
