import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/meal_planning_provider.dart';
import '../models/meal_plan.dart';
import '../models/meal_plan_item.dart';
import '../../recipes/providers/recipe_provider.dart';
import '../../recipes/models/recipe.dart';

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
  late TextEditingController _notesCtrl;
  late DateTime _selectedDate;
  String? _selectedCategoryId;
  final List<_ItemDraft> _items = [];

  bool get isEditing => widget.meal != null;

  @override
  void initState() {
    super.initState();
    final m = widget.meal;
    _notesCtrl = TextEditingController(text: m?.notes ?? '');
    _selectedDate = m?.date ?? widget.initialDate ?? DateTime.now();
    _selectedCategoryId = m?.categoryId;

    if (m != null) {
      for (final item in m.items) {
        _items.add(_ItemDraft(
          id: item.id,
          titleCtrl: TextEditingController(text: item.title),
          recipeId: item.recipeId,
          recipeName: item.recipeName,
        ));
      }
    }
    if (_items.isEmpty) _addItem();
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemDraft(
        id: _uuid.v4(),
        titleCtrl: TextEditingController(),
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].titleCtrl.dispose();
      _items.removeAt(index);
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final item in _items) {
      item.titleCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una categoría')));
      return;
    }

    final nonEmpty = _items
        .where((i) => i.titleCtrl.text.trim().isNotEmpty)
        .toList();
    if (nonEmpty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agrega al menos un ítem')));
      return;
    }

    final planId = widget.meal?.id ?? _uuid.v4();
    final items = nonEmpty.asMap().entries.map((e) {
      return MealPlanItem(
        id: e.value.id,
        mealPlanId: planId,
        title: e.value.titleCtrl.text.trim(),
        recipeId: e.value.recipeId,
        sortOrder: e.key,
      );
    }).toList();

    final plan = MealPlan(
      id: planId,
      date: _selectedDate,
      categoryId: _selectedCategoryId!,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      items: items,
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

    final recipes = recipesAsync.valueOrNull ?? [];

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date picker
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Fecha'),
            subtitle: Text(
              DateFormat('EEEE, d MMMM yyyy', 'es').format(_selectedDate),
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
                        onSelected: (_) =>
                            setState(() => _selectedCategoryId = cat.id),
                      ))
                  .toList(),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 20),

          // Items header
          Row(
            children: [
              Text('Ítems *', style: theme.textTheme.labelLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar'),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Item list
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _items.removeAt(oldIndex);
                _items.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final draft = _items[index];
              return _ItemRow(
                key: ValueKey(draft.id),
                draft: draft,
                recipes: recipes,
                canDelete: _items.length > 1,
                onDelete: () => _removeItem(index),
                onRecipeSelected: (id, name) {
                  setState(() {
                    draft.recipeId = id;
                    draft.recipeName = name;
                    if (id != null && draft.titleCtrl.text.isEmpty) {
                      draft.titleCtrl.text = name ?? '';
                    }
                  });
                },
              );
            },
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
    );
  }
}

// ─── Item draft (mutable local state) ────────────────────────────────────────

class _ItemDraft {
  final String id;
  final TextEditingController titleCtrl;
  String? recipeId;
  String? recipeName;

  _ItemDraft({
    required this.id,
    required this.titleCtrl,
    this.recipeId,
    this.recipeName,
  });
}

// ─── Single item row ──────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final _ItemDraft draft;
  final List<Recipe> recipes;
  final bool canDelete;
  final VoidCallback onDelete;
  final void Function(String? id, String? name) onRecipeSelected;

  const _ItemRow({
    super.key,
    required this.draft,
    required this.recipes,
    required this.canDelete,
    required this.onDelete,
    required this.onRecipeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 8),
              child: Icon(Icons.drag_handle_rounded,
                  color: colorScheme.onSurface.withAlpha(60), size: 20),
            ),

            // Fields
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title field
                  TextField(
                    controller: draft.titleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Descripción del ítem...',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 8),

                  // Recipe chip / picker
                  draft.recipeId != null
                      ? GestureDetector(
                          onTap: () => _pickRecipe(context),
                          child: Chip(
                            avatar: Icon(Icons.menu_book_outlined,
                                size: 14,
                                color: colorScheme.primary),
                            label: Text(
                              draft.recipeName ?? 'Receta',
                              style: TextStyle(
                                  fontSize: 12, color: colorScheme.primary),
                            ),
                            deleteIcon:
                                const Icon(Icons.close, size: 14),
                            onDeleted: () =>
                                onRecipeSelected(null, null),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                      : TextButton.icon(
                          onPressed: () => _pickRecipe(context),
                          icon: const Icon(Icons.link_outlined, size: 14),
                          label: const Text('Vincular receta',
                              style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                ],
              ),
            ),

            // Delete
            if (canDelete)
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: Colors.red.shade400),
                onPressed: onDelete,
                tooltip: 'Eliminar ítem',
              ),
          ],
        ),
      ),
    );
  }

  void _pickRecipe(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RecipePicker(
        recipes: recipes,
        selectedId: draft.recipeId,
        onSelected: (id, name) {
          Navigator.pop(ctx);
          onRecipeSelected(id, name);
        },
      ),
    );
  }
}

// ─── Recipe picker bottom sheet ───────────────────────────────────────────────

class _RecipePicker extends StatefulWidget {
  final List<Recipe> recipes;
  final String? selectedId;
  final void Function(String? id, String? name) onSelected;

  const _RecipePicker({
    required this.recipes,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.recipes
        .where((r) =>
            r.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar receta...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: const Text('Sin receta'),
            onTap: () => widget.onSelected(null, null),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final r = filtered[i];
                return ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(r.name),
                  subtitle: Text(r.type,
                      style: const TextStyle(fontSize: 12)),
                  selected: widget.selectedId == r.id,
                  onTap: () => widget.onSelected(r.id, r.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
