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

    return productsAsync.when(
      data: (products) {
        final product = products.where((p) => p.id == productId).firstOrNull;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Producto')),
            body: const Center(child: Text('Producto no encontrado')),
          );
        }
        return _buildDetail(context, ref, product);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, WidgetRef ref, Product product) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catColor = _parseColor(product.categoryColor);

    final Color statusColor = product.isOut
        ? Colors.red.shade600
        : product.isLow
            ? Colors.orange.shade700
            : Colors.green.shade600;

    final double progress = product.quantityToMaintain > 0
        ? (product.currentQuantity / product.quantityToMaintain).clamp(0.0, 1.0)
        : 0;

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
          // ── Category badges ─────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: catColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: catColor.withAlpha(100)),
                ),
                child: Text(
                  product.categoryName ?? '',
                  style: TextStyle(
                      color: catColor, fontWeight: FontWeight.w600),
                ),
              ),
              if (product.subcategoryName != null) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text(product.subcategoryName!),
                  labelStyle: const TextStyle(fontSize: 12),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // ── Stock card ───────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status label
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        product.isOut
                            ? 'Agotado'
                            : product.isLow
                                ? 'Stock bajo'
                                : 'Stock suficiente',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: statusColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${((product.currentQuantity / (product.quantityToMaintain > 0 ? product.quantityToMaintain : 1)) * 100).clamp(0, 999).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: colorScheme.onSurface.withAlpha(140),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: colorScheme.onSurface.withAlpha(18),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quantity stats: disponible / a mantener / precio
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _QuantityStat(
                            label: 'Disponible',
                            quantity: product.currentQuantity,
                            unit: product.unit,
                            color: statusColor,
                          ),
                        ),
                        VerticalDivider(
                          width: 24,
                          thickness: 1,
                          color: colorScheme.onSurface.withAlpha(20),
                        ),
                        Expanded(
                          child: _QuantityStat(
                            label: 'A mantener',
                            quantity: product.quantityToMaintain,
                            unit: product.unit,
                            color: catColor,
                          ),
                        ),
                        VerticalDivider(
                          width: 24,
                          thickness: 1,
                          color: colorScheme.onSurface.withAlpha(20),
                        ),
                        Expanded(
                          child: _PriceStat(
                            label: 'Último precio',
                            price: product.lastPrice,
                            refQty: product.priceRefQty,
                            unit: product.unit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Actualizar cantidad ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Actualizar cantidad disponible',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Unit type label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.straighten_rounded,
                            size: 14, color: colorScheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          'Unidad: ${product.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _QuantityUpdater(product: product),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Detalles ─────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalles',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.straighten_rounded,
                    label: 'Unidad de medida',
                    value: product.unit,
                    highlight: true,
                  ),
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

          // ── Nutricionales ─────────────────────────────────────────────
          if (product.nutritionalValues != null) ...[
            const SizedBox(height: 12),
            _NutritionalCard(nv: product.nutritionalValues!),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

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

// ── Stat: número + unidad separados ────────────────────────────────────────
class _QuantityStat extends StatelessWidget {
  final String label;
  final double quantity;
  final String unit;
  final Color color;

  const _QuantityStat({
    required this.label,
    required this.quantity,
    required this.unit,
    required this.color,
  });

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _fmt(quantity),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color.withAlpha(180),
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PriceStat extends StatelessWidget {
  final String label;
  final double price;
  final double refQty;
  final String unit;

  const _PriceStat({
    required this.label,
    required this.price,
    this.refQty = 1.0,
    this.unit = 'unidad',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = Colors.blueGrey;

    // Build the reference label: "$1000/botella" or "$5000/250g"
    final String refLabel;
    if (refQty != 1.0) {
      final refStr = refQty == refQty.truncateToDouble()
          ? refQty.toInt().toString()
          : refQty.toStringAsFixed(1);
      refLabel = '$refStr$unit';
    } else {
      refLabel = unit;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          price > 0 ? '\$${price.toStringAsFixed(0)}' : '—',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          price > 0 ? '/$refLabel' : 'sin precio',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Actualizador de cantidad ────────────────────────────────────────────────
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
    final qty = widget.product.currentQuantity;
    _ctrl = TextEditingController(
      text: qty == qty.roundToDouble()
          ? qty.toStringAsFixed(0)
          : qty.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _adjust(double delta) {
    final current = double.tryParse(_ctrl.text) ?? 0;
    final newVal = (current + delta).clamp(0, double.infinity);
    setState(() {
      _ctrl.text = newVal == newVal.roundToDouble()
          ? newVal.toStringAsFixed(0)
          : newVal.toStringAsFixed(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Row(
          children: [
            // Decrement button
            _AdjustButton(
              icon: Icons.remove_rounded,
              onTap: () => _adjust(-1),
            ),
            const SizedBox(width: 10),

            // Input field
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: colorScheme.outline.withAlpha(80)),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),
            // Increment button
            _AdjustButton(
              icon: Icons.add_rounded,
              onTap: () => _adjust(1),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Unit label centered
        Text(
          widget.product.unit,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Guardar cantidad'),
            onPressed: () async {
              final qty = double.tryParse(_ctrl.text);
              if (qty == null) return;
              final messenger = ScaffoldMessenger.of(context);
              await ref
                  .read(productsProvider.notifier)
                  .updateCurrentQuantity(widget.product.id, qty);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Cantidad actualizada')),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AdjustButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: colorScheme.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withAlpha(50)),
        ),
        child: Icon(icon, color: colorScheme.primary, size: 22),
      ),
    );
  }
}

// ── Fila de detalle ─────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18,
              color: highlight
                  ? colorScheme.primary
                  : colorScheme.onSurface.withAlpha(120)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(120),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        highlight ? FontWeight.w700 : FontWeight.w500,
                    color: highlight ? colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card nutricional ────────────────────────────────────────────────────────
class _NutritionalCard extends StatelessWidget {
  final NutritionalValues nv;

  const _NutritionalCard({required this.nv});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Valores Nutricionales',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (nv.servingSize != null) ...[
              const SizedBox(height: 4),
              Text(
                'Por porción: ${nv.servingSize} ${nv.servingUnit ?? ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(130)),
              ),
            ],
            const Divider(height: 20),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(),
                1: IntrinsicColumnWidth(),
              },
              children: [
                if (nv.kcal != null) _nutRow('Calorías', '${nv.kcal} kcal'),
                if (nv.proteins != null)
                  _nutRow('Proteínas', '${nv.proteins} g'),
                if (nv.carbs != null)
                  _nutRow('Carbohidratos', '${nv.carbs} g'),
                if (nv.sugars != null) _nutRow('Azúcares', '${nv.sugars} g'),
                if (nv.fiber != null) _nutRow('Fibra', '${nv.fiber} g'),
                if (nv.totalFats != null)
                  _nutRow('Grasas totales', '${nv.totalFats} g'),
                if (nv.saturatedFats != null)
                  _nutRow('Grasas saturadas', '${nv.saturatedFats} g'),
                if (nv.sodium != null) _nutRow('Sodio', '${nv.sodium} mg'),
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
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          textAlign: TextAlign.end,
        ),
      ),
    ]);
  }
}
