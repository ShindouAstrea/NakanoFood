import '../../../shared/utils/number_input.dart';
import '../../../shared/utils/unit_conversion.dart';
import '../../pantry/data/unit_conversion_seed.dart';
import '../../pantry/models/product.dart';
import '../models/recipe.dart';
import 'pantry_index.dart';

/// Qué se puede descontar de la despensa al cocinar, y qué no.
///
/// Los dos estados de "no se puede" están separados a propósito: uno se
/// arregla creando el producto y el otro declarando su equivalencia por
/// unidad, y el usuario no puede adivinar cuál le toca si los dos dicen
/// "no se descontó".
enum DeductionStatus {
  /// Hay producto y la equivalencia consta: se descuenta entero.
  ok,

  /// Se puede descontar, pero la despensa tiene menos de lo que pide la
  /// receta. Queda en cero, nunca en negativo.
  partial,

  /// El ingrediente no cruza con ningún producto de la despensa.
  unmatched,

  /// Hay producto, pero no consta a cuánto equivale su unidad en la de la
  /// receta: descontar obligaría a inventarse el factor.
  unconvertible,

  /// La receta no dice cuánto: "sal, al gusto". No es que falte información
  /// que el usuario pueda dar —no hay cantidad—, así que ofrecerle arreglarlo
  /// sería mandarlo a una tarea que no existe.
  unquantified,
}

/// Un ingrediente de la receta frente al producto de la despensa que le toca.
class DeductionLine {
  final RecipeIngredient ingredient;

  /// Producto que se descontaría, si se encontró alguno.
  final Product? product;

  /// Lo que pide la receta, ya con el multiplicador de porciones aplicado y
  /// en la unidad en que está escrita la receta.
  final double recipeAmount;

  /// [recipeAmount] pasado a unidades del producto, que es como se guarda el
  /// stock. Null cuando la equivalencia no se puede afirmar.
  final double? productAmount;

  final DeductionStatus status;

  /// La conversión se apoyó en una equivalencia de referencia (cuánto pesa una
  /// taza de harina) y no en algo que conste de este producto.
  ///
  /// No impide descontar —negarse a mover el stock por eso sería peor—, pero
  /// se dice: el usuario tiene que poder distinguir el número que sale de su
  /// propia ficha del que sale de una tabla de cocina.
  final bool isEstimate;

  /// Las equivalencias con las que se resolvió, para poder rehacer el cálculo
  /// cuando el usuario corrige la cantidad sin salir de la hoja.
  final UnitConverter converter;

  const DeductionLine._({
    required this.ingredient,
    required this.product,
    required this.recipeAmount,
    required this.productAmount,
    required this.status,
    required this.isEstimate,
    required this.converter,
  });

  /// Resuelve la conversión y el estado de una línea.
  factory DeductionLine.resolve({
    required RecipeIngredient ingredient,
    required Product? product,
    required double recipeAmount,
    UnitConverter? converter,
  }) {
    final amount = roundQuantity(recipeAmount);
    final rules = converter ?? seededConverter;

    DeductionLine skip(DeductionStatus status) => DeductionLine._(
          ingredient: ingredient,
          product: product,
          recipeAmount: amount,
          productAmount: null,
          status: status,
          isEstimate: false,
          converter: rules,
        );

    // Se comprueba antes que el producto porque "sal, al gusto" no se arregla
    // creando la sal: no hay nada que descontar aunque esté en la despensa.
    if (isUnquantifiedUnit(ingredient.unit)) {
      return skip(DeductionStatus.unquantified);
    }
    if (product == null) return skip(DeductionStatus.unmatched);

    final inProductUnits =
        product.amountInProductUnit(amount, ingredient.unit, converter: rules);
    if (inProductUnits == null) return skip(DeductionStatus.unconvertible);

    final toDeduct = roundQuantity(inProductUnits.value);
    return DeductionLine._(
      ingredient: ingredient,
      product: product,
      recipeAmount: amount,
      productAmount: toDeduct,
      status: toDeduct > product.currentQuantity
          ? DeductionStatus.partial
          : DeductionStatus.ok,
      isEstimate: inProductUnits.isEstimate,
      converter: rules,
    );
  }

  /// La misma línea con otra cantidad: el usuario puede corregir en la hoja de
  /// confirmación lo que realmente ocupó, y el estado se recalcula con ella.
  DeductionLine withRecipeAmount(double amount) => DeductionLine.resolve(
        ingredient: ingredient,
        product: product,
        recipeAmount: amount,
        converter: converter,
      );

  bool get isDeductible => productAmount != null;

  /// Lo que de verdad se puede restar: nunca más de lo que hay guardado.
  double get effectiveAmount {
    final amount = productAmount;
    if (amount == null || product == null || amount <= 0) return 0;
    return amount > product!.currentQuantity ? product!.currentQuantity : amount;
  }

  /// Cuánto queda en la despensa después de descontar, en unidades del
  /// producto. Null si no hay nada que descontar.
  double? get remainingAfter {
    if (!isDeductible) return null;
    return roundQuantity(product!.currentQuantity - effectiveAmount);
  }
}

/// El plan completo de descuento de una receta.
class CookDeduction {
  final List<DeductionLine> lines;

  const CookDeduction(this.lines);

  factory CookDeduction.build({
    required Recipe recipe,
    required List<Product> products,
    double multiplier = 1,
    UnitConverter? converter,
  }) {
    // El mismo cruce que usan el detalle y "¿Qué puedo cocinar?": lo que la
    // app dice que tienes y lo que descuenta tienen que salir de un solo sitio.
    final pantry = PantryIndex.from(products, converter: converter);
    return CookDeduction([
      for (final ingredient in recipe.ingredients)
        DeductionLine.resolve(
          ingredient: ingredient,
          product: pantry.matchFor(ingredient),
          recipeAmount: ingredient.quantity * multiplier,
          converter: pantry.converter,
        ),
    ]);
  }

  List<DeductionLine> get deductible =>
      lines.where((l) => l.isDeductible).toList();

  List<DeductionLine> get skipped =>
      lines.where((l) => !l.isDeductible).toList();

  bool get hasDeductible => lines.any((l) => l.isDeductible);
}

/// Suma por producto lo que hay que restar de la despensa.
///
/// Se agrupa porque un mismo producto puede aparecer en dos ingredientes —la
/// harina de la masa y la del enharinado—: escribiendo línea por línea, la
/// segunda pisaría a la primera y se descontaría de menos.
///
/// El tope contra el stock disponible se vuelve a aplicar al guardar: aquí
/// cada línea se limita por separado, y dos líneas del mismo producto podrían
/// sumar más de lo que hay.
Map<String, double> totalsByProduct(Iterable<DeductionLine> lines) {
  final totals = <String, double>{};
  for (final line in lines) {
    final product = line.product;
    if (product == null || line.effectiveAmount <= 0) continue;
    totals.update(
      product.id,
      (previous) => roundQuantity(previous + line.effectiveAmount),
      ifAbsent: () => line.effectiveAmount,
    );
  }
  return totals;
}
