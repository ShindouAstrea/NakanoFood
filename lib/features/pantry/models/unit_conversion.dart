import '../../../shared/utils/number_input.dart';
import '../../../shared/utils/unit_conversion.dart';

/// Una equivalencia guardada: lo que el usuario declara cuando la receta y la
/// despensa no hablan la misma unidad.
///
/// Es una [UnitRule] con identidad y sincronización. Las dos formas que puede
/// tomar se distinguen por cuál de las dos claves va rellena:
///
///   * [productId]: vale solo para ese producto de la despensa. Es lo que se
///     declara desde la hoja de descuento —"para MI azúcar, 1 cucharada son
///     12 g"— y le gana a todo lo demás.
///   * [ingredientKey]: vale para cualquier cosa que se llame así, exista o no
///     en la despensa. Sirve para lo que se repite entre productos.
///
/// Con las dos en null la equivalencia es general. Se admite porque hay
/// unidades que no dependen del ingrediente ("1 sobre = 10 g" en una casa
/// donde todos los sobres son iguales), pero no es lo que la app ofrece por
/// defecto: una equivalencia demasiado ancha se aplica donde no debe.
class UnitConversion extends UnitRule {
  final String id;
  final DateTime updatedAt;

  UnitConversion({
    required this.id,
    super.productId,
    super.ingredientKey,
    required super.fromQty,
    required super.fromUnit,
    required super.toQty,
    required super.toUnit,
    super.isEstimate,
    required this.updatedAt,
  });

  /// Cómo se lee: "1 cucharada = 12 g".
  String get label =>
      '${formatQuantity(fromQty)} $fromUnit = ${formatQuantity(toQty)} $toUnit';

  /// A qué se aplica, para poder distinguirlas en una lista.
  bool get isForProduct => productId != null;

  factory UnitConversion.fromMap(Map<String, dynamic> map) {
    return UnitConversion(
      id: map['id'] as String,
      productId: map['product_id'] as String?,
      ingredientKey: map['ingredient_key'] as String?,
      fromQty: (map['from_qty'] as num?)?.toDouble() ?? 0,
      fromUnit: map['from_unit'] as String? ?? '',
      toQty: (map['to_qty'] as num?)?.toDouble() ?? 0,
      toUnit: map['to_unit'] as String? ?? '',
      isEstimate: (map['is_estimate'] as int? ?? 0) == 1,
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'ingredient_key': ingredientKey,
      'from_qty': fromQty,
      'from_unit': fromUnit,
      'to_qty': toQty,
      'to_unit': toUnit,
      'is_estimate': isEstimate ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UnitConversion copyWith({
    double? fromQty,
    String? fromUnit,
    double? toQty,
    String? toUnit,
    bool? isEstimate,
    DateTime? updatedAt,
  }) {
    return UnitConversion(
      id: id,
      productId: productId,
      ingredientKey: ingredientKey,
      fromQty: fromQty ?? this.fromQty,
      fromUnit: fromUnit ?? this.fromUnit,
      toQty: toQty ?? this.toQty,
      toUnit: toUnit ?? this.toUnit,
      isEstimate: isEstimate ?? this.isEstimate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// True si las dos equivalencias dicen lo mismo sobre el mismo par de
  /// unidades, aunque estén escritas al revés o con otra cantidad base.
  ///
  /// Se usa para no acumular filas repetidas: declarar dos veces "1 cucharada
  /// de azúcar" debe corregir la anterior, no dejar dos y que el conversor
  /// elija una a suertes.
  bool sameSubjectAs(UnitConversion other) {
    if (productId != other.productId) return false;
    if (ingredientKey != null && other.ingredientKey != null) {
      if (ingredientKeyOf(ingredientKey!) !=
          ingredientKeyOf(other.ingredientKey!)) {
        return false;
      }
    } else if (ingredientKey != other.ingredientKey) {
      return false;
    }
    final a = {canonicalUnit(fromUnit), canonicalUnit(toUnit)};
    final b = {canonicalUnit(other.fromUnit), canonicalUnit(other.toUnit)};
    return a.length == b.length && a.containsAll(b);
  }
}
