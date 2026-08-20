import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/features/recipes/models/recipe.dart';
import 'package:nakano_food/features/recipes/providers/pantry_index.dart';
import 'package:nakano_food/features/recipes/providers/cookable_provider.dart';
import 'package:nakano_food/features/pantry/models/product.dart';

void main() {
  final now = DateTime(2026, 8, 19);

  Product product({
    required String name,
    String unit = 'unidad',
    double quantity = 5,
    double? packageSize,
    String? packageBaseUnit,
  }) =>
      Product(
        id: 'prod-$name',
        name: name,
        categoryId: 'c1',
        unit: unit,
        currentQuantity: quantity,
        packageSize: packageSize,
        packageBaseUnit: packageBaseUnit,
        createdAt: now,
        updatedAt: now,
      );

  RecipeIngredient ing({
    required String name,
    double quantity = 1,
    String unit = 'unidad',
    String? productId,
  }) =>
      RecipeIngredient(
        id: 'ing-$name',
        recipeId: 'r1',
        productId: productId,
        productName: name,
        quantity: quantity,
        unit: unit,
      );

  Recipe recipe(List<RecipeIngredient> ingredients) => Recipe(
        id: 'r1',
        name: 'Prueba',
        type: 'Comida Principal',
        portions: 2,
        createdAt: now,
        updatedAt: now,
        ingredients: ingredients,
      );

  group('PantryIndex: cruce por nombre', () {
    test('encuentra el producto aunque el acento no coincida', () {
      final pantry = PantryIndex.from([product(name: 'Plátano')]);
      expect(pantry.matchFor(ing(name: 'platano'))?.name, 'Plátano');
      expect(pantry.matchFor(ing(name: '  PLATANO '))?.name, 'Plátano');
    });

    test('el productId manda sobre el nombre', () {
      final leche = product(name: 'Leche');
      final pantry = PantryIndex.from([leche, product(name: 'Crema')]);
      // Nombre "Crema" pero vinculado al id de Leche: gana el vínculo.
      final match =
          pantry.matchFor(ing(name: 'Crema', productId: 'prod-Leche'));
      expect(match?.name, 'Leche');
    });

    test('sin producto equivalente devuelve null', () {
      final pantry = PantryIndex.from([product(name: 'Arroz')]);
      expect(pantry.matchFor(ing(name: 'Azafrán')), isNull);
    });
  });

  group('PantryIndex: disponibilidad', () {
    test('convierte unidades: 2 kg alcanzan para 500 g', () {
      final pantry =
          PantryIndex.from([product(name: 'Harina', unit: 'kg', quantity: 2)]);
      expect(
          pantry.isAvailable(ing(name: 'Harina', quantity: 500, unit: 'g')),
          isTrue);
    });

    test('usa la equivalencia declarada del envase', () {
      final pantry = PantryIndex.from([
        product(
          name: 'Harina',
          unit: 'paquete',
          quantity: 2,
          packageSize: 1,
          packageBaseUnit: 'kg',
        )
      ]);
      expect(
          pantry.isAvailable(ing(name: 'Harina', quantity: 500, unit: 'g')),
          isTrue);
      expect(
          pantry.isAvailable(ing(name: 'Harina', quantity: 3000, unit: 'g')),
          isFalse);
    });

    test('devuelve null cuando no se puede afirmar, no false', () {
      // Sin equivalencia declarada, 'paquete' no se puede pasar a gramos.
      final pantry = PantryIndex.from(
          [product(name: 'Harina', unit: 'paquete', quantity: 2)]);
      expect(pantry.isAvailable(ing(name: 'Harina', quantity: 500, unit: 'g')),
          isNull);
    });

    test('aplica el multiplicador de porciones', () {
      final pantry =
          PantryIndex.from([product(name: 'Arroz', unit: 'g', quantity: 150)]);
      final arroz = ing(name: 'Arroz', quantity: 100, unit: 'g');
      expect(pantry.isAvailable(arroz), isTrue);
      expect(pantry.isAvailable(arroz, multiplier: 3), isFalse);
    });
  });

  group('Cookable: clasificación', () {
    test('con todo comprobado y disponible se puede cocinar', () {
      final r = recipe([ing(name: 'A'), ing(name: 'B')]);
      final c = Cookable(recipe: r, missing: const [], unknown: const []);
      expect(c.canCook, isTrue);
      expect(c.missingCount, 0);
    });

    test('faltando ingredientes no se puede cocinar', () {
      final r = recipe([ing(name: 'A'), ing(name: 'B')]);
      final c = Cookable(recipe: r, missing: [r.ingredients.first], unknown: const []);
      expect(c.canCook, isFalse);
      expect(c.missingCount, 1);
      expect(c.isClose, isTrue);
    });

    test('un ingrediente sin comprobar impide afirmar que se puede', () {
      final r = recipe([ing(name: 'A'), ing(name: 'B')]);
      final c = Cookable(
          recipe: r, missing: const [], unknown: [r.ingredients.last]);
      expect(c.canCook, isFalse);
      expect(c.isUnlinked, isFalse); // solo uno de dos
    });

    test('nada cruzado con la despensa es "sin recetas vinculadas"', () {
      final r = recipe([ing(name: 'A'), ing(name: 'B')]);
      final c = Cookable(recipe: r, missing: const [], unknown: r.ingredients);
      expect(c.isUnlinked, isTrue);
      expect(c.isClose, isFalse); // no se ofrece como "te falta poco"
    });

    test('con más de dos faltantes deja de estar cerca', () {
      final r = recipe(
          [ing(name: 'A'), ing(name: 'B'), ing(name: 'C'), ing(name: 'D')]);
      final c = Cookable(
          recipe: r, missing: r.ingredients.take(3).toList(), unknown: const []);
      expect(c.isClose, isFalse);
    });

    test('receta sin ingredientes: se puede cocinar trivialmente', () {
      final c = Cookable(recipe: recipe([]), missing: const [], unknown: const []);
      expect(c.canCook, isTrue);
      // isUnlinked usa longitudes: 0 == 0, se contempla en la UI aparte.
      expect(c.missingCount, 0);
    });
  });
}
