import '../../../shared/utils/number_input.dart';
import '../../../shared/utils/unit_conversion.dart';
import '../../pantry/models/product.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/providers/pantry_index.dart';
import '../models/meal_plan.dart';

/// Un producto que el plan de comidas va a ocupar.
class PlannedNeed {
  final Product product;

  /// Lo que piden entre todas las recetas planificadas, en unidades del
  /// producto: la receta habla de gramos y la despensa de kilos.
  final double needed;

  /// En cuántas comidas del plan aparece. Es lo que justifica la cantidad
  /// cuando el número sorprende: 3 kg de harina se entienden si son 6 cenas.
  final int meals;

  const PlannedNeed({
    required this.product,
    required this.needed,
    required this.meals,
  });

  double get available => product.currentQuantity;

  /// Lo que falta comprar. Cero cuando la despensa ya alcanza.
  double get missing {
    final diff = roundQuantity(needed - available);
    return diff > 0 ? diff : 0;
  }

  bool get isCovered => missing <= 0;
}

/// Un ingrediente del plan que no se puede convertir en algo que comprar.
///
/// Se distinguen los dos motivos porque se arreglan en sitios distintos: uno
/// creando el producto en la despensa, el otro declarando su equivalencia por
/// unidad. Callarlos haría que la lista pareciera completa cuando no lo está.
class UnplannedIngredient {
  final String name;

  /// El producto de la despensa con el que sí cruzó. Null cuando el problema
  /// es que no existe; cuando existe, va aquí para que la pantalla pueda
  /// ofrecer declarar la equivalencia sin ir a buscarlo otra vez.
  final Product? product;

  /// Unidad en que lo pide la receta.
  final String recipeUnit;

  const UnplannedIngredient({
    required this.name,
    required this.product,
    required this.recipeUnit,
  });

  bool get isMissingFromPantry => product == null;

  /// Unidad del producto en la despensa. Null si el producto no existe.
  String? get productUnit => product?.unit;

  /// La receta no dice una cantidad ("al gusto"): no hay nada que comprar por
  /// ella, y no es un dato que al usuario le falte por dar.
  bool get isUnquantified => isUnquantifiedUnit(recipeUnit);
}

/// Lo que hay que comprar para cocinar lo planificado en un rango de fechas.
class MealPlanNeeds {
  final List<PlannedNeed> needs;
  final List<UnplannedIngredient> skipped;

  /// Comidas del rango que tienen receta y sí se pudieron calcular.
  final int mealsPlanned;

  /// Comidas escritas a mano, o cuya receta ya no existe: no hay ingredientes
  /// que sumar, así que el plan no puede pedir nada por ellas.
  final int mealsWithoutRecipe;

  const MealPlanNeeds({
    required this.needs,
    required this.skipped,
    required this.mealsPlanned,
    required this.mealsWithoutRecipe,
  });

  factory MealPlanNeeds.build({
    required List<MealPlan> plans,
    required List<Recipe> recipes,
    required List<Product> products,
    required DateTime from,
    required DateTime to,
    UnitConverter? converter,
  }) {
    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day);
    final byRecipeId = {for (final recipe in recipes) recipe.id: recipe};
    // El mismo cruce que usan el detalle de la receta y el descuento al
    // cocinar: lo que la app dice que falta tiene que salir de un solo sitio.
    final pantry = PantryIndex.from(products, converter: converter);

    final neededByProduct = <String, double>{};
    final mealsByProduct = <String, int>{};
    final productsById = <String, Product>{};
    final skipped = <String, UnplannedIngredient>{};
    var mealsPlanned = 0;
    var mealsWithoutRecipe = 0;

    for (final plan in plans) {
      final day = DateTime(plan.date.year, plan.date.month, plan.date.day);
      if (day.isBefore(fromDay) || day.isAfter(toDay)) continue;

      for (final item in plan.items) {
        final recipe =
            item.recipeId == null ? null : byRecipeId[item.recipeId];
        // Sin receta detrás no hay ingredientes que sumar. Vale tanto para la
        // comida escrita a mano como para la receta que se borró después.
        if (recipe == null) {
          mealsWithoutRecipe++;
          continue;
        }
        mealsPlanned++;

        // Una receta que ocupa harina dos veces es una sola comida para esa
        // harina, aunque sume dos cantidades.
        final countedHere = <String>{};

        for (final ingredient in recipe.ingredients) {
          final product = pantry.matchFor(ingredient);
          if (product == null) {
            skipped.putIfAbsent(
              normalizeName(ingredient.productName),
              () => UnplannedIngredient(
                name: ingredient.productName,
                product: null,
                recipeUnit: ingredient.unit,
              ),
            );
            continue;
          }

          final inProductUnits = product.convertFromRecipeUnit(
              ingredient.quantity, ingredient.unit,
              converter: pantry.converter);
          if (inProductUnits == null) {
            skipped.putIfAbsent(
              '${product.id}|${ingredient.unit}',
              () => UnplannedIngredient(
                name: product.name,
                product: product,
                recipeUnit: ingredient.unit,
              ),
            );
            continue;
          }

          productsById[product.id] = product;
          neededByProduct.update(
            product.id,
            (previous) => previous + inProductUnits,
            ifAbsent: () => inProductUnits,
          );
          if (countedHere.add(product.id)) {
            mealsByProduct.update(product.id, (n) => n + 1, ifAbsent: () => 1);
          }
        }
      }
    }

    final needs = [
      for (final entry in neededByProduct.entries)
        PlannedNeed(
          product: productsById[entry.key]!,
          needed: roundQuantity(entry.value),
          meals: mealsByProduct[entry.key] ?? 0,
        ),
    ]..sort((a, b) {
        // Primero lo que hay que comprar: es a lo que se viene a esta pantalla.
        if (a.isCovered != b.isCovered) return a.isCovered ? 1 : -1;
        return a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase());
      });

    return MealPlanNeeds(
      needs: needs,
      skipped: skipped.values.toList(),
      mealsPlanned: mealsPlanned,
      mealsWithoutRecipe: mealsWithoutRecipe,
    );
  }

  List<PlannedNeed> get toBuy => needs.where((n) => !n.isCovered).toList();

  List<PlannedNeed> get covered => needs.where((n) => n.isCovered).toList();

  bool get hasSomethingToBuy => needs.any((n) => !n.isCovered);

  /// No hay nada planificado con receta en el rango.
  bool get hasNothingPlanned => mealsPlanned == 0;
}

/// Cuánto comprar de cada producto, listo para armar la lista de compras.
///
/// Solo entra lo que falta: lo que la despensa ya cubre no se compra de nuevo.
Map<String, double> shoppingQuantities(Iterable<PlannedNeed> needs) {
  final quantities = <String, double>{};
  for (final need in needs) {
    if (need.missing <= 0) continue;
    quantities[need.product.id] = need.missing;
  }
  return quantities;
}
