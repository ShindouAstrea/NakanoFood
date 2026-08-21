import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/features/pantry/models/product.dart';
import 'package:nakano_food/features/pantry/providers/pantry_provider.dart';
import 'package:nakano_food/features/recipes/models/recipe.dart';
import 'package:nakano_food/features/recipes/providers/recipe_provider.dart';
import 'package:nakano_food/features/recipes/widgets/cook_deduction_sheet.dart';

/// La hoja que confirma el descuento.
///
/// Se monta la hoja de verdad, dentro de un modal, porque lo que puede fallar
/// aquí no es la aritmética —eso lo cubre cook_deduction_test— sino que la
/// fila no quepa en un teléfono chico, que lo que devuelve al cerrarse no sea
/// lo que el usuario dejó escrito, o que vincular no mueva nada en pantalla.
void main() {
  final now = DateTime(2026, 8, 20);

  Product product({
    required String name,
    String unit = 'kg',
    double quantity = 3,
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
    double quantity = 500,
    String unit = 'g',
  }) =>
      RecipeIngredient(
        id: 'ing-$name',
        recipeId: 'r1',
        productName: name,
        quantity: quantity,
        unit: unit,
      );

  Recipe recipe(List<RecipeIngredient> ingredients) => Recipe(
        id: 'r1',
        name: 'Pan amasado',
        type: 'Pastelería',
        createdAt: now,
        updatedAt: now,
        ingredients: ingredients,
      );

  /// Abre la hoja igual que la app —dentro de un modal— y devuelve el recibo
  /// donde quedará lo que entregue al cerrarse.
  Future<_Opened> openSheet(
    WidgetTester tester, {
    required List<RecipeIngredient> ingredients,
    required List<Product> products,
  }) async {
    final opened = _Opened(recipe(ingredients), products);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider.overrideWith(() => _FakeProducts(products)),
          recipesProvider.overrideWith(() => opened.recipes),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    opened.deltas =
                        await showModalBottomSheet<Map<String, double>>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) =>
                          CookDeductionSheet(recipe: opened.recipe),
                    );
                    opened.closed = true;
                  },
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
    return opened;
  }

  testWidgets('muestra qué queda en la despensa después de descontar',
      (tester) async {
    await openSheet(
      tester,
      ingredients: [ing(name: 'Harina', quantity: 500, unit: 'g')],
      products: [product(name: 'Harina', unit: 'kg', quantity: 3)],
    );

    expect(find.text('Descontar de la despensa'), findsOneWidget);
    expect(find.text('Harina'), findsOneWidget);
    // 500 g de una harina guardada en kg dejan 2,5 kg.
    expect(find.text('Quedan 2,5 kg'), findsOneWidget);
    // El campo se edita en la unidad de la receta, no en la del producto.
    expect(find.text('g'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
  });

  testWidgets('avisa cuando la despensa no alcanza', (tester) async {
    await openSheet(
      tester,
      ingredients: [ing(name: 'Harina', quantity: 800, unit: 'g')],
      products: [product(name: 'Harina', unit: 'kg', quantity: 0.5)],
    );

    expect(find.textContaining('Solo hay 0,5 kg'), findsOneWidget);
  });

  testWidgets('dice por qué un ingrediente no se descuenta', (tester) async {
    await openSheet(
      tester,
      ingredients: [
        ing(name: 'Harina', quantity: 500, unit: 'g'),
        ing(name: 'Azafrán', quantity: 1, unit: 'pizca'),
        ing(name: 'Aceite', quantity: 30, unit: 'ml'),
      ],
      products: [
        product(name: 'Harina', unit: 'kg'),
        product(name: 'Aceite', unit: 'botella'),
      ],
    );

    expect(find.text('No se descuentan'), findsOneWidget);
    expect(find.textContaining('no está en la despensa'), findsOneWidget);
    expect(find.textContaining('no consta cuántos ml rinde 1 botella'),
        findsOneWidget);
    // Vincular arregla el que falta; el de las unidades no, y por eso solo
    // aparece una vez.
    expect(find.text('Vincular'), findsOneWidget);
  });

  testWidgets('devuelve lo que el usuario dejó escrito, en unidades del producto',
      (tester) async {
    final harina = product(name: 'Harina', unit: 'kg', quantity: 3);
    final opened = await openSheet(
      tester,
      ingredients: [ing(name: 'Harina', quantity: 500, unit: 'g')],
      products: [harina],
    );

    await tester.enterText(find.byType(TextField).first, '200');
    await tester.pump();
    // Corregir la cantidad recalcula lo que queda, en vivo.
    expect(find.text('Quedan 2,8 kg'), findsOneWidget);

    await tester.tap(find.text('Descontar y registrar'));
    await tester.pumpAndSettle();

    // 200 g de una harina en kg son 0,2, no los 0,5 que pedía la receta.
    expect(opened.deltas, {harina.id: 0.2});
  });

  testWidgets('desmarcar una línea la deja fuera del descuento',
      (tester) async {
    final harina = product(name: 'Harina', unit: 'kg');
    final azucar = product(name: 'Azúcar', unit: 'kg');
    final opened = await openSheet(
      tester,
      ingredients: [
        ing(name: 'Harina', quantity: 500, unit: 'g'),
        ing(name: 'Azúcar', quantity: 100, unit: 'g'),
      ],
      products: [harina, azucar],
    );

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    expect(find.text('No se descuenta'), findsOneWidget);

    await tester.tap(find.text('Descontar y registrar'));
    await tester.pumpAndSettle();

    expect(opened.deltas, {harina.id: 0.5});
  });

  testWidgets('solo registrar devuelve un descuento vacío', (tester) async {
    final opened = await openSheet(
      tester,
      ingredients: [ing(name: 'Harina', quantity: 500, unit: 'g')],
      products: [product(name: 'Harina', unit: 'kg')],
    );

    await tester.tap(find.text('Solo registrar la receta'));
    await tester.pumpAndSettle();

    // Vacío, no null: la receta se registra pero la despensa no se toca.
    expect(opened.closed, isTrue);
    expect(opened.deltas, isEmpty);
  });

  testWidgets('si no se pudo descontar nada, lo explica en vez de callarlo',
      (tester) async {
    final opened = await openSheet(
      tester,
      ingredients: [ing(name: 'Azafrán', quantity: 1, unit: 'pizca')],
      products: [product(name: 'Harina', unit: 'kg')],
    );

    expect(find.text('No se pudo descontar nada'), findsOneWidget);
    expect(find.textContaining('no está en la despensa'), findsOneWidget);
    // Sin nada que ajustar no hay campos ni checkbox que ofrecer.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('Registrar de todos modos'));
    await tester.pumpAndSettle();

    expect(opened.closed, isTrue);
    expect(opened.deltas, isEmpty);
  });

  testWidgets('vincular "papas medianas" con "Papas" lo pone a descontar',
      (tester) async {
    // El caso que ninguna regla automática puede resolver: la receta llama al
    // ingrediente como se cocina y la despensa como se compra.
    final papas = product(
      name: 'Papas',
      unit: 'kg',
      quantity: 2,
      packageSize: 6,
      packageBaseUnit: 'unidad',
    );
    final opened = await openSheet(
      tester,
      ingredients: [ing(name: 'papas medianas', quantity: 3, unit: 'unidad')],
      products: [papas],
    );

    expect(find.text('No se pudo descontar nada'), findsOneWidget);

    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();

    // El selector se abre con el nombre del ingrediente ya buscado y aun así
    // encuentra el producto, que es de lo que se trata.
    expect(find.text('Vincular con un producto'), findsOneWidget);
    await tester.tap(find.text('Papas'));
    await tester.pumpAndSettle();

    // El vínculo queda guardado en la receta, no solo en esta pantalla.
    expect(opened.recipes.linked, {'ing-papas medianas': papas.id});

    // Y la fila salta a descontable: 3 de 6 papas por kilo son medio kilo.
    expect(find.text('Descontar de la despensa'), findsOneWidget);
    expect(find.text('Quedan 1,5 kg'), findsOneWidget);

    await tester.tap(find.text('Descontar y registrar'));
    await tester.pumpAndSettle();

    expect(opened.deltas, {papas.id: 0.5});
  });

  testWidgets('en un teléfono chico las filas caben sin desbordarse',
      (tester) async {
    // 320x568 lógicos: el suelo razonable de un teléfono en uso.
    tester.view.physicalSize = const Size(960, 1704);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await openSheet(
      tester,
      ingredients: [
        ing(name: 'Harina sin polvos de hornear', quantity: 500, unit: 'g'),
        ing(name: 'Azúcar', quantity: 100, unit: 'cucharadita'),
        ing(name: 'Aceite', quantity: 30, unit: 'ml'),
        ing(name: 'Sal', quantity: 1, unit: 'pizca'),
      ],
      products: [
        product(name: 'Harina sin polvos de hornear', unit: 'kg'),
        product(name: 'Azúcar', unit: 'kg'),
        product(name: 'Aceite', unit: 'botella'),
      ],
    );

    // Un overflow de RenderFlex hace fallar el test por sí solo; esto confirma
    // además que la hoja siguió siendo usable a ese ancho.
    expect(tester.takeException(), isNull);
    expect(find.text('Descontar y registrar'), findsOneWidget);
    expect(find.text('Vincular'), findsOneWidget);
  });
}

/// Lo que la hoja entregó al cerrarse, y la receta con la que se abrió.
class _Opened {
  _Opened(this.recipe, this.products) : recipes = _FakeRecipes([recipe]);

  final Recipe recipe;
  final List<Product> products;
  final _FakeRecipes recipes;

  Map<String, double>? deltas;
  bool closed = false;
}

class _FakeProducts extends ProductsNotifier {
  _FakeProducts(this.items);
  final List<Product> items;

  @override
  Future<List<Product>> build() async => items;
}

class _FakeRecipes extends RecipesNotifier {
  _FakeRecipes(this.items);
  final List<Recipe> items;

  /// Vínculos guardados, para comprobar que no se quedan en la pantalla.
  final linked = <String, String>{};

  @override
  Future<List<Recipe>> build() async => items;

  @override
  Future<void> linkIngredient({
    required String ingredientId,
    required String productId,
  }) async {
    linked[ingredientId] = productId;
  }
}
