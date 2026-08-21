import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/features/pantry/models/product.dart';
import 'package:nakano_food/features/recipes/models/recipe.dart';
import 'package:nakano_food/features/recipes/providers/cook_deduction.dart';

/// Descuento de la despensa al cocinar.
///
/// Lo que se resta del stock sale de convertir la cantidad de la receta a
/// unidades del producto, y ahí el error típico es de un factor mil: restar un
/// kilo de harina cuando la receta pedía un gramo vacía la despensa de golpe.
/// Por eso cada camino de conversión tiene su prueba.
void main() {
  final now = DateTime(2026, 8, 20);

  Product product({
    String name = 'Harina',
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
    String name = 'Harina',
    double quantity = 500,
    String unit = 'g',
  }) =>
      RecipeIngredient(
        id: 'ing-$name-$unit-$quantity',
        recipeId: 'r1',
        productName: name,
        quantity: quantity,
        unit: unit,
      );

  CookDeduction plan(
    List<RecipeIngredient> ingredients,
    List<Product> products, {
    double multiplier = 1,
  }) =>
      CookDeduction.build(
        recipe: Recipe(
          id: 'r1',
          name: 'Prueba',
          type: 'Comida Principal',
          createdAt: now,
          updatedAt: now,
          ingredients: ingredients,
        ),
        products: products,
        multiplier: multiplier,
      );

  group('pasar la cantidad de la receta a unidades del producto', () {
    test('misma unidad, nada que convertir', () {
      expect(product(unit: 'g').convertFromRecipeUnit(500, 'g'), 500);
    });

    test('500 g de una harina guardada en kg son 0,5', () {
      expect(product(unit: 'kg').convertFromRecipeUnit(500, 'g'), 0.5);
    });

    test('vía la equivalencia declarada: 200 g de un paquete de 1 kg', () {
      final harina =
          product(unit: 'paquete', packageSize: 1, packageBaseUnit: 'kg');
      expect(harina.convertFromRecipeUnit(200, 'g'), 0.2);
    });

    test('sin equivalencia declarada devuelve null, no adivina', () {
      expect(product(unit: 'paquete').convertFromRecipeUnit(200, 'g'), isNull);
    });

    test('no mezcla peso con volumen', () {
      expect(product(unit: 'kg').convertFromRecipeUnit(200, 'ml'), isNull);
    });

    test('es el inverso exacto de convertToRecipeUnit', () {
      final arroz =
          product(unit: 'paquete', packageSize: 750, packageBaseUnit: 'g');
      expect(arroz.convertToRecipeUnit(2, 'g'), 1500);
      expect(arroz.convertFromRecipeUnit(1500, 'g'), 2);
    });
  });

  group('plan de descuento', () {
    test('descuenta en unidades del producto, no en las de la receta', () {
      final line = plan(
        [ing(quantity: 500, unit: 'g')],
        [product(unit: 'kg', quantity: 3)],
      ).lines.single;

      expect(line.status, DeductionStatus.ok);
      expect(line.recipeAmount, 500);
      expect(line.productAmount, 0.5);
      expect(line.remainingAfter, 2.5);
    });

    test('respeta el multiplicador de porciones', () {
      final line = plan(
        [ing(quantity: 500, unit: 'g')],
        [product(unit: 'kg')],
        multiplier: 2,
      ).lines.single;

      expect(line.recipeAmount, 1000);
      expect(line.productAmount, 1);
    });

    test('un ingrediente que no está en la despensa no se descuenta', () {
      final result = plan([ing(name: 'Azafrán')], [product(name: 'Harina')]);

      expect(result.lines.single.status, DeductionStatus.unmatched);
      expect(result.hasDeductible, isFalse);
      expect(result.skipped, hasLength(1));
    });

    test('unidades que no se pueden equiparar no se descuentan', () {
      final line = plan([ing(unit: 'taza')], [product(unit: 'kg')]).lines.single;

      expect(line.status, DeductionStatus.unconvertible);
      expect(line.productAmount, isNull);
      expect(line.isDeductible, isFalse);
    });

    test('cruza por nombre aunque la receta no traiga productId', () {
      final line = plan(
        [ing(name: 'plátano', quantity: 2, unit: 'unidad')],
        [product(name: 'Plátano', unit: 'unidad', quantity: 5)],
      ).lines.single;

      expect(line.product?.name, 'Plátano');
      expect(line.productAmount, 2);
    });
  });

  group('el caso de las papas: 1 kg rinde 6', () {
    Product papas({double quantity = 2}) => Product(
          id: 'p-papas',
          name: 'Papas',
          categoryId: 'c1',
          unit: 'kg',
          currentQuantity: quantity,
          packageSize: 6,
          packageBaseUnit: 'unidad',
          createdAt: now,
          updatedAt: now,
        );

    test('3 papas de una receta son medio kilo de la despensa', () {
      final line = plan(
        [ing(name: 'Papas', quantity: 3, unit: 'unidad')],
        [papas()],
      ).lines.single;

      expect(line.status, DeductionStatus.ok);
      expect(line.productAmount, 0.5);
      expect(line.remainingAfter, 1.5);
    });

    test('da igual el singular o el plural', () {
      for (final escrito in ['papas', 'Papa', 'PAPAS', 'papa']) {
        final line = plan(
          [ing(name: escrito, quantity: 3, unit: 'unidad')],
          [papas()],
        ).lines.single;
        expect(line.product?.name, 'Papas', reason: 'escrito como "$escrito"');
      }
    });

    test('también al revés: despensa en singular, receta en plural', () {
      final line = plan(
        [ing(name: 'Tomates', quantity: 2, unit: 'unidad')],
        [
          Product(
            id: 'p-tomate',
            name: 'Tomate',
            categoryId: 'c1',
            unit: 'unidad',
            currentQuantity: 5,
            createdAt: now,
            updatedAt: now,
          )
        ],
      ).lines.single;

      expect(line.product?.name, 'Tomate');
      expect(line.productAmount, 2);
    });

    test('sin la equivalencia declarada no se inventa el descuento', () {
      final line = plan(
        [ing(name: 'Papas', quantity: 3, unit: 'unidad')],
        [
          Product(
            id: 'p-papas',
            name: 'Papas',
            categoryId: 'c1',
            unit: 'kg',
            currentQuantity: 2,
            createdAt: now,
            updatedAt: now,
          )
        ],
      ).lines.single;

      expect(line.status, DeductionStatus.unconvertible);
    });

    test('quitar la ese no cruza palabras cortas ni distintas', () {
      final despensa = [
        Product(
          id: 'p-gas',
          name: 'Gas',
          categoryId: 'c1',
          unit: 'unidad',
          currentQuantity: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      expect(
        plan([ing(name: 'Ga', quantity: 1, unit: 'unidad')], despensa)
            .lines
            .single
            .status,
        DeductionStatus.unmatched,
      );
      expect(
        plan([ing(name: 'Arroz', quantity: 1, unit: 'unidad')], despensa)
            .lines
            .single
            .status,
        DeductionStatus.unmatched,
      );
    });
  });

  group('cuando la despensa no alcanza', () {
    test('el stock queda en cero, nunca en negativo', () {
      final line = plan(
        [ing(quantity: 800, unit: 'g')],
        [product(unit: 'kg', quantity: 0.5)],
      ).lines.single;

      expect(line.status, DeductionStatus.partial);
      expect(line.productAmount, 0.8);
      expect(line.effectiveAmount, 0.5);
      expect(line.remainingAfter, 0);
    });
  });

  group('totales por producto', () {
    test('suma las dos veces que la receta ocupa el mismo producto', () {
      final harina = product(unit: 'kg', quantity: 3);
      final result = plan(
        [ing(quantity: 500, unit: 'g'), ing(quantity: 200, unit: 'g')],
        [harina],
      );

      expect(totalsByProduct(result.deductible), {harina.id: 0.7});
    });

    test('deja fuera lo que no se puede descontar', () {
      final result = plan(
        [ing(name: 'Azafrán'), ing(quantity: 500, unit: 'g')],
        [product(name: 'Harina', unit: 'kg')],
      );

      expect(totalsByProduct(result.lines).values, [0.5]);
    });

    test('una línea en cero no entra', () {
      final line = plan(
        [ing(quantity: 500, unit: 'g')],
        [product(unit: 'kg')],
      ).lines.single;

      expect(totalsByProduct([line.withRecipeAmount(0)]), isEmpty);
    });
  });

  group('corregir a mano lo que se ocupó', () {
    test('recalcula la conversión y el estado', () {
      final line = plan(
        [ing(quantity: 500, unit: 'g')],
        [product(unit: 'kg', quantity: 0.3)],
      ).lines.single;
      expect(line.status, DeductionStatus.partial);

      final corregida = line.withRecipeAmount(200);
      expect(corregida.productAmount, 0.2);
      expect(corregida.status, DeductionStatus.ok);
      expect(corregida.remainingAfter, 0.1);
    });
  });
}
