import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nakano_food/features/meal_planning/models/meal_plan.dart';
import 'package:nakano_food/features/meal_planning/models/meal_plan_item.dart';
import 'package:nakano_food/features/meal_planning/providers/meal_planning_provider.dart';
import 'package:nakano_food/features/pantry/models/product.dart';
import 'package:nakano_food/features/pantry/providers/pantry_provider.dart';
import 'package:nakano_food/features/pantry/widgets/plan_shopping_sheet.dart';
import 'package:nakano_food/features/recipes/models/recipe.dart';
import 'package:nakano_food/features/recipes/providers/recipe_provider.dart';

/// La hoja de "Comprar para el plan".
///
/// Se monta la hoja de verdad con el calendario, las recetas y la despensa
/// falseados: lo que se comprueba es que lo calculado llegue a la pantalla
/// —incluido lo que no se pudo calcular— y que quepa en un teléfono chico.
/// La escritura de la lista la cubre pantry_db_writes_test.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('es', null);
  });

  final today = DateTime.now();
  DateTime day(int offset) {
    final d = today.add(Duration(days: offset));
    return DateTime(d.year, d.month, d.day);
  }

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
        createdAt: today,
        updatedAt: today,
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

  Recipe recipe(List<RecipeIngredient> ingredients, {String id = 'r1'}) =>
      Recipe(
        id: id,
        name: 'Pan amasado',
        type: 'Comida Principal',
        createdAt: today,
        updatedAt: today,
        ingredients: ingredients,
      );

  MealPlan meal(DateTime date, String? recipeId) => MealPlan(
        id: 'mp-${date.day}-$recipeId',
        date: date,
        categoryId: 'cena',
        items: [
          MealPlanItem(
            id: 'item-${date.day}-$recipeId',
            mealPlanId: 'mp-${date.day}-$recipeId',
            title: recipeId ?? 'Sobras',
            recipeId: recipeId,
          ),
        ],
      );

  Future<void> openSheet(
    WidgetTester tester, {
    required List<MealPlan> plans,
    required List<Recipe> recipes,
    required List<Product> products,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealPlansProvider.overrideWith(() => _FakePlans(plans)),
          recipesProvider.overrideWith(() => _FakeRecipes(recipes)),
          productsProvider.overrideWith(() => _FakeProducts(products)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => startShoppingForPlan(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra cuánto falta y para cuántas comidas', (tester) async {
    await openSheet(
      tester,
      plans: [meal(day(0), 'r1'), meal(day(2), 'r1')],
      recipes: [
        recipe([ing(name: 'Harina', quantity: 500)])
      ],
      products: [product(name: 'Harina', unit: 'kg', quantity: 0.3)],
    );

    expect(find.text('Comprar para el plan'), findsOneWidget);
    expect(find.text('Harina'), findsOneWidget);
    // Dos cenas de 500 g son 1 kg; con 0,3 en casa faltan 0,7.
    expect(find.text('0,7 kg'), findsOneWidget);
    expect(find.text('Tienes 0,3 de 1 kg · 2 comidas'), findsOneWidget);
    expect(find.text('Crear lista (1)'), findsOneWidget);
  });

  testWidgets('separa lo que ya tienes de lo que hay que comprar',
      (tester) async {
    await openSheet(
      tester,
      plans: [meal(day(1), 'r1')],
      recipes: [
        recipe([
          ing(name: 'Harina', quantity: 500),
          ing(name: 'Azúcar', quantity: 100),
        ])
      ],
      products: [
        product(name: 'Harina', unit: 'kg', quantity: 0),
        product(name: 'Azúcar', unit: 'kg', quantity: 5),
      ],
    );

    expect(find.text('Ya tienes (1)'), findsOneWidget);
    expect(find.text('necesitas 0,1 kg'), findsOneWidget);
    expect(find.text('Crear lista (1)'), findsOneWidget);
  });

  testWidgets('dice qué no pudo agregar y por qué', (tester) async {
    await openSheet(
      tester,
      plans: [meal(day(1), 'r1')],
      recipes: [
        recipe([
          ing(name: 'Harina', quantity: 500),
          ing(name: 'Azafrán', quantity: 1, unit: 'pizca'),
          ing(name: 'Aceite', quantity: 30, unit: 'ml'),
        ])
      ],
      products: [
        product(name: 'Harina', unit: 'kg'),
        product(name: 'Aceite', unit: 'botella'),
      ],
    );

    expect(find.text('No se pueden agregar'), findsOneWidget);
    expect(find.textContaining('no está en la despensa'), findsOneWidget);
    expect(find.textContaining('no consta cuántos ml rinde 1 botella'),
        findsOneWidget);
  });

  testWidgets('cambiar el rango recalcula lo que falta', (tester) async {
    await openSheet(
      tester,
      plans: [meal(day(0), 'r1'), meal(day(5), 'r1')],
      recipes: [
        recipe([ing(name: 'Harina', quantity: 500)])
      ],
      products: [product(name: 'Harina', unit: 'kg')],
    );

    // Con 7 días entran las dos cenas.
    expect(find.text('1 kg'), findsOneWidget);

    await tester.tap(find.text('3 días'));
    await tester.pumpAndSettle();

    // Con 3, solo la de hoy.
    expect(find.text('0,5 kg'), findsOneWidget);
  });

  testWidgets('destildar un producto lo saca de la cuenta', (tester) async {
    await openSheet(
      tester,
      plans: [meal(day(1), 'r1')],
      recipes: [
        recipe([
          ing(name: 'Harina', quantity: 500),
          ing(name: 'Azúcar', quantity: 100),
        ])
      ],
      products: [
        product(name: 'Harina', unit: 'kg'),
        product(name: 'Azúcar', unit: 'kg'),
      ],
    );

    expect(find.text('Crear lista (2)'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.text('Crear lista (1)'), findsOneWidget);
  });

  testWidgets('sin nada planificado lo explica en vez de una lista vacía',
      (tester) async {
    await openSheet(
      tester,
      plans: [meal(day(1), null)],
      recipes: [
        recipe([ing(name: 'Harina')])
      ],
      products: [product(name: 'Harina', unit: 'kg')],
    );

    expect(find.text('Nada planificado en estos días'), findsOneWidget);
    expect(find.textContaining('ninguna está vinculada a una receta'),
        findsOneWidget);
    expect(find.text('Nada que comprar'), findsOneWidget);
  });

  testWidgets('cuando la despensa cubre el plan no manda a comprar de más',
      (tester) async {
    await openSheet(
      tester,
      plans: [meal(day(1), 'r1')],
      recipes: [
        recipe([ing(name: 'Harina', quantity: 500)])
      ],
      products: [product(name: 'Harina', unit: 'kg', quantity: 10)],
    );

    expect(find.text('Ya tienes todo'), findsOneWidget);
    expect(find.text('Nada que comprar'), findsOneWidget);
  });

  testWidgets('en un teléfono chico las filas caben sin desbordarse',
      (tester) async {
    // 320x568 lógicos: el suelo razonable de un teléfono en uso.
    tester.view.physicalSize = const Size(960, 1704);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await openSheet(
      tester,
      plans: [meal(day(0), 'r1'), meal(day(3), 'r1')],
      recipes: [
        recipe([
          ing(name: 'Harina sin polvos de hornear', quantity: 500),
          ing(name: 'Azúcar rubia', quantity: 100),
          ing(name: 'Aceite', quantity: 30, unit: 'ml'),
          ing(name: 'Sal de mar', quantity: 1, unit: 'pizca'),
        ])
      ],
      products: [
        product(name: 'Harina sin polvos de hornear', unit: 'kg'),
        product(name: 'Azúcar rubia', unit: 'kg', quantity: 9),
        product(name: 'Aceite', unit: 'botella'),
      ],
    );

    // Un overflow de RenderFlex hace fallar el test por sí solo; esto confirma
    // además que la hoja siguió siendo usable a ese ancho.
    expect(tester.takeException(), isNull);
    expect(find.text('Crear lista (1)'), findsOneWidget);
    expect(find.text('Ya tienes (1)'), findsOneWidget);
  });
}

class _FakePlans extends MealPlansNotifier {
  _FakePlans(this.plans);
  final List<MealPlan> plans;

  @override
  Future<List<MealPlan>> build() async => plans;
}

class _FakeRecipes extends RecipesNotifier {
  _FakeRecipes(this.recipes);
  final List<Recipe> recipes;

  @override
  Future<List<Recipe>> build() async => recipes;
}

class _FakeProducts extends ProductsNotifier {
  _FakeProducts(this.products);
  final List<Product> products;

  @override
  Future<List<Product>> build() async => products;
}
