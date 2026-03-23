import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import 'add_edit_recipe_screen.dart';
import 'recipe_detail_screen.dart';
import '../../../shared/widgets/empty_state.dart';

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(filteredRecipesProvider);
    final typeFilter = ref.watch(recipeTypeFilterProvider);
    ref.watch(recipeSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recetas'),
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
}
