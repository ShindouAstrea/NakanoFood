import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/features/pantry/data/unit_conversion_seed.dart';
import 'package:nakano_food/shared/utils/unit_conversion.dart';

/// El conversor de unidades de cocina.
///
/// Lo que se prueba aquí termina restándose de la despensa de verdad, así que
/// hay dos clases de fallo que vigilar y son opuestas: inventarse un factor
/// (descontar un kilo donde iba un gramo) y no encontrar uno que sí consta
/// (dejar al usuario sin poder descontar nada porque su receta habla de
/// cucharadas). Cada grupo cubre uno de los dos lados.
void main() {
  group('leer la unidad como venga escrita', () {
    test('mayúsculas, acentos y puntos', () {
      expect(canonicalUnit('Cucharada'), 'cucharada');
      expect(canonicalUnit('  KG '), 'kg');
      expect(canonicalUnit('cdta.'), 'cucharadita');
    });

    test('abreviaturas de recetario', () {
      expect(canonicalUnit('cda'), 'cucharada');
      expect(canonicalUnit('tbsp'), 'cucharada');
      expect(canonicalUnit('tsp'), 'cucharadita');
      expect(canonicalUnit('cup'), 'taza');
      expect(canonicalUnit('cc'), 'ml');
      expect(canonicalUnit('lts'), 'l');
      expect(canonicalUnit('gr'), 'g');
    });

    test('plurales regulares', () {
      expect(canonicalUnit('cucharadas'), 'cucharada');
      expect(canonicalUnit('cucharaditas'), 'cucharadita');
      expect(canonicalUnit('tazas'), 'taza');
      expect(canonicalUnit('gramos'), 'g');
      expect(canonicalUnit('kilos'), 'kg');
      expect(canonicalUnit('unidades'), 'unidad');
      expect(canonicalUnit('dientes'), 'diente');
      expect(canonicalUnit('rebanadas'), 'rebanada');
    });

    test('formas que dicen lo mismo con otra palabra', () {
      expect(canonicalUnit('cuchara sopera'), 'cucharada');
      expect(canonicalUnit('cucharadita de té'), 'cucharadita');
      expect(canonicalUnit('lonja'), 'rebanada');
      expect(canonicalUnit('sachet'), 'sobre');
    });

    test('una unidad que la app no conoce se respeta, pero sin plural', () {
      // Para que "2 bidones" y "1 bidón" sean la misma unidad y la
      // equivalencia que el usuario declare para una valga para la otra.
      expect(canonicalUnit('bidones'), canonicalUnit('bidone'));
      // Y no se parten palabras cortas acabadas en ese.
      expect(canonicalUnit('gas'), 'gas');
    });

    test('clasifica la magnitud', () {
      expect(unitKind('kg'), UnitKind.weight);
      expect(unitKind('cucharada'), UnitKind.volume);
      expect(unitKind('taza'), UnitKind.volume);
      expect(unitKind('docena'), UnitKind.count);
      expect(unitKind('paquete'), UnitKind.opaque);
      expect(unitKind('al gusto'), UnitKind.unquantified);
    });
  });

  group('lo que es cierto por definición', () {
    final c = UnitConverter.empty;

    double? to(double q, String from, String target) =>
        c.convert(q, from: from, to: target)?.value;

    test('cuchara, cucharadita y taza son medidas de volumen', () {
      expect(to(1, 'cucharada', 'ml'), 15);
      expect(to(1, 'cucharadita', 'ml'), 5);
      expect(to(1, 'taza', 'ml'), 250);
      expect(to(3, 'cucharadita', 'cucharada'), 1);
      expect(to(1, 'taza', 'cucharada'), closeTo(16.667, 0.001));
    });

    test('y no hace falta declarar nada para encadenarlas', () {
      expect(to(2, 'tazas', 'L'), 0.5);
      expect(to(4, 'cdas', 'dl'), closeTo(0.6, 0.0001));
    });

    test('peso imperial', () {
      expect(to(1, 'lb', 'g'), closeTo(453.592, 0.001));
      expect(to(16, 'oz', 'lb'), closeTo(1, 0.0001));
    });

    test('conteo', () {
      expect(to(1, 'docena', 'unidad'), 12);
      expect(to(6, 'unidades', 'docena'), 0.5);
    });

    test('nunca son estimadas', () {
      final amount = c.convert(1, from: 'taza', to: 'cucharada');
      expect(amount!.isEstimate, isFalse);
    });

    test('sin densidad no cruza volumen con peso', () {
      expect(to(1, 'taza', 'g'), isNull);
      expect(to(1, 'kg', 'ml'), isNull);
    });

    test('una cantidad "al gusto" no se convierte a nada', () {
      expect(to(1, 'al gusto', 'g'), isNull);
      expect(to(1, 'g', 'al gusto'), isNull);
      expect(isUnquantifiedUnit('cantidad necesaria'), isTrue);
      expect(isUnquantifiedUnit('pizca'), isFalse);
    });
  });

  group('medidas de volumen que no están definidas en ninguna parte', () {
    final c = UnitConverter.empty;

    test('se aceptan, porque las recetas las usan', () {
      expect(c.convert(1, from: 'vaso', to: 'ml')!.value, 200);
      expect(c.convert(2, from: 'pizca', to: 'cucharadita')!.value,
          closeTo(0.25, 0.0001));
    });

    test('pero se marcan como estimadas', () {
      expect(c.convert(1, from: 'vaso', to: 'ml')!.isEstimate, isTrue);
      expect(c.convert(1, from: 'copa', to: 'ml')!.isEstimate, isTrue);
    });
  });

  group('equivalencias declaradas', () {
    UnitConverter withRule(UnitRule rule) => UnitConverter([rule]);

    test('atada a un producto, solo vale para ese producto', () {
      final c = withRule(const UnitRule(
        productId: 'p1',
        fromQty: 1,
        fromUnit: 'cucharada',
        toQty: 12,
        toUnit: 'g',
      ));

      expect(
        c.convert(8, from: 'cucharada', to: 'g', productId: 'p1')!.value,
        96,
      );
      expect(c.convert(8, from: 'cucharada', to: 'g', productId: 'p2'), isNull);
      expect(c.convert(8, from: 'cucharada', to: 'g'), isNull);
    });

    test('atada a un nombre, vale para cualquiera que se llame así', () {
      final c = withRule(const UnitRule(
        ingredientKey: 'azucar',
        fromQty: 1,
        fromUnit: 'cucharada',
        toQty: 12,
        toUnit: 'g',
      ));

      expect(
        c.convert(1, from: 'cucharada', to: 'g', ingredientKey: 'Azúcar')!.value,
        12,
      );
      // Singular y plural, y sin acentos: es el mismo ingrediente.
      expect(
        c.convert(1, from: 'cucharada', to: 'g', ingredientKey: 'azucares'),
        isNotNull,
      );
      expect(
        c.convert(1, from: 'cucharada', to: 'g', ingredientKey: 'harina'),
        isNull,
      );
    });

    test('se usa en los dos sentidos', () {
      final c = withRule(const UnitRule(
        productId: 'p1',
        fromQty: 1,
        fromUnit: 'cucharada',
        toQty: 12,
        toUnit: 'g',
      ));

      expect(c.convert(96, from: 'g', to: 'cucharada', productId: 'p1')!.value,
          8);
    });

    test('se encadena con lo que ya se sabe', () {
      // Declarada en gramos, preguntada en kilos y en cucharaditas.
      final c = withRule(const UnitRule(
        productId: 'p1',
        fromQty: 1,
        fromUnit: 'taza',
        toQty: 200,
        toUnit: 'g',
      ));

      expect(c.convert(1, from: 'taza', to: 'kg', productId: 'p1')!.value, 0.2);
      expect(
        c.convert(1, from: 'cucharadita', to: 'g', productId: 'p1')!.value,
        closeTo(4, 0.0001),
      );
    });

    test('lo que declara el usuario no se marca como estimado', () {
      final c = withRule(const UnitRule(
        productId: 'p1',
        fromQty: 1,
        fromUnit: 'cucharada',
        toQty: 12,
        toUnit: 'g',
      ));

      expect(
        c.convert(1, from: 'cucharada', to: 'g', productId: 'p1')!.isEstimate,
        isFalse,
      );
    });
  });

  group('quién manda cuando hay más de una respuesta', () {
    const catalogo = UnitRule(
      ingredientKey: 'azucar',
      fromQty: 1,
      fromUnit: 'taza',
      toQty: 200,
      toUnit: 'g',
      isEstimate: true,
    );

    test('la del producto le gana a la del nombre', () {
      // Este azúcar del usuario es más denso que el de la tabla.
      const propia = UnitRule(
        productId: 'p1',
        fromQty: 1,
        fromUnit: 'taza',
        toQty: 240,
        toUnit: 'g',
      );
      final c = UnitConverter([catalogo, propia]);

      final amount = c.convert(1,
          from: 'taza', to: 'g', productId: 'p1', ingredientKey: 'azucar');
      expect(amount!.value, 240);
      expect(amount.isEstimate, isFalse);
    });

    test('sin la del producto, se usa la del nombre y se avisa', () {
      final c = UnitConverter([catalogo]);

      final amount = c.convert(1,
          from: 'taza', to: 'g', productId: 'p1', ingredientKey: 'azucar');
      expect(amount!.value, 200);
      expect(amount.isEstimate, isTrue);
    });

    test('entre nombres parciales gana el más específico', () {
      const leche = UnitRule(
        ingredientKey: 'leche',
        fromQty: 1,
        fromUnit: 'taza',
        toQty: 245,
        toUnit: 'g',
        isEstimate: true,
      );
      const cocoRule = UnitRule(
        ingredientKey: 'leche de coco',
        fromQty: 1,
        fromUnit: 'taza',
        toQty: 240,
        toUnit: 'g',
        isEstimate: true,
      );
      final c = UnitConverter([leche, cocoRule]);

      expect(
        c.convert(1, from: 'taza', to: 'g', ingredientKey: 'Leche de coco')!
            .value,
        240,
      );
      expect(
        c.convert(1, from: 'taza', to: 'g', ingredientKey: 'Leche entera')!
            .value,
        245,
      );
    });

    test('el nombre se cruza por palabras enteras, no por trozos', () {
      // "sal" y "salsa" pesan cosas muy distintas: cruzarlas por prefijo
      // descontaría el triple de lo que toca.
      const sal = UnitRule(
        ingredientKey: 'sal',
        fromQty: 1,
        fromUnit: 'taza',
        toQty: 290,
        toUnit: 'g',
        isEstimate: true,
      );
      final c = UnitConverter([sal]);

      expect(c.convert(1, from: 'taza', to: 'g', ingredientKey: 'Sal de mar')!
          .value, 290);
      expect(c.convert(1, from: 'taza', to: 'g', ingredientKey: 'Salsa inglesa'),
          isNull);
    });
  });

  group('el catálogo que trae la app', () {
    test('sabe lo que pesa una taza de lo habitual', () {
      final c = seededConverter;
      expect(
        c.convert(1, from: 'taza', to: 'g', ingredientKey: 'Harina')!.value,
        120,
      );
      expect(
        c.convert(1, from: 'taza', to: 'g', ingredientKey: 'Azúcar')!.value,
        200,
      );
      expect(
        c.convert(1, from: 'taza', to: 'g', ingredientKey: 'Arroz')!.value,
        185,
      );
    });

    test('y lo que pesa una pieza', () {
      final c = seededConverter;
      expect(
        c.convert(2, from: 'diente', to: 'g', ingredientKey: 'Ajo')!.value,
        10,
      );
      expect(
        c.convert(3, from: 'unidad', to: 'g', ingredientKey: 'Huevos')!.value,
        180,
      );
    });

    test('todo lo suyo va marcado como estimado', () {
      final amount = seededConverter.convert(1,
          from: 'cucharada', to: 'g', ingredientKey: 'Azúcar');
      expect(amount!.isEstimate, isTrue);
    });

    test('de lo que no conoce no se inventa nada', () {
      expect(
        seededConverter.convert(1,
            from: 'taza', to: 'g', ingredientKey: 'Azafrán'),
        isNull,
      );
    });
  });

  group('el caso que motivó todo esto', () {
    // Azúcar guardada en paquetes de 1 kg, receta que pide 8 cucharadas.
    final converter = seededConverter;
    const paqueteDeUnKilo = [
      UnitEdge(from: 'paquete', to: 'kg', factor: 1),
    ];

    test('8 cucharadas de azúcar son 96 g', () {
      expect(
        converter
            .convert(8,
                from: 'cucharada', to: 'g', ingredientKey: 'Azúcar')!
            .value,
        closeTo(96, 0.001),
      );
    });

    test('y eso es 0,096 paquetes: ya se puede descontar', () {
      final amount = converter.convert(
        8,
        from: 'cucharada',
        to: 'paquete',
        ingredientKey: 'Azúcar',
        extraEdges: paqueteDeUnKilo,
      );

      expect(amount, isNotNull);
      expect(amount!.value, closeTo(0.096, 0.0001));
      expect(amount.isEstimate, isTrue);
    });

    test('y al revés: 2 paquetes dan para 166 cucharadas', () {
      final amount = converter.convert(
        2,
        from: 'paquete',
        to: 'cucharada',
        ingredientKey: 'Azúcar',
        extraEdges: paqueteDeUnKilo,
      );

      expect(amount!.value, closeTo(166.667, 0.01));
    });
  });
}
