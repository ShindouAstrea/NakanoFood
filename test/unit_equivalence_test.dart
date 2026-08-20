import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/features/pantry/models/product.dart';

/// Equivalencia por unidad, recuperada de la 2.5.2.
///
/// Un producto declara a cuánto equivale una de sus unidades ("1 paquete = 1
/// kg") para poder compararlo con recetas escritas en otra unidad.
void main() {
  final now = DateTime(2026, 8, 19);

  Product p({
    String unit = 'paquete',
    double? packageSize,
    String? packageBaseUnit,
    double currentQuantity = 2,
    double lastPrice = 0,
    double priceRefQty = 1,
  }) =>
      Product(
        id: 'p1',
        name: 'Harina',
        categoryId: 'c1',
        unit: unit,
        currentQuantity: currentQuantity,
        lastPrice: lastPrice,
        priceRefQty: priceRefQty,
        packageSize: packageSize,
        packageBaseUnit: packageBaseUnit,
        createdAt: now,
        updatedAt: now,
      );

  group('misma unidad', () {
    test('no convierte nada', () {
      expect(p(unit: 'kg').convertToRecipeUnit(2, 'kg'), 2);
    });

    test('reconoce sinónimos y mayúsculas', () {
      expect(p(unit: 'litro').convertToRecipeUnit(3, 'L'), 3);
      expect(p(unit: 'Kg').convertToRecipeUnit(1, 'kilos'), 1);
      expect(p(unit: 'gramos').convertToRecipeUnit(50, 'g'), 50);
    });
  });

  group('conversión métrica directa, sin equivalencia declarada', () {
    test('kg a g y vuelta', () {
      expect(p(unit: 'kg').convertToRecipeUnit(2, 'g'), 2000);
      expect(p(unit: 'g').convertToRecipeUnit(500, 'kg'), 0.5);
    });

    test('L a ml y vuelta', () {
      expect(p(unit: 'L').convertToRecipeUnit(1.5, 'ml'), 1500);
      expect(p(unit: 'ml').convertToRecipeUnit(250, 'L'), 0.25);
    });

    test('no mezcla peso con volumen', () {
      expect(p(unit: 'kg').convertToRecipeUnit(1, 'ml'), isNull);
    });
  });

  group('vía la equivalencia declarada', () {
    test('el caso de la app: 1 paquete = 1 kg', () {
      final harina = p(packageSize: 1, packageBaseUnit: 'kg');
      expect(harina.convertToRecipeUnit(2, 'kg'), 2);
      // Y encadena con la conversión métrica: 2 paquetes → 2 kg → 2000 g.
      expect(harina.convertToRecipeUnit(2, 'g'), 2000);
    });

    test('envases que no son de 1 unidad', () {
      final arroz = p(packageSize: 750, packageBaseUnit: 'g');
      expect(arroz.convertToRecipeUnit(2, 'g'), 1500);
      expect(arroz.convertToRecipeUnit(2, 'kg'), 1.5);
    });

    test('sin equivalencia declarada devuelve null, no adivina', () {
      expect(p().convertToRecipeUnit(2, 'g'), isNull);
      expect(p(packageSize: 0, packageBaseUnit: 'kg').convertToRecipeUnit(2, 'g'),
          isNull);
      expect(p(packageSize: 1).convertToRecipeUnit(2, 'g'), isNull);
    });

    test('equivalencia a una magnitud incompatible devuelve null', () {
      final x = p(packageSize: 1, packageBaseUnit: 'kg');
      expect(x.convertToRecipeUnit(2, 'ml'), isNull);
    });
  });

  group('el escenario que motivó la función', () {
    test('2 kg de harina alcanzan para una receta que pide 500 g', () {
      final harina = p(unit: 'kg', currentQuantity: 2);
      final disponible = harina.convertToRecipeUnit(harina.currentQuantity, 'g');
      expect(disponible, 2000);
      expect(disponible! >= 500, isTrue); // antes comparaba 2 >= 500 → falso
    });

    test('2 paquetes de 1 kg también alcanzan', () {
      final harina = p(packageSize: 1, packageBaseUnit: 'kg', currentQuantity: 2);
      final disponible = harina.convertToRecipeUnit(harina.currentQuantity, 'g');
      expect(disponible, 2000);
      expect(disponible! >= 500, isTrue);
    });
  });

  group('costo con unidades distintas', () {
    test('200 g de una harina a 1.200 el kg cuesta 240', () {
      final harina = p(unit: 'kg', lastPrice: 1200, priceRefQty: 1);
      final unaUnidadEnGramos = harina.convertToRecipeUnit(1, 'g');
      expect(unaUnidadEnGramos, 1000);
      final costo = (200 / unaUnidadEnGramos!) * harina.pricePerUnit;
      expect(costo, 240);
    });
  });
}
