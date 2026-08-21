import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/utils/number_input.dart';
import '../models/product.dart';
import '../providers/pantry_provider.dart';

const _uuid = Uuid();

/// Da de alta un producto con lo mínimo y lo devuelve. Null si se cancela.
///
/// Existe para los dos momentos en que hace falta un producto y pararse a
/// llenar la ficha entera no tiene sentido: en mitad de la compra, con el
/// producto en la mano, y al vincular un ingrediente de una receta con algo
/// que todavía no está en la despensa.
///
/// Precio, nutrición y equivalencia por unidad se completan después en la
/// ficha normal: aquí se pide lo que la base exige y nada más.
Future<Product?> quickAddProduct(
  BuildContext context,
  WidgetRef ref, {
  String? initialName,
}) {
  return showDialog<Product>(
    context: context,
    builder: (_) => _QuickAddDialog(initialName: initialName ?? ''),
  );
}

class _QuickAddDialog extends ConsumerStatefulWidget {
  final String initialName;

  const _QuickAddDialog({required this.initialName});

  @override
  ConsumerState<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends ConsumerState<_QuickAddDialog> {
  late final TextEditingController _nameCtrl;
  final _quantityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  String? _categoryId;
  String _unit = 'unidad';
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(List<ProductCategory> categories) async {
    final name = _nameCtrl.text.trim();
    final categoryId = _categoryId ?? categories.firstOrNull?.id;

    if (name.isEmpty) {
      setState(() => _error = 'Ponle un nombre');
      return;
    }
    if (categoryId == null) {
      setState(() => _error = 'No hay categorías en la despensa');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final now = DateTime.now();
    final product = Product(
      id: _uuid.v4(),
      name: name,
      categoryId: categoryId,
      unit: _unit,
      // Lo que no se pregunta queda en su valor neutro: sin stock, sin precio
      // y con objetivo 1, que es lo que hace que aparezca como "por reponer"
      // hasta que se compre.
      currentQuantity: parseDecimal(_quantityCtrl.text) ?? 0,
      lastPrice: parseDecimal(_priceCtrl.text) ?? 0,
      priceRefQty: 1,
      quantityToMaintain: 1,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(productsProvider.notifier).addProduct(product);
    if (!mounted) return;
    Navigator.pop(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    // La primera vez se elige sola: casi siempre lo que se agrega a mitad de
    // una compra es comida, y una categoría de más es un toque de menos.
    _categoryId ??= categories.firstOrNull?.id;

    return AlertDialog(
      title: const Text('Producto nuevo'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: widget.initialName.isEmpty,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  isDense: true,
                ),
                onSubmitted: (_) => _save(categories),
              ),
              const SizedBox(height: 16),
              Text('Categoría', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final category in categories)
                    ChoiceChip(
                      label: Text(category.name),
                      selected: _categoryId == category.id,
                      onSelected: (_) =>
                          setState(() => _categoryId = category.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Unidad', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final unit in productUnits)
                    ChoiceChip(
                      label: Text(unit),
                      selected: _unit == unit,
                      onSelected: (_) => setState(() => _unit = unit),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Tienes',
                        suffixText: _unit,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Precio',
                        prefixText: '\$ ',
                        helperText: 'por $_unit',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.error)),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(categories),
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
