import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import '../data/default_recipes.dart';
import '../services/recipe_share_service.dart';
import '../widgets/recipe_card.dart';
import 'add_edit_recipe_screen.dart';
import 'explore_recipes_screen.dart';
import 'recipe_detail_screen.dart';
import '../../../shared/widgets/skeletons/recipe_card_skeleton.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  // Cacheamos los defaults para no reconstruirlos en cada rebuild
  final _allDefaults = buildDefaultRecipes();

  List<Recipe> _unsavedDefaults(List<Recipe> saved) {
    final savedNames =
        saved.map((r) => r.name.toLowerCase().trim()).toSet();
    return _allDefaults
        .where((d) => !savedNames.contains(d.name.toLowerCase().trim()))
        .toList();
  }

  void _openDefaultsPicker(BuildContext context, List<Recipe> unsaved) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DefaultRecipesPicker(
        defaults: unsaved,
        onSaved: () => ref.invalidate(recipesProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(filteredRecipesProvider);
    final allRecipesAsync = ref.watch(recipesProvider);
    final typeFilter = ref.watch(recipeTypeFilterProvider);
    ref.watch(recipeSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recetas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Explorar recetas',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ExploreRecipesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Importar receta',
            onPressed: () => _showImportDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar recetas...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) =>
                  ref.read(recipeSearchProvider.notifier).state = v,
            ),
          ),
          // Type filter
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('Todos'),
                    selected: typeFilter == null,
                    onSelected: (_) =>
                        ref.read(recipeTypeFilterProvider.notifier).state =
                            null,
                  ),
                ),
                ...recipeTypes.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(type),
                        selected: typeFilter == type,
                        onSelected: (_) => ref
                            .read(recipeTypeFilterProvider.notifier)
                            .state = typeFilter == type ? null : type,
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: recipesAsync.when(
              data: (recipes) {
                if (recipes.isEmpty) {
                  return _DefaultRecipesPicker(
                    defaults: _allDefaults,
                    onSaved: () => ref.invalidate(recipesProvider),
                  );
                }
                final allSaved = allRecipesAsync.value ?? [];
                final unsaved = _unsavedDefaults(allSaved);
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(recipesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    itemCount: recipes.length + (unsaved.isNotEmpty ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (unsaved.isNotEmpty && i == 0) {
                        return _UnsavedDefaultsBanner(
                          count: unsaved.length,
                          onTap: () => _openDefaultsPicker(context, unsaved),
                        );
                      }
                      final recipeIndex = unsaved.isNotEmpty ? i - 1 : i;
                      return RecipeCard(
                        recipe: recipes[recipeIndex],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(
                                recipeId: recipes[recipeIndex].id),
                          ),
                        ).then((_) => ref.invalidate(recipesProvider)),
                      );
                    },
                  ),
                );
              },
              loading: () => const RecipeListSkeleton(),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_recipes',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditRecipeScreen()),
        ).then((_) => ref.invalidate(recipesProvider)),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar receta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingresa el código de 6 caracteres que te compartieron:'),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'ABC123',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length != 6) return;
              Navigator.pop(ctx);
              await _importRecipe(context, code);
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  Future<void> _importRecipe(BuildContext context, String code) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Buscando receta...'),
          ],
        ),
      ),
    );

    try {
      final recipe = await RecipeShareService.importByCode(code);
      if (!context.mounted) return;
      Navigator.pop(context);

      if (recipe == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código no encontrado o expirado.')),
        );
        return;
      }

      await ref.read(recipesProvider.notifier).addRecipe(recipe);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡"${recipe.name}" importada correctamente!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al importar. ¿Tienes conexión?')),
      );
    }
  }
}

// ─── Selector de recetas predefinidas ────────────────────────────────────────

class _DefaultRecipesPicker extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  final List<Recipe> defaults;
  const _DefaultRecipesPicker({required this.onSaved, required this.defaults});

  @override
  ConsumerState<_DefaultRecipesPicker> createState() =>
      _DefaultRecipesPickerState();
}

