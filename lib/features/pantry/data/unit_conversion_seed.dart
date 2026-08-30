/// Catálogo de referencia: cuánto pesa lo que una receta mide en volumen.
///
/// Una taza de harina y una taza de azúcar ocupan lo mismo y pesan muy
/// distinto, así que ningún cálculo puede ir de "8 cucharadas" a "gramos" sin
/// saber de qué ingrediente se habla. Esto es lo que la app sabe de fábrica
/// para no obligar al usuario a declarar lo evidente antes de poder descontar
/// nada.
///
/// Vive en código y no en la base de datos a propósito:
///
///   * No ensucia la despensa del usuario con sesenta filas que él no escribió
///     ni tiene por qué ver, ni las sube a Supabase en cada sync.
///   * Corregir un valor es una versión de la app, no una migración.
///   * Y sobre todo: cualquier cosa que el usuario declare —para su producto o
///     para ese nombre de ingrediente— le gana a esto, porque entra con más
///     prioridad. El catálogo es el último recurso, nunca la última palabra.
///
/// Todas van marcadas como estimadas: son valores de referencia de tablas de
/// cocina, no la harina concreta que hay en esa despensa. Esa marca viaja con
/// el número hasta la pantalla, que escribe "≈".
library;

import '../../../shared/utils/unit_conversion.dart';

/// Peso de una taza (250 ml) del ingrediente, en gramos.
///
/// Se declara por taza y no por cucharada porque es como vienen las tablas de
/// cocina; el resto lo deduce el conversor, que sabe que una cucharada es la
/// decimosexta parte y media taza la mitad.
const _gramsPerCup = <String, double>{
  // Azúcares y endulzantes
  'azucar': 200,
  'azucar rubia': 200,
  'azucar morena': 220,
  'azucar flor': 120,
  'azucar impalpable': 120,
  'miel': 340,
  'manjar': 300,
  'dulce de leche': 300,
  'mermelada': 320,
  'leche condensada': 306,
  // Harinas y secos de repostería
  'harina': 120,
  'harina integral': 120,
  'maicena': 120,
  'almidon de maiz': 120,
  'chuno': 120,
  'semola': 165,
  'polvos de hornear': 200,
  'polvo de hornear': 200,
  'bicarbonato': 220,
  'levadura': 150,
  'cacao': 85,
  'cocoa': 85,
  'pan rallado': 110,
  'coco rallado': 80,
  'gelatina': 150,
  // Granos, legumbres y pastas
  'arroz': 185,
  'avena': 90,
  'quinoa': 170,
  'lenteja': 190,
  'poroto': 190,
  'frijol': 190,
  'garbanzo': 200,
  'polenta': 160,
  'couscous': 175,
  'fideo': 100,
  'pasta': 100,
  // Líquidos y grasas
  'agua': 250,
  'leche': 245,
  'leche evaporada': 250,
  'leche de coco': 240,
  'crema': 240,
  'yogurt': 245,
  'aceite': 218,
  'mantequilla': 227,
  'margarina': 227,
  'manteca': 205,
  'vinagre': 240,
  'vino': 240,
  'cerveza': 240,
  'jugo': 245,
  'caldo': 240,
  // Salsas y condimentos
  'sal': 290,
  'salsa de tomate': 245,
  'pure de tomate': 250,
  'ketchup': 270,
  'mayonesa': 220,
  'mostaza': 250,
  'salsa de soya': 255,
  'salsa de soja': 255,
  // Frutos secos y semillas
  'nuez': 120,
  'almendra': 140,
  'mani': 145,
  'pasa': 145,
  'sesamo': 145,
  'chia': 170,
  'linaza': 170,
  'chocolate': 170,
  // Otros de despensa
  'queso rallado': 100,
  'cafe': 85,
};

/// Peso de una pieza, en gramos: lo que hace falta cuando la receta cuenta
/// unidades y la despensa pesa kilos ("2 dientes de ajo" contra "1 kg").
///
/// Son tamaños medianos de supermercado. Igual que arriba, cualquier cosa que
/// el usuario declare para su producto le gana.
const _gramsPerPiece = <String, ({String unit, double grams})>{
  'ajo': (unit: 'diente', grams: 5),
  'huevo': (unit: 'unidad', grams: 60),
  'cebolla': (unit: 'unidad', grams: 150),
  'tomate': (unit: 'unidad', grams: 120),
  'papa': (unit: 'unidad', grams: 150),
  'zanahoria': (unit: 'unidad', grams: 70),
  'limon': (unit: 'unidad', grams: 100),
  'naranja': (unit: 'unidad', grams: 180),
  'manzana': (unit: 'unidad', grams: 180),
  'platano': (unit: 'unidad', grams: 120),
  'palta': (unit: 'unidad', grams: 200),
  'pimenton': (unit: 'unidad', grams: 150),
  'zapallo italiano': (unit: 'unidad', grams: 200),
  'berenjena': (unit: 'unidad', grams: 250),
  'pepino': (unit: 'unidad', grams: 200),
  'choclo': (unit: 'unidad', grams: 200),
  'pan de molde': (unit: 'rebanada', grams: 28),
  'pan': (unit: 'unidad', grams: 80),
  'tortilla': (unit: 'unidad', grams: 30),
  'apio': (unit: 'tallo', grams: 40),
  'puerro': (unit: 'unidad', grams: 90),
  'champinon': (unit: 'unidad', grams: 20),
  'jamon': (unit: 'rebanada', grams: 20),
  'queso': (unit: 'rebanada', grams: 20),
  'tocino': (unit: 'rebanada', grams: 15),
};

/// El catálogo entero como reglas de conversión.
final List<UnitRule> seedUnitRules = [
  for (final entry in _gramsPerCup.entries)
    UnitRule(
      ingredientKey: entry.key,
      fromQty: 1,
      fromUnit: 'taza',
      toQty: entry.value,
      toUnit: 'g',
      isEstimate: true,
    ),
  for (final entry in _gramsPerPiece.entries)
    UnitRule(
      ingredientKey: entry.key,
      fromQty: 1,
      fromUnit: entry.value.unit,
      toQty: entry.value.grams,
      toUnit: 'g',
      isEstimate: true,
    ),
];

/// El conversor con solo el catálogo, sin nada declarado por el usuario.
///
/// Es el que usan los modelos cuando nadie les pasa uno: un sitio del que se
/// nos olvide pasar el conversor pierde las equivalencias del usuario, pero no
/// se queda ciego del todo. Lo contrario —que el descuento dejara de funcionar
/// en una pantalla y nadie se enterara— es un fallo mucho más silencioso.
final UnitConverter seededConverter = UnitConverter(seedUnitRules);
