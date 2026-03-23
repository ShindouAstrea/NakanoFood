import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pantry_provider.dart';
import '../models/product.dart';
import 'add_edit_product_screen.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.grey;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final theme = Theme.of(context);

    return productsAsync.when(
      data: (products) {
        final product = products.where((p) => p.id == productId).firstOrNull;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Producto')),
            body: const Center(child: Text('Producto no encontrado')),
          );
        }
        return _buildDetail(context, ref, product, theme);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildDetail(
      BuildContext context, WidgetRef ref, Product product, ThemeData theme) {
    final catColor = _parseColor(product.categoryColor);

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditProductScreen(product: product),
              ),
            ).then((_) => ref.invalidate(productsProvider)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref, product),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: catColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: catColor.withAlpha(100)),
                        ),
                        child: Text(
                          product.categoryName ?? '',
                          style: TextStyle(
                              color: catColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (product.subcategoryName != null) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(product.subcategoryName!),
                          labelStyle: const TextStyle(fontSize: 12),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        label: 'Disponible',
                        value:
                            '${product.currentQuantity.toStringAsFixed(product.currentQuantity == product.currentQuantity.roundToDouble() ? 0 : 1)} ${product.unit}',
                        color: product.isOut
                            ? Colors.red
                            : product.isLow
                                ? Colors.orange
                                : Colors.green,
                      ),
                      _StatItem(
                        label: 'A mantener',
                        value:
                            '${product.quantityToMaintain.toStringAsFixed(product.quantityToMaintain == product.quantityToMaintain.roundToDouble() ? 0 : 1)} ${product.unit}',
                        color: catColor,
                      ),
                      _StatItem(
                        label: 'Último precio',
                        value: product.lastPrice > 0
                            ? '\$${product.lastPrice.toStringAsFixed(0)}'
                            : 'N/A',
                        color: Colors.blueGrey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            product.isOut
                                ? 'Agotado'
                                : product.isLow
                                    ? 'Stock bajo'
                                    : 'Stock suficiente',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: product.isOut
                                  ? Colors.red
                                  : product.isLow
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ),
                          Text(
                            '${((product.currentQuantity / product.quantityToMaintain) * 100).clamp(0, 999).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: product.quantityToMaintain > 0
                              ? (product.currentQuantity /
                                      product.quantityToMaintain)
                                  .clamp(0.0, 1.0)
                              : 0,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            product.isOut
                                ? Colors.red
                                : product.isLow
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                          minHeight: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick update quantity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Actualizar Cantidad',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _QuantityUpdater(product: product),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detalles',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (product.lastPlace != null)
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Último lugar de compra',
                      value: product.lastPlace!,
                    ),
                  if (product.notes != null)
                    _DetailRow(
                      icon: Icons.notes_outlined,
                      label: 'Notas',
                      value: product.notes!,
                    ),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Agregado',
                    value: _formatDate(product.createdAt),
                  ),
                  _DetailRow(
                    icon: Icons.update_outlined,
                    label: 'Actualizado',
                    value: _formatDate(product.updatedAt),
                  ),
                ],
              ),
            ),
          ),

          // Nutritional values
          if (product.nutritionalValues != null) ...[
            const SizedBox(height: 12),
            _NutritionalCard(nv: product.nutritionalValues!),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text(
            '¿Estás seguro de eliminar "${product.name}"? Esta acción no se puede deshacer.'),
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
      await ref.read(productsProvider.notifier).deleteProduct(product.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _QuantityUpdater extends ConsumerStatefulWidget {
  final Product product;
  const _QuantityUpdater({required this.product});

  @override
  ConsumerState<_QuantityUpdater> createState() => _QuantityUpdaterState();
}

class _QuantityUpdaterState extends ConsumerState<_QuantityUpdater> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.product.currentQuantity.toString(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () {
            final current = double.tryParse(_ctrl.text) ?? 0;
            if (current > 0) {
              final newVal = (current - 1).clamp(0, double.infinity);
              _ctrl.text = newVal.toString();
            }
          },
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffixText: widget.product.unit,
              isDense: true,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () {
            final current = double.tryParse(_ctrl.text) ?? 0;
            _ctrl.text = (current + 1).toString();
          },
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () async {
            final qty = double.tryParse(_ctrl.text);
            if (qty == null) return;
            await ref
                .read(productsProvider.notifier)
                .updateCurrentQuantity(widget.product.id, qty);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cantidad actualizada')),
              );
            }
          },
          child: const Text('Actualizar'),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NutritionalCard extends StatelessWidget {
  final NutritionalValues nv;

  const _NutritionalCard({required this.nv});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Valores Nutricionales',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (nv.servingSize != null) ...[
              const SizedBox(height: 4),
              Text(
                'Por porción: ${nv.servingSize} ${nv.servingUnit ?? ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
            const Divider(),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(),
                1: IntrinsicColumnWidth(),
              },
              children: [
                if (nv.kcal != null)
                  _nutRow('Calorías', '${nv.kcal} kcal'),
                if (nv.proteins != null)
                  _nutRow('Proteínas', '${nv.proteins} g'),
                if (nv.carbs != null)
                  _nutRow('Carbohidratos', '${nv.carbs} g'),
                if (nv.sugars != null)
                  _nutRow('Azúcares', '${nv.sugars} g'),
                if (nv.fiber != null)
                  _nutRow('Fibra', '${nv.fiber} g'),
                if (nv.totalFats != null)
                  _nutRow('Grasas Totales', '${nv.totalFats} g'),
                if (nv.saturatedFats != null)
                  _nutRow('Grasas Saturadas', '${nv.saturatedFats} g'),
                if (nv.sodium != null)
                  _nutRow('Sodio', '${nv.sodium} mg'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _nutRow(String label, String value) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end),
      ),
    ]);
  }
}
