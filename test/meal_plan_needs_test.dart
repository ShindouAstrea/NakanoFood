import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/features/meal_planning/models/meal_plan.dart';
import 'package:nakano_food/features/meal_planning/models/meal_plan_item.dart';
import 'package:nakano_food/features/meal_planning/providers/meal_plan_needs.dart';
import 'package:nakano_food/features/pantry/models/product.dart';
import 'package:nakano_food/features/recipes/models/recipe.dart';

/// Qué comprar para cocinar lo planificado.
///
/// Cruza los tres módulos —calendario, recetas y despensa— así que lo que se
/// prueba aquí es que ninguno de los tres se pierda por el camino: que sume
/// las comidas del rango y solo las del rango, que reste lo que ya hay, y que
/// diga en voz alta lo que no supo calcular en vez de dejarlo fuera callando.
void main() {
  final now = DateTime(2026, 8, 20);

  Product product({
    required String name,
    String unit = 'kg',
    double quantity = 0,
  }) =>
      Product(
        id: 'prod-$name',
        name: name,
        categoryId: 'c1',
        unit: unit,
        currentQuantity: quantity,
        createdAt: now,
        updatedAt: now,
      );

  RecipeIngredient ing({
    required String name,
    double quantity = 500,
    String unit = 'g',
  }) =>
      RecipeIngredient(
        id: 'ing-$name-$unit',
        recipeId: 'r1',
        productName: name,
        quantity: quantity,
        unit: unit,
      );

  Recipe recipe({
    required String id,
    required List<RecipeIngredient> ingredients,
  }) =>
      Recipe(
        id: id,
        name: 'Receta $id',
        type: 'Comida Principal',
        createdAt: now,
        updatedAt: now,
        ingredients: ingredients,
      );

  /// Una comida planificada: fecha y receta (o texto suelto si [recipeId] es
  /// null, como cuando se anota "sobras" sin vincular nada).
  MealPlan meal(DateTime date, String? recipeId, {String id = 'mp'}) => MealPlan(
        id: '$id-${date.day}-$recipeId',
        date: date,
        categoryId: 'cena',
        items: [
          MealPlanItem(
            id: 'item-$id-${date.day}-$recipeId',
            mealPlanId: '$id-${date.day}-$recipeId',
            title: recipeId ?? 'Lo que haya',
            recipeId: recipeId,
          ),
        ],
      );

  MealPlanNeeds build({
    required List<MealPlan> plans,
    required List<Recipe> recipes,
    required List<Product> products,
    int days = 7,
  }) =>
      MealPlanNeeds.build(
        plans: plans,
        recipes: recipes,
        products: products,
        from: now,
        to: now.add(Duration(days: days - 1)),
      );

  group('suma lo que piden las recetas del rango', () {
    test('agrega entre comidas y convierte a unidades del producto', () {
      final plan = build(
        plans: [
          meal(now, 'r1'),
          meal(now.add(const Duration(days: 2)), 'r1'),
        ],
        recipes: [
          recipe(id: 'r1', ingredients: [ing(name: 'Harina', quantity: 500)]),
        ],
        products: [product(name: 'Harina', unit: 'kg')],
      );

      // 500 g dos veces son 1 kg, que es como se guarda la harina.
      expect(plan.needs.single.needed, 1);
      expect(plan.mealsPlanned, 2);
    });

    test('deja fuera lo planificado antes o después del rango', () {
      final plan = build(
        days: 3,
        plans: [
          meal(now.subtract(const Duration(days: 1)), 'r1'),
          meal(now.add(const Duration(days: 1)), 'r1'),
          meal(now.add(const Duration(days: 9)), 'r1'),
        ],
        recipes: [
          recipe(id: 'r1', ingredients: [ing(name: 'Harina', quantity: 500)]),
        ],
        products: [product(name: 'Harina', unit: 'kg')],
      );

      expect(plan.mealsPlanned, 1);
      expect(plan.needs.single.needed, 0.5);
    });

    test('el último día del rango entra', () {
      final plan = build(
        days: 7,
        plans: [meal(now.add(const Duration(days: 6)), 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [ing(name: 'Harina')]),
        ],
        products: [product(name: 'Harina', unit: 'kg')],
      );

      expect(plan.mealsPlanned, 1);
    });

    test('cuenta comidas, no ingredientes repetidos', () {
      // La harina aparece dos veces en la misma receta: la masa y el molde.
      final plan = build(
        plans: [meal(now, 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [
            ing(name: 'Harina', quantity: 500),
            ing(name: 'Harina', quantity: 100),
          ]),
        ],
        products: [product(name: 'Harina', unit: 'kg')],
      );

      expect(plan.needs.single.needed, 0.6);
      expect(plan.needs.single.meals, 1);
    });
  });

  group('descuenta lo que ya hay en la despensa', () {
    test('solo falta la diferencia', () {
      final plan = build(
        plans: [meal(now, 'r1'), meal(now.add(const Duration(days: 1)), 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [ing(name: 'Harina', quantity: 500)]),
        ],
        products: [product(name: 'Harina', unit: 'kg', quantity: 0.3)],
      );

      final need = plan.needs.single;
      expect(need.needed, 1);
      expect(need.available, 0.3);
      expect(need.missing, 0.7);
      expect(need.isCovered, isFalse);
    });

    test('lo que alcanza queda cubierto y no se compra', () {
      final plan = build(
        plans: [meal(now, 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [ing(name: 'Harina', quantity: 500)]),
        ],
        products: [product(name: 'Harina', unit: 'kg', quantity: 2)],
      );

      expect(plan.needs.single.isCovered, isTrue);
      expect(plan.toBuy, isEmpty);
      expect(plan.covered, hasLength(1));
      expect(plan.hasSomethingToBuy, isFalse);
    });

    test('lo que falta va primero en la lista', () {
      final plan = build(
        plans: [meal(now, 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [
            ing(name: 'Azúcar', quantity: 100),
            ing(name: 'Harina', quantity: 500),
          ]),
        ],
        products: [
          product(name: 'Azúcar', unit: 'kg', quantity: 5),
          product(name: 'Harina', unit: 'kg', quantity: 0),
        ],
      );

      expect(plan.needs.first.product.name, 'Harina');
      expect(plan.needs.last.product.name, 'Azúcar');
    });
  });

  group('lo que no se puede pedir se dice', () {
    test('un ingrediente que no está en la despensa, una sola vez', () {
      final plan = build(
        plans: [meal(now, 'r1'), meal(now.add(const Duration(days: 1)), 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [ing(name: 'Azafrán', quantity: 1)]),
        ],
        products: [product(name: 'Harina')],
      );

      expect(plan.skipped, hasLength(1));
      expect(plan.skipped.single.name, 'Azafrán');
      expect(plan.skipped.single.isMissingFromPantry, isTrue);
      expect(plan.needs, isEmpty);
    });

    test('unidades que no se pueden equiparar, con el producto que las tiene',
        () {
      final plan = build(
        plans: [meal(now, 'r1')],
        recipes: [
          recipe(id: 'r1',
              ingredients: [ing(name: 'Aceite', quantity: 30, unit: 'ml')]),
        ],
        products: [product(name: 'Aceite', unit: 'botella')],
      );

      final skipped = plan.skipped.single;
      expect(skipped.isMissingFromPantry, isFalse);
      expect(skipped.productUnit, 'botella');
      expect(skipped.recipeUnit, 'ml');
    });

    test('las comidas anotadas sin receta se cuentan aparte', () {
      final plan = build(
        plans: [meal(now, null), meal(now.add(const Duration(days: 1)), 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [ing(name: 'Harina')]),
        ],
        products: [product(name: 'Harina', unit: 'kg')],
      );

      expect(plan.mealsWithoutRecipe, 1);
      expect(plan.mealsPlanned, 1);
    });

    test('una receta borrada no rompe el cálculo del resto', () {
      final plan = build(
        plans: [meal(now, 'r-borrada'), meal(now, 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [ing(name: 'Harina', quantity: 500)]),
        ],
        products: [product(name: 'Harina', unit: 'kg')],
      );

      expect(plan.mealsWithoutRecipe, 1);
      expect(plan.needs.single.needed, 0.5);
    });

    test('sin nada planificado lo dice, en vez de una lista vacía', () {
      final plan = build(
        plans: [meal(now.add(const Duration(days: 30)), 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [ing(name: 'Harina')]),
        ],
        products: [product(name: 'Harina', unit: 'kg')],
      );

      expect(plan.hasNothingPlanned, isTrue);
    });
  });

  group('lo que se lleva a la lista de compras', () {
    test('solo lo que falta, en unidades del producto', () {
      final harina = product(name: 'Harina', unit: 'kg', quantity: 0.3);
      final azucar = product(name: 'Azúcar', unit: 'kg', quantity: 5);
      final plan = build(
        plans: [meal(now, 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [
            ing(name: 'Harina', quantity: 500),
            ing(name: 'Azúcar', quantity: 100),
          ]),
        ],
        products: [harina, azucar],
      );

      expect(shoppingQuantities(plan.needs), {harina.id: 0.2});
    });

    test('deja fuera lo que el usuario destildó', () {
      final plan = build(
        plans: [meal(now, 'r1')],
        recipes: [
          recipe(id: 'r1', ingredients: [
            ing(name: 'Harina', quantity: 500),
            ing(name: 'Azúcar', quantity: 100),
          ]),
        ],
        products: [
          product(name: 'Harina', unit: 'kg'),
          product(name: 'Azúcar', unit: 'kg'),
        ],
      );

      final soloHarina =
          plan.toBuy.where((n) => n.product.name == 'Harina');
      expect(shoppingQuantities(soloHarina), {'prod-Harina': 0.5});
    });
  });
}
