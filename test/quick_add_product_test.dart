import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/features/pantry/models/product.dart';
import 'package:nakano_food/features/pantry/providers/pantry_provider.dart';
import 'package:nakano_food/features/pantry/widgets/product_picker.dart';
import 'package:nakano_food/features/pantry/widgets/quick_add_product.dart';

/// El alta rápida de un producto.
///
/// Existe para dos momentos en que pararse a llenar la ficha completa rompe lo
/// que estabas haciendo: en mitad de una compra y al vincular un ingrediente.
/// Por eso lo que se prueba es que con lo mínimo escrito ya quede creado, y
/// que lo que sí se escribe no se pierda.
void main() {
  final now = DateTime(2026, 8, 20);

  final categorias = [
    const ProductCategory(id: 'cat_alimentacion', name: 'Alimentación'),
    const ProductCategory(id: 'cat_aseo', name: 'Aseo'),
  ];

  Future<_Result> openQuickAdd(
    WidgetTester tester, {
    String? initialName,
  }) async {
    final result = _Result();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(() => _FakeCategories(categorias)),
          productsProvider.overrideWith(() => result.products),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result.created = await quickAddProduct(
                      context,
                      ref,
                      initialName: initialName,
                    );
                    result.closed = true;
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
    return result;
  }

  testWidgets('con solo el nombre ya queda creado', (tester) async {
    final result = await openQuickAdd(tester, initialName: 'Papas');

    expect(find.text('Producto nuevo'), findsOneWidget);
    expect(find.text('Papas'), findsOneWidget);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    final creado = result.products.added.single;
    expect(creado.name, 'Papas');
    // Lo que no se pregunta toma su valor neutro, y la categoría se elige sola.
    expect(creado.categoryId, 'cat_alimentacion');
    expect(creado.unit, 'unidad');
    expect(creado.currentQuantity, 0);
    expect(creado.lastPrice, 0);
    // Objetivo 1: nace marcado como "por reponer" hasta que se compre.
    expect(creado.quantityToMaintain, 1);
    expect(result.created?.name, 'Papas');
  });

  testWidgets('guarda la unidad, la cantidad y el precio que se escriban',
      (tester) async {
    final result = await openQuickAdd(tester, initialName: 'Arroz');

    await tester.tap(find.widgetWithText(ChoiceChip, 'kg'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Aseo'));
    await tester.enterText(find.widgetWithText(TextField, 'Tienes'), '2,5');
    await tester.enterText(find.widgetWithText(TextField, 'Precio'), '1200');
    await tester.pump();

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    final creado = result.products.added.single;
    expect(creado.unit, 'kg');
    expect(creado.categoryId, 'cat_aseo');
    // La coma del teclado en español se lee como decimal.
    expect(creado.currentQuantity, 2.5);
    expect(creado.lastPrice, 1200);
  });

  testWidgets('sin nombre no crea nada y lo dice', (tester) async {
    final result = await openQuickAdd(tester);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Ponle un nombre'), findsOneWidget);
    expect(result.products.added, isEmpty);
    expect(result.closed, isFalse);
  });

  testWidgets('cancelar no deja nada', (tester) async {
    final result = await openQuickAdd(tester, initialName: 'Papas');

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(result.products.added, isEmpty);
    expect(result.created, isNull);
    expect(result.closed, isTrue);
  });

  testWidgets('el selector ofrece crear lo que no encuentra', (tester) async {
    Product? elegido;
    final nuevo = Product(
      id: 'nuevo',
      name: 'Papas medianas',
      categoryId: 'cat_alimentacion',
      unit: 'kg',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  elegido = await pickPantryProduct(
                    context,
                    // La despensa tiene cosas, pero ninguna es esta: el caso
                    // real es tener productos y que el ingrediente no esté.
                    products: [
                      Product(
                        id: 'p-harina',
                        name: 'Harina',
                        categoryId: 'cat_alimentacion',
                        unit: 'kg',
                        createdAt: now,
                        updatedAt: now,
                      )
                    ],
                    initialQuery: 'papas medianas',
                    onCreate: (query) async => nuevo,
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Ningún producto coincide'), findsOneWidget);
    await tester.tap(find.text('Crear "papas medianas"'));
    await tester.pumpAndSettle();

    // Lo recién creado se devuelve sin obligar a buscarlo otra vez.
    expect(elegido?.id, 'nuevo');
  });

  testWidgets('sin forma de crear, el selector no lo ofrece', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => pickPantryProduct(
                  context,
                  products: const [],
                  initialQuery: 'papas',
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Crear'), findsNothing);
  });
}

class _Result {
  final products = _FakeProducts();
  Product? created;
  bool closed = false;
}

class _FakeCategories extends CategoriesNotifier {
  _FakeCategories(this.items);
  final List<ProductCategory> items;

  @override
  Future<List<ProductCategory>> build() async => items;
}

class _FakeProducts extends ProductsNotifier {
  final added = <Product>[];

  @override
  Future<List<Product>> build() async => added;

  @override
  Future<void> addProduct(
    Product product, {
    NutritionalValues? nutritionalValues,
  }) async {
    added.add(product);
  }
}
