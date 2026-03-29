import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../providers/pantry_provider.dart';
import '../services/open_food_facts_service.dart';
import '../widgets/barcode_scanner_sheet.dart';

const _uuid = Uuid();

/// Formatea un double eliminando el decimal cuando es entero (2.0 → "2").
String _fmtN(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class AddEditProductScreen extends ConsumerStatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastPriceCtrl;
  late final TextEditingController _priceRefQtyCtrl;
  late final TextEditingController _quantityToMaintainCtrl;
  late final TextEditingController _currentQuantityCtrl;
  late final TextEditingController _lastPlaceCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _newCategoryCtrl;
  late final TextEditingController _newSubcategoryCtrl;

  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  String _selectedUnit = 'unidad';
  bool _showNutritional = false;

  // Nutritional controllers
  final _kcalCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _sugarsCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();
  final _totalFatsCtrl = TextEditingController();
  final _saturatedFatsCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _sodiumCtrl = TextEditingController();
  final _servingSizeCtrl = TextEditingController();
  final _servingUnitCtrl = TextEditingController();

  bool _loadingBarcode = false;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _lastPriceCtrl = TextEditingController(
        text: p?.lastPrice != null && p!.lastPrice > 0
            ? _fmtN(p.lastPrice)
            : '');
    _priceRefQtyCtrl = TextEditingController(
        text: p?.priceRefQty != null && p!.priceRefQty != 1.0
            ? _fmtN(p.priceRefQty)
            : '1');
    _quantityToMaintainCtrl = TextEditingController(
        text: p != null ? _fmtN(p.quantityToMaintain) : '1');
    _currentQuantityCtrl = TextEditingController(
        text: p != null ? _fmtN(p.currentQuantity) : '0');
    _lastPlaceCtrl = TextEditingController(text: p?.lastPlace ?? '');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
    _newCategoryCtrl = TextEditingController();
    _newSubcategoryCtrl = TextEditingController();
    _selectedCategoryId = p?.categoryId;
    _selectedSubcategoryId = p?.subcategoryId;
    _selectedUnit = p?.unit ?? 'unidad';

    if (p?.nutritionalValues != null) {
      final nv = p!.nutritionalValues!;
      _showNutritional = true;
      _kcalCtrl.text = nv.kcal != null ? _fmtN(nv.kcal!) : '';
      _carbsCtrl.text = nv.carbs != null ? _fmtN(nv.carbs!) : '';
      _sugarsCtrl.text = nv.sugars != null ? _fmtN(nv.sugars!) : '';
      _fiberCtrl.text = nv.fiber != null ? _fmtN(nv.fiber!) : '';
      _totalFatsCtrl.text = nv.totalFats != null ? _fmtN(nv.totalFats!) : '';
      _saturatedFatsCtrl.text =
          nv.saturatedFats != null ? _fmtN(nv.saturatedFats!) : '';
      _proteinCtrl.text = nv.proteins != null ? _fmtN(nv.proteins!) : '';
      _sodiumCtrl.text = nv.sodium != null ? _fmtN(nv.sodium!) : '';
      _servingSizeCtrl.text =
          nv.servingSize != null ? _fmtN(nv.servingSize!) : '';
      _servingUnitCtrl.text = nv.servingUnit ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastPriceCtrl.dispose();
    _priceRefQtyCtrl.dispose();
    _quantityToMaintainCtrl.dispose();
    _currentQuantityCtrl.dispose();
    _lastPlaceCtrl.dispose();
    _notesCtrl.dispose();
    _newCategoryCtrl.dispose();
    _newSubcategoryCtrl.dispose();
    _kcalCtrl.dispose();
    _carbsCtrl.dispose();
    _sugarsCtrl.dispose();
    _fiberCtrl.dispose();
    _totalFatsCtrl.dispose();
    _saturatedFatsCtrl.dispose();
    _proteinCtrl.dispose();
    _sodiumCtrl.dispose();
    _servingSizeCtrl.dispose();
    _servingUnitCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    if (kIsWeb) return;
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const BarcodeScannerSheet(),
      ),
    );
    if (code == null || !mounted) return;

    setState(() => _loadingBarcode = true);
    final product = await OpenFoodFactsService.fetchByBarcode(code);
    if (!mounted) return;
    setState(() => _loadingBarcode = false);

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto no encontrado. Puedes ingresarlo manualmente.'),
        ),
      );
      return;
    }

    setState(() {
      if (product.name.isNotEmpty) _nameCtrl.text = product.name;
      if (product.servingSize != null) {
        _showNutritional = true;
        _servingSizeCtrl.text = product.servingSize!.toStringAsFixed(0);
        _servingUnitCtrl.text = product.servingUnit;
        if (product.kcal != null) _kcalCtrl.text = product.kcal!.toStringAsFixed(1);
        if (product.proteins != null) _proteinCtrl.text = product.proteins!.toStringAsFixed(1);
        if (product.carbs != null) _carbsCtrl.text = product.carbs!.toStringAsFixed(1);
        if (product.sugars != null) _sugarsCtrl.text = product.sugars!.toStringAsFixed(1);
        if (product.totalFats != null) _totalFatsCtrl.text = product.totalFats!.toStringAsFixed(1);
        if (product.saturatedFats != null) _saturatedFatsCtrl.text = product.saturatedFats!.toStringAsFixed(1);
        if (product.fiber != null) _fiberCtrl.text = product.fiber!.toStringAsFixed(1);
        if (product.sodium != null) _sodiumCtrl.text = product.sodium!.toStringAsFixed(0);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Producto encontrado: ${product.name}')),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona una categoría')));
      return;
    }

    final now = DateTime.now();
    final product = Product(
      id: widget.product?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      categoryId: _selectedCategoryId!,
      subcategoryId: _selectedSubcategoryId,
      unit: _selectedUnit,
      lastPrice: double.tryParse(_lastPriceCtrl.text) ?? 0,
      priceRefQty: double.tryParse(_priceRefQtyCtrl.text) ?? 1.0,
      quantityToMaintain:
          double.tryParse(_quantityToMaintainCtrl.text) ?? 1,
      currentQuantity: double.tryParse(_currentQuantityCtrl.text) ?? 0,
      lastPlace: _lastPlaceCtrl.text.trim().isEmpty
          ? null
          : _lastPlaceCtrl.text.trim(),
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.product?.createdAt ?? now,
      updatedAt: now,
    );

    NutritionalValues? nutritionalValues;
    if (_showNutritional) {
      nutritionalValues = NutritionalValues(
        id: widget.product?.nutritionalValues?.id ?? _uuid.v4(),
        productId: product.id,
        servingSize: double.tryParse(_servingSizeCtrl.text),
        servingUnit: _servingUnitCtrl.text.trim().isEmpty
            ? null
            : _servingUnitCtrl.text.trim(),
        kcal: double.tryParse(_kcalCtrl.text),
        carbs: double.tryParse(_carbsCtrl.text),
        sugars: double.tryParse(_sugarsCtrl.text),
        fiber: double.tryParse(_fiberCtrl.text),
        totalFats: double.tryParse(_totalFatsCtrl.text),
        saturatedFats: double.tryParse(_saturatedFatsCtrl.text),
        proteins: double.tryParse(_proteinCtrl.text),
        sodium: double.tryParse(_sodiumCtrl.text),
      );
    }

    if (isEditing) {
      await ref.read(productsProvider.notifier).updateProduct(
            product,
            nutritionalValues: nutritionalValues,
            deleteNutritional: !_showNutritional,
          );
    } else {
      await ref.read(productsProvider.notifier).addProduct(
            product,
            nutritionalValues: nutritionalValues,
          );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
        actions: [
          if (!kIsWeb)
            _loadingBarcode
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.qr_code_scanner,
                        color: Colors.white),
                    tooltip: 'Escanear código de barras',
                    onPressed: _scanBarcode,
                  ),
          TextButton(
            onPressed: _save,
            child:
                const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            const _SectionTitle(title: 'Información General'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto *',
                hintText: 'Ej: Leche entera',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            // Category selection
            categoriesAsync.when(
              data: (categories) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Categoría *',
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ...categories.map((cat) => ChoiceChip(
                            label: Text(cat.name),
                            selected: _selectedCategoryId == cat.id,
                            onSelected: (_) => setState(() {
                              _selectedCategoryId = cat.id;
                              _selectedSubcategoryId = null;
                            }),
                          )),
                      ActionChip(
                        label: const Text('+ Nueva'),
                        onPressed: () => _showAddCategoryDialog(context),
                      ),
                    ],
                  ),
                  // Subcategory
                  if (_selectedCategoryId != null) ...[
                    const SizedBox(height: 12),
                    Text('Subcategoría',
                        style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('Ninguna'),
                          selected: _selectedSubcategoryId == null,
                          onSelected: (_) =>
                              setState(() => _selectedSubcategoryId = null),
                        ),
                        ...categories
                            .where((c) => c.id == _selectedCategoryId)
                            .expand((c) => c.subcategories)
                            .map((sub) => ChoiceChip(
                                  label: Text(sub.name),
                                  selected: _selectedSubcategoryId == sub.id,
                                  onSelected: (_) => setState(
                                      () => _selectedSubcategoryId = sub.id),
                                )),
                        ActionChip(
                          label: const Text('+ Nueva'),
                          onPressed: () =>
                              _showAddSubcategoryDialog(context),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),

            // Unit
            Text('Unidad de medida *', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                'unidad', 'g', 'kg', 'ml', 'L',
                'lata', 'botella', 'caja', 'bolsa', 'paquete',
              ].map((u) => ChoiceChip(
                    label: Text(u),
                    selected: _selectedUnit == u,
                    onSelected: (_) => setState(() => _selectedUnit = u),
                  )).toList(),
            ),
            const SizedBox(height: 16),

            // Quantities and Price
            const _SectionTitle(title: 'Inventario'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _currentQuantityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad actual',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _quantityToMaintainCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad a mantener *',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (double.tryParse(v) == null) return 'Inválido';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _lastPriceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Precio ref.',
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _priceRefQtyCtrl,
                    decoration: InputDecoration(
                      labelText: 'por',
                      suffixText: _selectedUnit,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ej: \$5000 por 250 gramos',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha(120),
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _lastPlaceCtrl,
              decoration: const InputDecoration(
                labelText: 'Último lugar de compra',
                hintText: 'Ej: Supermercado A',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Marca preferida, variedad, etc.',
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Nutritional Values (only for food category or if already set)
            _buildNutritionalSection(theme),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionalSection(ThemeData theme) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final selectedCat = categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => const ProductCategory(id: '', name: ''),
    );
    final isFood = selectedCat.name.toLowerCase().contains('aliment') ||
        selectedCat.id == 'cat_alimentacion';

    if (!isFood && !_showNutritional) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: 'Valores Nutricionales'),
            Switch(
              value: _showNutritional,
              onChanged: (v) => setState(() => _showNutritional = v),
            ),
          ],
        ),
        if (_showNutritional) ...[
          const SizedBox(height: 8),
          Text(
            'Tamaño de porción',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _servingSizeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    hintText: '100',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _servingUnitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Unidad',
                    hintText: 'g, ml, etc.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NutritionalField(
                    controller: _kcalCtrl, label: 'Calorías (kcal)'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NutritionalField(
                    controller: _proteinCtrl, label: 'Proteínas (g)'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NutritionalField(
                    controller: _carbsCtrl, label: 'Carbohidratos (g)'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NutritionalField(
                    controller: _sugarsCtrl, label: 'Azúcares (g)'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NutritionalField(
                    controller: _fiberCtrl, label: 'Fibra (g)'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NutritionalField(
                    controller: _totalFatsCtrl, label: 'Grasas Totales (g)'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NutritionalField(
                    controller: _saturatedFatsCtrl,
                    label: 'Grasas Saturadas (g)'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NutritionalField(
                    controller: _sodiumCtrl, label: 'Sodio (mg)'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    _newCategoryCtrl.clear();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Categoría'),
        content: TextField(
          controller: _newCategoryCtrl,
          decoration:
              const InputDecoration(labelText: 'Nombre de la categoría'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar')),
        ],
      ),
    );
    if (result == true && _newCategoryCtrl.text.trim().isNotEmpty) {
      final cat = await ref
          .read(categoriesProvider.notifier)
          .addCategory(_newCategoryCtrl.text.trim(), null, null);
      if (mounted) {
        setState(() {
          _selectedCategoryId = cat.id;
          _selectedSubcategoryId = null;
        });
      }
    }
  }

  Future<void> _showAddSubcategoryDialog(BuildContext context) async {
    if (_selectedCategoryId == null) return;
    _newSubcategoryCtrl.clear();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Subcategoría'),
        content: TextField(
          controller: _newSubcategoryCtrl,
          decoration:
              const InputDecoration(labelText: 'Nombre de la subcategoría'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar')),
        ],
      ),
    );
    if (result == true && _newSubcategoryCtrl.text.trim().isNotEmpty) {
      await ref
          .read(categoriesProvider.notifier)
          .addSubcategory(_selectedCategoryId!, _newSubcategoryCtrl.text.trim());
      if (mounted) setState(() {});
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _NutritionalField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _NutritionalField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
    );
  }
}
