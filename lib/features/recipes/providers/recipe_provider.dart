import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_write_helper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/image_storage_service.dart';
import '../../../core/services/sync_service.dart';
import '../models/recipe.dart';
import '../../pantry/models/product.dart';

const _uuid = Uuid();

final recipesProvider =
    AsyncNotifierProvider<RecipesNotifier, List<Recipe>>(RecipesNotifier.new);

class RecipesNotifier extends AsyncNotifier<List<Recipe>> {
  @override
  Future<List<Recipe>> build() => _loadRecipes();

  String? get _uid => ref.read(currentUserIdProvider);

  Future<List<Recipe>> _loadRecipes() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('recipes', orderBy: 'name ASC');

    final recipes = <Recipe>[];
    for (final m in maps) {
      final recipe = Recipe.fromMap(m);
      final ingredients = await _loadIngredients(recipe.id);
      final steps = await _loadSteps(recipe.id);
      final images = await _loadImages(recipe.id);
      final cookings = await _loadCookings(recipe.id);
      recipes.add(recipe.copyWith(
        ingredients: ingredients,
        steps: steps,
        imagePaths: images,
        cookCount: cookings.length,
        lastCookedAt: cookings.isNotEmpty ? cookings.first : null,
      ));
    }
    return recipes;
  }

  Future<List<DateTime>> _loadCookings(String recipeId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'recipe_cookings',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'cooked_at DESC',
    );
    return maps
        .map((m) => DateTime.parse(m['cooked_at'] as String))
        .toList();
  }

  Future<List<RecipeIngredient>> _loadIngredients(String recipeId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'recipe_ingredients',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );
    return maps.map(RecipeIngredient.fromMap).toList();
  }

  Future<List<RecipeStep>> _loadSteps(String recipeId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'recipe_steps',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'step_number ASC',
    );
    return maps.map(RecipeStep.fromMap).toList();
  }

  Future<List<String>> _loadImages(String recipeId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'recipe_images',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );
    return maps.map((m) => m['image_path'] as String).toList();
  }

  /// Uploads local image paths to Supabase Storage and returns the resolved
  /// paths (URLs for uploaded images, original path if upload failed or skipped).
  Future<List<String>> _uploadImages(
      List<String> paths, String recipeId) async {
    if (_uid == null) return paths;
    final resolved = <String>[];
    for (final path in paths) {
      if (ImageStorageService.isRemoteUrl(path)) {
        resolved.add(path);
      } else {
        final url = await ImageStorageService.uploadImage(
          localPath: path,
          userId: _uid!,
          recipeId: recipeId,
        );
        resolved.add(url ?? path);
      }
    }
    return resolved;
  }

  Future<void> addRecipe(Recipe recipe) async {
    final resolvedPaths = await _uploadImages(recipe.imagePaths, recipe.id);
    final resolvedMain = resolvedPaths.isNotEmpty &&
            recipe.mainImagePath != null &&
            !ImageStorageService.isRemoteUrl(recipe.mainImagePath!)
        ? resolvedPaths.firstWhere(
            (p) => ImageStorageService.isRemoteUrl(p),
            orElse: () => recipe.mainImagePath!)
        : recipe.mainImagePath;
    final resolved = recipe.copyWith(
      mainImagePath: resolvedMain,
      imagePaths: resolvedPaths,
    );

    final db = await DatabaseHelper.instance.database;
    await db.insert('recipes', withSync(resolved.toMap(), _uid));
    for (final ingredient in resolved.ingredients) {
      await db.insert(
          'recipe_ingredients', withSync(ingredient.toMap(), _uid));
    }
    for (final step in resolved.steps) {
      await db.insert('recipe_steps', withSync(step.toMap(), _uid));
    }
    for (final imagePath in resolved.imagePaths) {
      await db.insert('recipe_images', withSync({
        'id': _uuid.v4(),
        'recipe_id': resolved.id,
        'image_path': imagePath,
      }, _uid));
    }
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final resolvedPaths = await _uploadImages(recipe.imagePaths, recipe.id);
    // Map old local path → new URL for main image
    String? resolvedMain = recipe.mainImagePath;
    if (resolvedMain != null && !ImageStorageService.isRemoteUrl(resolvedMain)) {
      final idx = recipe.imagePaths.indexOf(resolvedMain);
      if (idx >= 0 && idx < resolvedPaths.length) {
        resolvedMain = resolvedPaths[idx];
      }
    }
    final resolved = recipe.copyWith(
      mainImagePath: resolvedMain,
      imagePaths: resolvedPaths,
    );

    final db = await DatabaseHelper.instance.database;
    await db.update(
      'recipes',
      withSync(resolved.toMap(), _uid),
      where: 'id = ?',
      whereArgs: [resolved.id],
    );
    await db.delete('recipe_ingredients',
        where: 'recipe_id = ?', whereArgs: [resolved.id]);
    await db.delete('recipe_steps',
        where: 'recipe_id = ?', whereArgs: [resolved.id]);
    await db.delete('recipe_images',
        where: 'recipe_id = ?', whereArgs: [resolved.id]);

    for (final ingredient in resolved.ingredients) {
      await db.insert(
          'recipe_ingredients', withSync(ingredient.toMap(), _uid));
    }
    for (final step in resolved.steps) {
      await db.insert('recipe_steps', withSync(step.toMap(), _uid));
    }
    for (final imagePath in resolved.imagePaths) {
      await db.insert('recipe_images', withSync({
        'id': _uuid.v4(),
        'recipe_id': resolved.id,
        'image_path': imagePath,
      }, _uid));
    }
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> rateRecipe(String id, int rating) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'recipes',
      withSync({'rating': rating}, _uid),
      where: 'id = ?',
      whereArgs: [id],
    );
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> markCooked(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('recipe_cookings', withSync({
      'id': _uuid.v4(),
      'recipe_id': id,
      'cooked_at': DateTime.now().toIso8601String(),
    }, _uid));
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> deleteRecipe(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }
}

