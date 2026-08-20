import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/features/pantry/models/product.dart';

/// Cubre el arreglo del costo estimado de recetas.
///
/// El cálculo dividía por `quantityToMaintain` (el stock que quieres tener en
/// casa), que no tiene ninguna relación con el precio. El resultado era el
/// costo real dividido por el nivel de stock objetivo.
void main() {
  final now = DateTime(2026, 8, 19);

  Product leche({
    double lastPrice = 1200,
    double priceRefQty = 1,
    double quantityToMaintain = 6,
  }) =>
      Product(
        id: 'p1',
        name: 'Leche',
        categoryId: 'c1',
        unit: 'L',
        lastPrice: lastPrice,
        priceRefQty: priceRefQty,
        quantityToMaintain: quantityToMaintain,
        createdAt: now,
        updatedAt: now,
      );

  group('costo de un ingrediente', () {
    test('no depende del stock objetivo', () {
      final p = leche(quantityToMaintain: 6);
      // 1 litro de una leche a $1.200/L cuesta $1.200.
      expect(1 * p.pricePerUnit, 1200);

      // Y cambiar cuánto quieres mantener en casa no altera el precio.
      expect(leche(quantityToMaintain: 1).pricePerUnit,
          leche(quantityToMaintain: 20).pricePerUnit);
    });

    test('la fórmula anterior daba un resultado 6 veces menor', () {
      final p = leche(quantityToMaintain: 6);
      final formulaVieja = (1 / p.quantityToMaintain) * p.lastPrice;
      expect(formulaVieja, 200); // el bug
      expect(1 * p.pricePerUnit, 1200); // lo correcto
    });

    test('usa la cantidad de referencia del precio', () {
      // Arroz: $2.000 el paquete de 2 kg → $1.000 por kg.
      final arroz = leche(lastPrice: 2000, priceRefQty: 2);
      expect(arroz.pricePerUnit, 1000);
      expect(3 * arroz.pricePerUnit, 3000);
    });

    test('una cantidad de referencia en cero no revienta', () {
      // El campo no valida el 0; pricePerUnit debe protegerse de la división.
      final roto = leche(lastPrice: 1500, priceRefQty: 0);
      expect(roto.pricePerUnit, 1500);
      expect(roto.pricePerUnit.isFinite, isTrue);
    });
  });
}
