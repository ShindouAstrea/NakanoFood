import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/features/pantry/models/product.dart';
import 'package:nakano_food/features/pantry/widgets/product_picker.dart';

/// La búsqueda del selector de productos.
///
/// Se usa para vincular un ingrediente con su producto, así que arranca con el
/// nombre del ingrediente ya escrito: si buscar "papas medianas" no ofreciera
/// "Papas", el selector no serviría justo para el caso que existe.
void main() {
  final now = DateTime(2026, 8, 20);

  Product product(String name) => Product(
        id: 'prod-$name',
        name: name,
        categoryId: 'c1',
        unit: 'kg',
        currentQuantity: 1,
        createdAt: now,
        updatedAt: now,
      );

  final despensa = [
    product('Papas'),
    product('Arroz'),
    product('Aceite de oliva'),
    product('Papel higiénico'),
  ];

  List<String> buscar(String query) =>
      matchingProducts(despensa, query).map((p) => p.name).toList();

  test('el nombre del ingrediente encuentra el producto', () {
    expect(buscar('papas medianas'), contains('Papas'));
    expect(buscar('Papas peladas grandes'), contains('Papas'));
  });

  test('cruza singular con plural en los dos sentidos', () {
    expect(buscar('papa'), contains('Papas'));
    expect(buscar('papas'), contains('Papas'));
  });

  test('lo escrito a medias ya filtra', () {
    final resultado = buscar('pap');
    expect(resultado, contains('Papas'));
    expect(resultado, isNot(contains('Arroz')));
  });

  test('busca dentro de nombres de varias palabras', () {
    expect(buscar('aceite'), contains('Aceite de oliva'));
    expect(buscar('oliva'), contains('Aceite de oliva'));
  });

  test('el que mejor calza va primero', () {
    // "Papas" es el nombre exacto; "Papel higiénico" solo comparte el arranque.
    expect(buscar('papas').first, 'Papas');
  });

  test('sin coincidencias no inventa resultados', () {
    expect(buscar('azafrán'), isEmpty);
  });

  test('con la búsqueda vacía se ve la despensa entera, ordenada', () {
    expect(buscar(''),
        ['Aceite de oliva', 'Arroz', 'Papas', 'Papel higiénico']);
  });
}