// ─── Recipe with pantry availability ─────────────────────────────────────────

final recipeWithAvailabilityProvider =
    FutureProvider.family<Recipe, String>((ref, recipeId) async {
  final recipes = await ref.watch(recipesProvider.future);
  final recipe = recipes.firstWhere((r) => r.id == recipeId);
  final db = await DatabaseHelper.instance.database;

  final enrichedIngredients = <RecipeIngredient>[];
  for (final ingredient in recipe.ingredients) {
    if (ingredient.productId != null) {
      final prodMaps = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [ingredient.productId],
        limit: 1,
      );
      if (prodMaps.isNotEmpty) {
        final product = Product.fromMap(prodMaps.first);
        enrichedIngredients.add(ingredient.copyWith(
          availableQuantity: product.currentQuantity,
          isAvailable: product.currentQuantity >= ingredient.quantity,
        ));
      } else {
        enrichedIngredients
            .add(ingredient.copyWith(availableQuantity: 0, isAvailable: false));
      }
    } else {
      enrichedIngredients.add(ingredient.copyWith(isAvailable: null));
    }
  }

  double cost = 0;
  for (final ing in enrichedIngredients) {
    if (ing.productId != null) {
      final prodMaps = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [ing.productId],
        limit: 1,
      );
      if (prodMaps.isNotEmpty) {
        final product = Product.fromMap(prodMaps.first);
        if (product.lastPrice > 0 && product.quantityToMaintain > 0) {
          cost += (ing.quantity / product.quantityToMaintain) * product.lastPrice;
        }
      }
    }
  }

  return recipe.copyWith(
    ingredients: enrichedIngredients,
    estimatedCost: cost,
  );
});

// ─── Filter / search ──────────────────────────────────────────────────────────

final recipeTypeFilterProvider = StateProvider<String?>((ref) => null);
final recipeSearchProvider = StateProvider<String>((ref) => '');

final filteredRecipesProvider = Provider<AsyncValue<List<Recipe>>>((ref) {
  final recipes = ref.watch(recipesProvider);
  final typeFilter = ref.watch(recipeTypeFilterProvider);
  final search = ref.watch(recipeSearchProvider).toLowerCase();

  return recipes.whenData((list) => list.where((r) {
        final matchesType = typeFilter == null || r.type == typeFilter;
        final matchesSearch =
            search.isEmpty || r.name.toLowerCase().contains(search);
        return matchesType && matchesSearch;
      }).toList());
});
