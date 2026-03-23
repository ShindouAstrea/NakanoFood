import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../../pantry/providers/pantry_provider.dart';

const _uuid = Uuid();

class AddEditRecipeScreen extends ConsumerStatefulWidget {
  final Recipe? recipe;

  const AddEditRecipeScreen({super.key, this.recipe});

  @override
  ConsumerState<AddEditRecipeScreen> createState() =>
      _AddEditRecipeScreenState();
}

class _AddEditRecipeScreenState extends ConsumerState<AddEditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _portionsCtrl;
  late final TextEditingController _prepTimeCtrl;
  late final TextEditingController _cookTimeCtrl;
  late final TextEditingController _notesCtrl;

  String _selectedType = recipeTypes.first;
  String? _mainImagePath;
  final List<String> _additionalImages = [];
  final List<_IngredientEntry> _ingredients = [];
  final List<TextEditingController> _stepControllers = [];

  bool get isEditing => widget.recipe != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _portionsCtrl =
        TextEditingController(text: r?.portions.toString() ?? '1');
    _prepTimeCtrl =
        TextEditingController(text: r?.prepTime?.toString() ?? '');
    _cookTimeCtrl =
        TextEditingController(text: r?.cookTime?.toString() ?? '');
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    _selectedType = r?.type ?? recipeTypes.first;
    _mainImagePath = r?.mainImagePath;

    if (r != null) {
      _additionalImages.addAll(r.imagePaths
          .where((p) => p != r.mainImagePath));
      for (final ing in r.ingredients) {
        _ingredients.add(_IngredientEntry(
          id: ing.id,
          productId: ing.productId,
          nameCtrl: TextEditingController(text: ing.productName),
          qtyCtrl:
              TextEditingController(text: ing.quantity.toString()),
          unit: ing.unit,
        ));
      }
      for (final step in r.steps) {
        _stepControllers
            .add(TextEditingController(text: step.description));
      }
    }
    if (_stepControllers.isEmpty) {
      _stepControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _portionsCtrl.dispose();
    _prepTimeCtrl.dispose();
    _cookTimeCtrl.dispose();
    _notesCtrl.dispose();
    for (final ing in _ingredients) {
      ing.nameCtrl.dispose();
      ing.qtyCtrl.dispose();
    }
    for (final ctrl in _stepControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMainImage() async {
    if (kIsWeb) return;
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _mainImagePath = img.path);
  }

  Future<void> _pickAdditionalImage() async {
    if (kIsWeb) return;
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _additionalImages.add(img.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final recipeId = widget.recipe?.id ?? _uuid.v4();

    final filteredIngredients = _ingredients
        .where((ing) => ing.nameCtrl.text.trim().isNotEmpty)
        .toList();
    final ingredients = filteredIngredients
        .map((ing) => RecipeIngredient(
              id: ing.id ?? _uuid.v4(),
              recipeId: recipeId,
              productId: ing.productId,
              productName: ing.nameCtrl.text.trim(),
              quantity: double.tryParse(ing.qtyCtrl.text) ?? 1,
              unit: ing.unit,
            ))
        .toList();

    final stepDescriptions = _stepControllers
        .map((ctrl) => ctrl.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final steps = stepDescriptions
        .asMap()
        .entries
        .map((e) => RecipeStep(
              id: _uuid.v4(),
              recipeId: recipeId,
              stepNumber: e.key + 1,
              description: e.value,
            ))
        .toList();

    final allImages = [
      if (_mainImagePath != null) _mainImagePath!,
      ..._additionalImages,
    ];

    final recipe = Recipe(
      id: recipeId,
      name: _nameCtrl.text.trim(),
      type: _selectedType,
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      mainImagePath: _mainImagePath,
      portions: int.tryParse(_portionsCtrl.text) ?? 1,
      prepTime: int.tryParse(_prepTimeCtrl.text),
      cookTime: int.tryParse(_cookTimeCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      createdAt: widget.recipe?.createdAt ?? now,
      updatedAt: now,
      ingredients: ingredients,
      steps: steps,
      imagePaths: allImages,
    );

    if (isEditing) {
      await ref.read(recipesProvider.notifier).updateRecipe(recipe);
    } else {
      await ref.read(recipesProvider.notifier).addRecipe(recipe);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Receta' : 'Nueva Receta'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Guardar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Main Image
            GestureDetector(
              onTap: _pickMainImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey.shade300, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: (!kIsWeb && _mainImagePath != null)
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(_mainImagePath!),
                              fit: BoxFit.cover),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor:
                                  Colors.black.withAlpha(150),
                              radius: 18,
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 40,
                              color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Agregar foto principal',
                              style: TextStyle(
                                  color: Colors.grey.shade500)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Basic info
            const _SectionTitle(title: 'Información General'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre *'),
              validator: (v) => v?.trim().isEmpty == true ? 'Requerido' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            // Type
            Text('Tipo de receta *', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: recipeTypes
                  .map((type) => ChoiceChip(
                        label: Text(type),
                        selected: _selectedType == type,
                        onSelected: (_) =>
                            setState(() => _selectedType = type),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Breve descripción de la receta',
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _portionsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Porciones *',
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Preparación',
                      suffixText: 'min',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cookTimeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cocción',
                        suffixText: 'min',
                        prefixIcon:
                            Icon(Icons.local_fire_department_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Ingredients
            const _SectionTitle(title: 'Ingredientes'),
            const SizedBox(height: 8),
            ..._ingredients.mapIndexed((i, ing) => _IngredientRow(
                  entry: ing,
                  onRemove: () => setState(() => _ingredients.removeAt(i)),
                  index: i,
                )),
            TextButton.icon(
              onPressed: () => setState(() => _ingredients.add(_IngredientEntry(
                    id: null,
                    productId: null,
                    nameCtrl: TextEditingController(),
                    qtyCtrl: TextEditingController(text: '1'),
                    unit: 'g',
                  ))),
              icon: const Icon(Icons.add),
              label: const Text('Agregar ingrediente'),
            ),
            const SizedBox(height: 16),

            // Steps
            const _SectionTitle(title: 'Pasos de Preparación'),
            const SizedBox(height: 8),
            ..._stepControllers.mapIndexed(
                (i, ctrl) => _StepRow(
                      controller: ctrl,
                      stepNumber: i + 1,
                      onRemove: _stepControllers.length > 1
                          ? () => setState(
                              () => _stepControllers.removeAt(i))
                          : null,
                    )),
            TextButton.icon(
              onPressed: () => setState(
                  () => _stepControllers.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar paso'),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Consejos, variaciones, sugerencias...',
                prefixIcon: Icon(Icons.lightbulb_outline),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Additional images
            if (_additionalImages.isNotEmpty) ...[
              const _SectionTitle(title: 'Fotos Adicionales'),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _additionalImages.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _additionalImages.length) {
                      return GestureDetector(
                        onTap: _pickAdditionalImage,
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add,
                              color: Colors.grey.shade400),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: kIsWeb
                                ? null
                                : DecorationImage(
                                    image: FileImage(
                                        File(_additionalImages[i])),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 10,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _additionalImages.removeAt(i)),
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor:
                                  Colors.red.withAlpha(200),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            TextButton.icon(
              onPressed: _pickAdditionalImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Agregar foto adicional'),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _IngredientEntry {
  final String? id;
  String? productId;
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  String unit;

  _IngredientEntry({
    required this.id,
    required this.productId,
    required this.nameCtrl,
    required this.qtyCtrl,
    required this.unit,
  });
}

class _IngredientRow extends ConsumerStatefulWidget {
  final _IngredientEntry entry;
  final VoidCallback onRemove;
  final int index;

  const _IngredientRow({
    required this.entry,
    required this.onRemove,
    required this.index,
  });

  @override
  ConsumerState<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends ConsumerState<_IngredientRow> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withAlpha(6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.onSurface.withAlpha(20)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: number + ingredient name
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IngredientAutocomplete(entry: widget.entry),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Line 2: quantity + unit (full width, no delete crowding)
          Row(
            children: [
              const SizedBox(width: 30),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: widget.entry.qtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: widget.entry.unit,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Unidad',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: commonUnits
                      .map((u) =>
                          DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => widget.entry.unit = v);
                  },
                ),
              ),
            ],
          ),
          // Line 3: delete button aligned right
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onRemove,
              icon: Icon(Icons.delete_outline,
                  size: 15, color: Colors.red.shade400),
              label: Text(
                'Eliminar',
                style: TextStyle(fontSize: 12, color: Colors.red.shade400),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientAutocomplete extends ConsumerWidget {
  final _IngredientEntry entry;
  const _IngredientAutocomplete({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final products = productsAsync.valueOrNull ?? [];

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: entry.nameCtrl.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const [];
        final query = textEditingValue.text.toLowerCase();
        return products
            .where((p) => p.name.toLowerCase().contains(query))
            .map((p) => p.name)
            .take(5)
            .toList();
      },
      onSelected: (selected) {
        final product = products.firstWhere(
          (p) => p.name == selected,
          orElse: () => products.first,
        );
        entry.nameCtrl.text = selected;
        entry.productId = product.id;
        if (product.unit.isNotEmpty) {
          entry.unit = commonUnits.contains(product.unit)
              ? product.unit
              : commonUnits.first;
        }
      },
      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
        ctrl.text = entry.nameCtrl.text;
        ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
        ctrl.addListener(() => entry.nameCtrl.text = ctrl.text);
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: const InputDecoration(
            hintText: 'Ingrediente',
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          textCapitalization: TextCapitalization.sentences,
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  final TextEditingController controller;
  final int stepNumber;
  final VoidCallback? onRemove;

  const _StepRow({
    required this.controller,
    required this.stepNumber,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Describe el paso $stepNumber...',
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Colors.red.shade400,
              onPressed: onRemove,
            ),
        ],
      ),
    );
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

// Helper extension
extension ListIndexedMap<T> on List<T> {
  List<R> mapIndexed<R>(R Function(int index, T item) f) {
    return asMap().entries.map((e) => f(e.key, e.value)).toList();
  }
}
