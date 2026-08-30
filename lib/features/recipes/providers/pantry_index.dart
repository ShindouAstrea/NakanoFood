import '../models/recipe.dart';
import '../../pantry/data/unit_conversion_seed.dart';
import '../../pantry/models/product.dart';
import '../../../shared/utils/number_input.dart';
import '../../../shared/utils/unit_conversion.dart';

/// Cruce entre los ingredientes de una receta y los productos de la despensa.
///
/// Vive aparte porque lo usan tanto el detalle de una receta como la pantalla
/// "¿Qué puedo cocinar?", y las dos deben responder exactamente lo mismo.
class PantryIndex {
  final Map<String, Product> _byId;
  final Map<String, Product> _byName;
  final Map<String, Product> _bySingular;

  /// Las equivalencias de unidad con las que se cruza la despensa.
  ///
  /// Va en el índice y no como argumento de cada llamada porque las tres
  /// pantallas que preguntan —el detalle de la receta, "¿Qué puedo cocinar?" y
  /// el descuento al cocinar— tienen que responder lo mismo, y con un conversor
  /// distinto cada una responderían cosas distintas.
  final UnitConverter converter;

  const PantryIndex._(
      this._byId, this._byName, this._bySingular, this.converter);

  factory PantryIndex.from(
    List<Product> products, {
    UnitConverter? converter,
  }) {
    final byId = {for (final p in products) p.id: p};
    // Con nombres normalizados repetidos gana el primero: cruzar con uno de
    // ellos es preferible a no cruzar nada.
    final byName = <String, Product>{};
    final bySingular = <String, Product>{};
    for (final p in products) {
      final name = normalizeName(p.name);
      byName.putIfAbsent(name, () => p);
      bySingular.putIfAbsent(_withoutPlural(name), () => p);
    }
    return PantryIndex._(
        byId, byName, bySingular, converter ?? seededConverter);
  }

  /// Quita la ese final para poder comparar singular con plural.
  ///
  /// Se quita una sola letra y solo en nombres de más de tres: así "papas" y
  /// "papa" se cruzan, pero "gas" sigue siendo "gas". No se toca la
  /// terminación "-es" porque partiría "tomates" en "tomat", que ya no se
  /// parece a "tomate".
  static String _withoutPlural(String normalized) =>
      normalized.length > 3 && normalized.endsWith('s')
          ? normalized.substring(0, normalized.length - 1)
          : normalized;

  /// Producto correspondiente al ingrediente, o null si no hay ninguno.
  ///
  /// El `productId` solo se rellena si se eligió una opción del autocompletado
  /// al escribir la receta, así que las precargadas, las generadas con IA y las
  /// importadas por código llegan sin él. El respaldo por nombre normalizado
  /// —sin mayúsculas, acentos ni espacios sobrantes— las recupera.
  ///
  /// Y si tampoco así, se prueba sin la ese final: la receta dice "2 papas" y
  /// la despensa guarda "Papa". Nadie escribe las dos igual, y no cruzarlas
  /// significa no descontar y mandar a comprar lo que ya está en casa.
  Product? matchFor(RecipeIngredient ingredient) {
    final byId =
        ingredient.productId != null ? _byId[ingredient.productId] : null;
    if (byId != null) return byId;

    final name = normalizeName(ingredient.productName);
    return _byName[name] ?? _bySingular[_withoutPlural(name)];
  }

  /// Cuánto hay en la despensa, expresado en la unidad que pide la receta.
  ///
  /// Null cuando no se puede afirmar: no hay producto, o las unidades no son
  /// convertibles y el producto no declara su equivalencia.
  /// Trae también la marca de si el número se apoya en una equivalencia
  /// estimada, para poder escribir "≈ 2 tazas" en vez de "2 tazas".
  UnitAmount? availableAmountFor(RecipeIngredient ingredient) {
    final product = matchFor(ingredient);
    if (product == null) return null;
    return product.amountInRecipeUnit(
      product.currentQuantity,
      ingredient.unit,
      converter: converter,
    );
  }

  /// [availableAmountFor] cuando solo interesa el número.
  double? availableFor(RecipeIngredient ingredient) =>
      availableAmountFor(ingredient)?.value;

  /// True/false si se puede afirmar, null si no hay información suficiente.
  ///
  /// El tercer estado es deliberado: decir "te falta" cuando en realidad no se
  /// sabe empuja al usuario a comprar cosas que ya tiene.
  bool? isAvailable(RecipeIngredient ingredient, {double multiplier = 1}) {
    final available = availableFor(ingredient);
    if (available == null) return null;
    return available >= ingredient.quantity * multiplier;
  }
}
