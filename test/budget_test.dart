import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/features/pantry/providers/budget_provider.dart';
import 'package:nakano_food/features/pantry/models/shopping_session.dart';

void main() {
  group('BudgetStatus', () {
    test('dentro del presupuesto', () {
      const s = BudgetStatus(budget: 200000, spent: 50000);
      expect(s.percentUsed, 25);
      expect(s.isExceeded, isFalse);
      expect(s.isNearLimit, isFalse);
      expect(s.remaining, 150000);
      expect(s.exceededBy, 0);
    });

    test('avisa a partir del 80 %, antes de pasarse', () {
      const justo = BudgetStatus(budget: 100000, spent: 79999);
      expect(justo.isNearLimit, isFalse);

      const cerca = BudgetStatus(budget: 100000, spent: 80000);
      expect(cerca.isNearLimit, isTrue);
      expect(cerca.isExceeded, isFalse);
    });

    test('superado: informa el exceso y no deja restante negativo', () {
      const s = BudgetStatus(budget: 100000, spent: 130000);
      expect(s.isExceeded, isTrue);
      expect(s.exceededBy, 30000);
      expect(s.remaining, 0);
      expect(s.percentUsed, 130);
      // isNearLimit es para el aviso previo; superado ya no es "cerca".
      expect(s.isNearLimit, isFalse);
    });

    test('justo en el límite no cuenta como superado', () {
      const s = BudgetStatus(budget: 100000, spent: 100000);
      expect(s.isExceeded, isFalse);
      expect(s.remaining, 0);
      expect(s.percentUsed, 100);
    });

    test('presupuesto cero no divide por cero', () {
      const s = BudgetStatus(budget: 0, spent: 5000);
      expect(s.ratio, 0);
      expect(s.ratio.isFinite, isTrue);
    });
  });

  group('calculatedTotal de una compra', () {
    ShoppingItem item({
      required bool purchased,
      double planned = 1000,
      double actual = 0,
      double qty = 1,
    }) =>
        ShoppingItem(
          id: 'i',
          sessionId: 's',
          productId: 'p',
          productName: 'X',
          unit: 'unidad',
          plannedQuantity: qty,
          plannedPrice: planned,
          actualPrice: actual,
          isPurchased: purchased,
        );

    ShoppingSession session(List<ShoppingItem> items) => ShoppingSession(
          id: 's',
          createdAt: DateTime(2026, 8, 19),
          items: items,
        );

    test('solo cuenta lo comprado', () {
      // El bug: una sesión arranca con la despensa entera, así que los no
      // comprados inflaban el total con su precio estimado.
      final s = session([
        item(purchased: true, actual: 3000),
        item(purchased: false, planned: 50000),
        item(purchased: false, planned: 20000),
      ]);
      expect(s.calculatedTotal, 3000);
      expect(s.purchasedCount, 1);
    });

    test('usa el precio real cuando existe', () {
      final s = session([item(purchased: true, planned: 1000, actual: 1500)]);
      expect(s.calculatedTotal, 1500);
    });

    test('cae al precio estimado si no se registró el real', () {
      final s = session([item(purchased: true, planned: 1200, actual: 0)]);
      expect(s.calculatedTotal, 1200);
    });

    test('multiplica por la cantidad', () {
      final s = session([item(purchased: true, actual: 500, qty: 3)]);
      expect(s.calculatedTotal, 1500);
    });

    test('sin nada comprado el total es cero, no el estimado', () {
      final s = session([item(purchased: false, planned: 99000)]);
      expect(s.calculatedTotal, 0);
    });
  });
}
