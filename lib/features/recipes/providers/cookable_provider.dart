import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../../pantry/providers/pantry_provider.dart';
import 'pantry_index.dart';
import 'recipe_provider.dart';

/// Una receta evaluada contra la despensa actual.
class Cookable {
  final Recipe recipe;

  /// Ingredientes que faltan o no alcanzan.
  final List<RecipeIngredient> missing;

  /// Ingredientes sin equivalente en la despensa, o cuya unidad no se puede
  /// convertir. No se cuentan como faltantes porque no consta que falten.
  final List<RecipeIngredient> unknown;

  const Cookable({
    required this.recipe,
    required this.missing,
    required this.unknown,
  });

  /// Todo lo que se pudo comprobar, alcanza.
  bool get canCook => missing.isEmpty && unknown.isEmpty;

  /// Nada de la receta se pudo cruzar con la despensa.
  bool get isUnlinked => unknown.length == recipe.ingredients.length;

  /// A un par de ingredientes de poder cocinarla.
  bool get isClose => !canCook && missing.length <= 2 && !isUnlinked;

  int get missingCount => missing.length;
}

/// Recetas guardadas cruzadas con la despensa, ordenadas por cercanía:
/// primero las que se pueden cocinar ya, luego las que menos ingredientes
/// necesitan, y al final las que no se pudieron evaluar.
final cookableRecipesProvider = FutureProvider<List<Cookable>>((ref) async {
  final recipes = await ref.watch(recipesProvider.future);
  final products = await ref.watch(productsProvider.future);
  final pantry = PantryIndex.from(products);

  final result = <Cookable>[];
  for (final recipe in recipes) {
    // Una receta sin ingredientes no se puede afirmar que sea cocinable.
    if (recipe.ingredients.isEmpty) {
      result.add(Cookable(recipe: recipe, missing: const [], unknown: const []));
      continue;
    }

    final missing = <RecipeIngredient>[];
    final unknown = <RecipeIngredient>[];

    for (final ingredient in recipe.ingredients) {
      final available = pantry.isAvailable(ingredient);
      if (available == null) {
        unknown.add(ingredient);
      } else if (!available) {
        missing.add(ingredient);
      }
    }

    result.add(
        Cookable(recipe: recipe, missing: missing, unknown: unknown));
  }

  result.sort((a, b) {
    if (a.canCook != b.canCook) return a.canCook ? -1 : 1;
    if (a.isUnlinked != b.isUnlinked) return a.isUnlinked ? 1 : -1;
    final byMissing = a.missingCount.compareTo(b.missingCount);
    if (byMissing != 0) return byMissing;
    return a.recipe.name.compareTo(b.recipe.name);
  });

  return result;
});
