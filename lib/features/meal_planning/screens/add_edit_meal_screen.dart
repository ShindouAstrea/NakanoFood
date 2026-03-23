import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/meal_planning_provider.dart';
import '../models/meal_plan.dart';
import '../../recipes/providers/recipe_provider.dart';

const _uuid = Uuid();

class AddEditMealScreen extends ConsumerStatefulWidget {
  final MealPlan? meal;
  final DateTime? initialDate;

  const AddEditMealScreen({super.key, this.meal, this.initialDate});

  @override
  ConsumerState<AddEditMealScreen> createState() =>
      _AddEditMealScreenState();
}

class _AddEditMealScreenState extends ConsumerState<AddEditMealScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _notesCtrl;
  late DateTime _selectedDate;
  String? _selectedCategoryId;
  String? _selectedRecipeId;

  bool get isEditing => widget.meal != null;

  @override
  void initState() {
    super.initState();
    final m = widget.meal;
    _titleCtrl = TextEditingController(text: m?.title ?? '');
    _notesCtrl = TextEditingController(text: m?.notes ?? '');
    _selectedDate = m?.date ??
        widget.initialDate ??
        DateTime.now();
    _selectedCategoryId = m?.categoryId;
    _selectedRecipeId = m?.recipeId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una categoría')));
      return;
    }

    final plan = MealPlan(
      id: widget.meal?.id ?? _uuid.v4(),
      date: _selectedDate,
      categoryId: _selectedCategoryId!,
      title: _titleCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      recipeId: _selectedRecipeId,
    );

    if (isEditing) {
      await ref.read(mealPlansProvider.notifier).updateMealPlan(plan);
    } else {
      await ref.read(mealPlansProvider.notifier).addMealPlan(plan);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(mealCategoriesProvider);
    final recipesAsync = ref.watch(recipesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Comida' : 'Agregar Comida'),
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
            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Fecha'),
              subtitle: Text(
                DateFormat('EEEE, d MMMM yyyy', 'es')
                    .format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              trailing: const Icon(Icons.chevron_right),
            ),
            const Divider(),
            const SizedBox(height: 12),

            // Category
            Text('Categoría *', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (categories) => Wrap(
                spacing: 8,
                runSpacing: 4,
                children: categories
                    .map((cat) => ChoiceChip(
                          label: Text(cat.name),
                          selected: _selectedCategoryId == cat.id,
                          onSelected: (_) => setState(
                              () => _selectedCategoryId = cat.id),
                        ))
                    .toList(),
              ),
              loading: () =>
                  const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción / Alimento *',
                hintText: 'Ej: Avena con frutas, Pollo a la plancha...',
                prefixIcon: Icon(Icons.restaurant_outlined),
              ),
              validator: (v) =>
                  v?.trim().isEmpty == true ? 'Requerido' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Recipe (optional)
            Text('Receta vinculada (opcional)',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            recipesAsync.when(
              data: (recipes) {
                return DropdownButtonFormField<String?>(
                  initialValue: _selectedRecipeId,
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar receta',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('Sin receta')),
                    ...recipes.map((r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(r.name),
                        )),
                  ],
                  onChanged: (v) =>
                      setState(() {
                        _selectedRecipeId = v;
                        // Auto-fill title from recipe
                        if (v != null) {
                          final recipe = recipes.firstWhere(
                              (r) => r.id == v);
                          if (_titleCtrl.text.isEmpty) {
                            _titleCtrl.text = recipe.name;
                          }
                        }
                      }),
                );
              },
              loading: () =>
                  const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Comentarios adicionales...',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
