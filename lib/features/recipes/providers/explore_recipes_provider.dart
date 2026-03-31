import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pantry/providers/pantry_provider.dart';
import '../models/recipe_suggestion.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../services/recipe_explore_service.dart';

final exploreTypeFilterProvider = StateProvider<String?>((ref) => null);

final exploreSuggestionsProvider =
    AsyncNotifierProvider<ExploreSuggestionsNotifier, List<RecipeSuggestion>>(
  ExploreSuggestionsNotifier.new,
);

class ExploreSuggestionsNotifier
    extends AsyncNotifier<List<RecipeSuggestion>> {
  @override
  Future<List<RecipeSuggestion>> build() => _fetch();

  Future<List<RecipeSuggestion>> _fetch() async {
    final typeFilter = ref.watch(exploreTypeFilterProvider);
    // read (no watch) para que agregar una receta no relance la búsqueda de IA
    final recipes = ref.read(recipesProvider).valueOrNull ?? <Recipe>[];
    final products = ref.read(productsProvider).valueOrNull ?? [];

    return RecipeExploreService.getSuggestions(
      savedRecipes: recipes,
      pantryProducts: products,
      typeFilter: typeFilter,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
