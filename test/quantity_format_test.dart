import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/shared/utils/number_input.dart';

/// Redondeo y escritura de cantidades.
///
/// Sin redondear, descontar de la despensa deja restos binarios que quedan
/// guardados y escritos en pantalla: nadie tiene 2,8000000000000003 kg.
void main() {
  group('roundQuantity', () {
    test('limpia el resto de la resta en coma flotante', () {
      expect(roundQuantity(3 - 0.2), 2.8);
      expect(roundQuantity(0.3 - 0.2), 0.1);
    });

    test('deja intacto lo que ya está redondo', () {
      expect(roundQuantity(2.5), 2.5);
      expect(roundQuantity(0), 0);
    });

    test('conserva el milésimo, que es el gramo dentro del kilo', () {
      expect(roundQuantity(0.001), 0.001);
      expect(roundQuantity(0.0004), 0);
    });

    test('no revienta con lo que no es un número', () {
      expect(roundQuantity(double.infinity), 0);
      expect(roundQuantity(double.nan), 0);
      expect(roundQuantity(1e20), 1e12);
    });
  });

  group('formatQuantity', () {
    test('sin decimales cuando la cantidad es entera', () {
      expect(formatQuantity(3), '3');
      expect(formatQuantity(1500), '1500');
    });

    test('con coma y sin ceros de relleno', () {
      expect(formatQuantity(0.5), '0,5');
      expect(formatQuantity(0.25), '0,25');
      expect(formatQuantity(2.8000000000000003), '2,8');
    });

    test('lo que escribe se puede volver a leer', () {
      expect(parseDecimal(formatQuantity(0.25)), 0.25);
    });
  });
}
