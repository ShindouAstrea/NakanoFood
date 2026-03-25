import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import '../services/recipe_share_service.dart';
import '../widgets/recipe_card.dart';
import 'add_edit_recipe_screen.dart';
import 'explore_recipes_screen.dart';
import 'recipe_detail_screen.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeletons/recipe_card_skeleton.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(filteredRecipesProvider);
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
                  return EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'Sin recetas',
                    subtitle: 'Agrega recetas de tus comidas favoritas',
                    actionLabel: 'Agregar receta',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddEditRecipeScreen()),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(recipesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: recipes.length,
                    itemBuilder: (_, i) => RecipeCard(
                      recipe: recipes[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RecipeDetailScreen(recipeId: recipes[i].id),
                        ),
                      ).then((_) => ref.invalidate(recipesProvider)),
                    ),
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
