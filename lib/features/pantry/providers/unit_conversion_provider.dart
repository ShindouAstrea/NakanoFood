import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/database/db_write_helper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/sync_service.dart';
import '../../../shared/utils/unit_conversion.dart';
import '../data/unit_conversion_seed.dart';
import '../models/unit_conversion.dart';

const _uuid = Uuid();

/// Las equivalencias de unidad que ha declarado el usuario.
final unitConversionsProvider =
    AsyncNotifierProvider<UnitConversionsNotifier, List<UnitConversion>>(
  UnitConversionsNotifier.new,
);

class UnitConversionsNotifier extends AsyncNotifier<List<UnitConversion>> {
  @override
  Future<List<UnitConversion>> build() {
    ref.watch(syncCompletionCountProvider);
    return _load();
  }

  String? get _uid => ref.read(currentUserIdProvider);

  Future<List<UnitConversion>> _load() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('unit_conversions');
    return maps.map(UnitConversion.fromMap).toList();
  }

  /// Guarda una equivalencia, sustituyendo la que ya dijera algo sobre el
  /// mismo par de unidades para el mismo sujeto.
  ///
  /// Corregir tiene que corregir: si declarar dos veces "1 cucharada de
  /// azúcar" dejara las dos filas, el conversor elegiría una de las dos por
  /// criterios que al usuario no le constan, y vería cambiar el descuento sin
  /// haber tocado nada.
  Future<UnitConversion> declare({
    String? productId,
    String? ingredientKey,
    required double fromQty,
    required String fromUnit,
    required double toQty,
    required String toUnit,
    bool isEstimate = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final conversion = UnitConversion(
      id: _uuid.v4(),
      productId: productId,
      ingredientKey:
          ingredientKey == null ? null : ingredientKeyOf(ingredientKey),
      fromQty: fromQty,
      fromUnit: canonicalUnit(fromUnit),
      toQty: toQty,
      toUnit: canonicalUnit(toUnit),
      isEstimate: isEstimate,
      updatedAt: DateTime.now(),
    );

    for (final existing in state.valueOrNull ?? const <UnitConversion>[]) {
      if (existing.sameSubjectAs(conversion)) {
        await _delete(db, existing.id);
      }
    }

    await db.insert('unit_conversions', withSync(conversion.toMap(), _uid));
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
    return conversion;
  }

  Future<void> remove(String id) async {
    final db = await DatabaseHelper.instance.database;
    await _delete(db, id);
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> _delete(Database db, String id) async {
    await ref.read(syncServiceProvider).recordDeletion('unit_conversions', id);
    await db.delete('unit_conversions', where: 'id = ?', whereArgs: [id]);
  }
}

/// El conversor que debe usar toda la app.
///
/// Es el catálogo de referencia más lo que el usuario haya declarado, y en ese
/// orden importa quién va después: las reglas del usuario entran con más
/// prioridad y le ganan al catálogo cuando hablan del mismo par de unidades.
///
/// Mientras las equivalencias se están cargando devuelve el catálogo solo. Es
/// deliberado: bloquear la despensa entera esperando una tabla que casi
/// siempre está vacía sería peor que empezar sin las correcciones del usuario
/// y aplicarlas medio segundo después, cuando el provider se reconstruya.
final unitConverterProvider = Provider<UnitConverter>((ref) {
  final declared = ref.watch(unitConversionsProvider).valueOrNull;
  if (declared == null || declared.isEmpty) return seededConverter;
  return UnitConverter([...seedUnitRules, ...declared]);
});

/// Las equivalencias que afectan a un producto: las suyas propias y las que se
/// declararon para cualquier cosa que se llame así.
///
/// Las dos, y no solo las suyas: quien declara "vale para cualquier azúcar"
/// desde la hoja de descuento tiene que poder encontrarla y borrarla después
/// desde su azúcar, que es donde va a ir a buscarla. Una fila que actúa y no
/// se ve es una fila que el usuario no puede corregir.
///
/// No incluye el catálogo de la app: eso no es suyo y no se borra, se pisa.
final productConversionsProvider =
    Provider.family<List<UnitConversion>, ({String id, String name})>(
        (ref, product) {
  final all = ref.watch(unitConversionsProvider).valueOrNull ??
      const <UnitConversion>[];
  final key = ingredientKeyOf(product.name);

  return all.where((c) {
    if (c.productId != null) return c.productId == product.id;
    if (c.ingredientKey != null) return c.ingredientKey == key;
    return false;
  }).toList()
    ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
});
