import 'package:flutter_test/flutter_test.dart';
import 'package:nakano_food/shared/utils/number_input.dart';

void main() {
  group('parseDecimal', () {
    test('acepta la coma del teclado en español', () {
      // El bug original: "2,5" devolvía null y se guardaba el fallback.
      expect(parseDecimal('2,5'), 2.5);
      expect(parseDecimal('12,50'), 12.5);
      expect(parseDecimal('0,5'), 0.5);
    });

    test('sigue aceptando el punto', () {
      expect(parseDecimal('2.5'), 2.5);
      expect(parseDecimal('3'), 3);
    });

    test('ignora espacios alrededor', () {
      expect(parseDecimal('  1,5  '), 1.5);
    });

    test('devuelve null en lugar de inventar un valor', () {
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('   '), isNull);
      expect(parseDecimal(null), isNull);
    });

    test('conserva el signo negativo para que se pueda rechazar', () {
      expect(parseDecimal('-5'), -5);
    });
  });

  group('parseInteger', () {
    test('lee enteros y tolera decimales escritos con coma', () {
      expect(parseInteger('4'), 4);
      expect(parseInteger('4,0'), 4);
      expect(parseInteger('3,6'), 4); // redondea
    });

    test('devuelve null si no hay número', () {
      expect(parseInteger('abc'), isNull);
    });
  });

  group('validatePositiveNumber', () {
    test('rechaza cero salvo que se permita explícitamente', () {
      expect(validatePositiveNumber('0'), isNotNull);
      expect(validatePositiveNumber('0', allowZero: true), isNull);
    });

    test('rechaza negativos y texto', () {
      expect(validatePositiveNumber('-3'), isNotNull);
      expect(validatePositiveNumber('abc'), isNotNull);
    });

    test('acepta decimales con coma', () {
      expect(validatePositiveNumber('2,5'), isNull);
    });

    test('un campo opcional vacío es válido', () {
      expect(validatePositiveNumber('', required: false), isNull);
      expect(validatePositiveNumber(''), isNotNull);
    });
  });

  group('normalizeName', () {
    test('cruza nombres con y sin acento', () {
      // Buscar "platano" debe encontrar "Plátano".
      expect(normalizeName('Plátano'), normalizeName('platano'));
      expect(normalizeName('Jamón'), normalizeName('jamon'));
      expect(normalizeName('Azúcar'), normalizeName('AZUCAR'));
      expect(normalizeName('Niño'), 'nino');
    });

    test('ignora espacios sobrantes, incluidos los internos', () {
      expect(normalizeName('  Leche  '), 'leche');
      expect(normalizeName('Arroz   integral'), 'arroz integral');
    });

    test('no cruza nombres que sí son distintos', () {
      expect(normalizeName('Leche'), isNot(normalizeName('Leche Entera')));
    });
  });
}