class _DefaultRecipesPickerState
    extends ConsumerState<_DefaultRecipesPicker> {
  List<Recipe> get _defaults => widget.defaults;
  final Set<String> _saving = {};

  Future<void> _save(Recipe recipe) async {
    if (_saving.contains(recipe.id)) return;
    setState(() => _saving.add(recipe.id));
    // Genera un nuevo id único para no colisionar si se guarda dos veces
    final toSave = recipe.copyWith(id: '${recipe.id}_${DateTime.now().millisecondsSinceEpoch}');
    final stepsWithId = recipe.steps
        .map((s) => RecipeStep(
              id: '${s.id}_${DateTime.now().millisecondsSinceEpoch}',
              recipeId: toSave.id,
              stepNumber: s.stepNumber,
              description: s.description,
            ))
        .toList();
    final ingsWithId = recipe.ingredients
        .map((i) => RecipeIngredient(
              id: '${i.id}_${DateTime.now().millisecondsSinceEpoch}',
              recipeId: toSave.id,
              productName: i.productName,
              quantity: i.quantity,
              unit: i.unit,
            ))
        .toList();
    await ref.read(recipesProvider.notifier).addRecipe(
          toSave.copyWith(
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            steps: stepsWithId,
            ingredients: ingsWithId,
          ),
        );
    setState(() => _saving.remove(recipe.id));
    widget.onSaved();
  }

  void _showDetail(Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DefaultRecipeDetail(
        recipe: recipe,
        onSave: () {
          Navigator.pop(context);
          _save(recipe);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Empieza con estas recetas',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Guarda las que quieras en tu colección. Siempre podrás editarlas.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final recipe = _defaults[i];
              final isSaving = _saving.contains(recipe.id);
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showDetail(recipe),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Icono de tipo
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _typeEmoji(recipe.type),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(recipe.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  _MiniChip(recipe.type),
                                  if (recipe.totalTime > 0) ...[
                                    const SizedBox(width: 4),
                                    _MiniChip(
                                        '${recipe.totalTime} min',
                                        icon: Icons.timer_outlined),
                                  ],
                                  const SizedBox(width: 4),
                                  _MiniChip(
                                      '${recipe.portions} porc.',
                                      icon: Icons.people_outline),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Botón guardar
                        isSaving
                            ? const SizedBox(
                                width: 36,
                                height: 36,
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                    Icons.add_circle_outline_rounded),
                                color: theme.colorScheme.primary,
                                tooltip: 'Guardar receta',
                                onPressed: () => _save(recipe),
                              ),
                      ],
                    ),
                  ),
                ),
              );
            },
            childCount: _defaults.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

String _typeEmoji(String type) {
  switch (type) {
    case 'Desayuno': return '🌅';
    case 'Comida Principal': return '🍽️';
    case 'Cena': return '🌙';
    case 'Postre': return '🍮';
    case 'Snack': return '🥐';
    case 'Ensalada': return '🥗';
    case 'Sopa': return '🍲';
    case 'Bebida': return '🥤';
    case 'Pastelería': return '🎂';
    default: return '🍴';
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _MiniChip(this.label, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: Colors.grey.shade600),
            const SizedBox(width: 2),
          ],
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

// ─── Detalle de receta predefinida (bottom sheet) ─────────────────────────────

class _DefaultRecipeDetail extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onSave;
  const _DefaultRecipeDetail({required this.recipe, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                // Header
                Row(
                  children: [
                    Text(_typeEmoji(recipe.type),
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(recipe.name,
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              _MiniChip(recipe.type),
                              if (recipe.totalTime > 0) ...[
                                const SizedBox(width: 4),
                                _MiniChip('${recipe.totalTime} min',
                                    icon: Icons.timer_outlined),
                              ],
                              const SizedBox(width: 4),
                              _MiniChip('${recipe.portions} porciones',
                                  icon: Icons.people_outline),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (recipe.description != null) ...[
                  const SizedBox(height: 12),
                  Text(recipe.description!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade700)),
                ],
                const SizedBox(height: 16),
                // Ingredientes
                Text('Ingredientes',
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                ...recipe.ingredients.map((ing) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 6),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ing.productName)),
                          Text(
                            '${ing.quantity == ing.quantity.roundToDouble() ? ing.quantity.toInt() : ing.quantity} ${ing.unit}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                // Pasos
                Text('Preparación',
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                ...recipe.steps.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text('${s.stepNumber}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(s.description,
                                style: const TextStyle(height: 1.4)),
                          )),
                        ],
                      ),
                    )),
                if (recipe.notes != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.amber.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(recipe.notes!,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.amber.shade900))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Botón guardar fijo abajo
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Guardar en mis recetas'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Banner recetas predefinidas pendientes ───────────────────────────────────

class _UnsavedDefaultsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _UnsavedDefaultsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withAlpha(120),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.secondary.withAlpha(80)),
          ),
          child: Row(
            children: [
              Icon(Icons.collections_bookmark_outlined,
                  size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  count == 1
                      ? '1 receta predefinida disponible para agregar'
                      : '$count recetas predefinidas disponibles para agregar',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: theme.colorScheme.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
