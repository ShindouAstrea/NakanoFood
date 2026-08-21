import '../models/recipe.dart';
import '../../pantry/models/product.dart';
import '../../../shared/utils/number_input.dart';

/// Cruce entre los ingredientes de una receta y los productos de la despensa.
///
/// Vive aparte porque lo usan tanto el detalle de una receta como la pantalla
/// "¿Qué puedo cocinar?", y las dos deben responder exactamente lo mismo.
class PantryIndex {
  final Map<String, Product> _byId;
  final Map<String, Product> _byName;
  final Map<String, Product> _bySingular;

  const PantryIndex._(this._byId, this._byName, this._bySingular);

  factory PantryIndex.from(List<Product> products) {
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
    return PantryIndex._(byId, byName, bySingular);
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
  double? availableFor(RecipeIngredient ingredient) {
    final product = matchFor(ingredient);
    if (product == null) return null;
    return product.convertToRecipeUnit(
        product.currentQuantity, ingredient.unit);
  }

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
