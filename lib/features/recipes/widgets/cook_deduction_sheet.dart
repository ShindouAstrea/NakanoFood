import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/number_input.dart';
import '../../pantry/models/product.dart';
import '../../pantry/providers/pantry_provider.dart';
import '../../pantry/providers/unit_conversion_provider.dart';
import '../../pantry/widgets/product_picker.dart';
import '../../pantry/widgets/quick_add_product.dart';
import '../../pantry/widgets/unit_equivalence_sheet.dart';
import '../models/recipe.dart';
import '../providers/cook_deduction.dart';
import '../providers/recipe_provider.dart';

/// Da una receta por cocinada: la registra y, si sus ingredientes cruzan con
/// la despensa, ofrece descontarlos.
///
/// Vive aparte de la pantalla de detalle porque son dos los sitios que dan una
/// receta por cocinada —el botón del detalle y el "¡Listo!" del modo cocina— y
/// los dos tienen que hacer exactamente lo mismo.
Future<void> confirmCooked(
  BuildContext context,
  WidgetRef ref, {
  required Recipe recipe,
  double multiplier = 1,
}) async {
  final products = await ref.read(productsProvider.future);
  final plan = CookDeduction.build(
    recipe: recipe,
    products: products,
    multiplier: multiplier,
    converter: ref.read(unitConverterProvider),
  );

  if (!context.mounted) return;

  // Una receta sin ingredientes no tiene nada que decir: se registra y ya.
  // Pero si los tiene y ninguno se pudo cruzar con la despensa, la hoja se
  // abre igual: quien marca "la cociné" y ve que su stock no se movió merece
  // saber por qué —y poder arreglarlo ahí mismo— en vez de quedarse pensando
  // que la app no funciona.
  if (!plan.hasDeductible && plan.skipped.isEmpty) {
    await _register(context, ref, recipe: recipe, deltas: const {});
    return;
  }

  final deltas = await showModalBottomSheet<Map<String, double>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CookDeductionSheet(recipe: recipe, multiplier: multiplier),
  );

  // Cerrar la hoja deslizándola no registra nada: se pudo abrir por ver qué
  // decía, y marcar la receta a cambio sería una sorpresa.
  if (deltas == null || !context.mounted) return;

  await _register(context, ref, recipe: recipe, deltas: deltas);
}

Future<void> _register(
  BuildContext context,
  WidgetRef ref, {
  required Recipe recipe,
  required Map<String, double> deltas,
}) async {
  // Los notifiers se toman antes de escribir nada: si la pantalla se cierra
  // mientras se guarda —el modo cocina se cierra justo después—, leerlos
  // después del await sería sobre un ref ya desechado.
  final pantry = ref.read(productsProvider.notifier);
  final recipes = ref.read(recipesProvider.notifier);

  if (deltas.isNotEmpty) {
    await pantry.consumeQuantities(deltas);
  }
  await recipes.markCooked(recipe.id);

  if (!context.mounted) return;
  // El detalle muestra disponibilidad y costo calculados sobre el stock, así
  // que tiene que releerlos después de haberlo movido.
  ref.invalidate(recipeWithAvailabilityProvider(recipe.id));
  final count = deltas.length;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        count == 0
            ? '¡Registrado! La receta fue marcada como cocinada hoy.'
            : 'Cocinada y descontada de la despensa '
                '($count ${count == 1 ? 'producto' : 'productos'}).',
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// La hoja de confirmación del descuento.
///
/// Se abre desde [confirmCooked], que es por donde entra la app. Queda pública
/// para poder montarla en un test de widget.
class CookDeductionSheet extends ConsumerStatefulWidget {
  final Recipe recipe;
  final double multiplier;

  const CookDeductionSheet({
    super.key,
    required this.recipe,
    this.multiplier = 1,
  });

  @override
  ConsumerState<CookDeductionSheet> createState() => _CookDeductionSheetState();
}

class _CookDeductionSheetState extends ConsumerState<CookDeductionSheet> {
  /// Copia local de la receta. Vincular un ingrediente lo aplica aquí además
  /// de guardarlo, para que la fila salte a "se descuenta" sin cerrar la hoja.
  late Recipe _recipe;

  /// Ingredientes que el usuario destildó.
  final _excluded = <String>{};

  /// Cantidades corregidas a mano, por ingrediente. Se guardan aparte de las
  /// líneas porque estas se recalculan cada vez que algo cambia.
  final _edited = <String, double>{};

  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(DeductionLine line) =>
      _controllers.putIfAbsent(
        line.ingredient.id,
        () => TextEditingController(text: formatQuantity(line.recipeAmount)),
      );

  /// El plan recalculado, con las correcciones del usuario aplicadas encima.
  CookDeduction _planFrom(List<Product> products) {
    final base = CookDeduction.build(
      recipe: _recipe,
      products: products,
      multiplier: widget.multiplier,
      converter: ref.watch(unitConverterProvider),
    );
    return CookDeduction([
      for (final line in base.lines)
        _edited.containsKey(line.ingredient.id)
            ? line.withRecipeAmount(_edited[line.ingredient.id]!)
            : line,
    ]);
  }

  Map<String, double> _deltas(CookDeduction plan) => totalsByProduct([
        for (final line in plan.deductible)
          if (!_excluded.contains(line.ingredient.id)) line,
      ]);

  void _onAmountChanged(DeductionLine line, String text) {
    // Un campo a medio escribir no debe borrar la línea: mientras no haya un
    // número legible se deja en cero, que es "no descontar esto".
    final parsed = parseDecimal(text) ?? 0;
    setState(() {
      _edited[line.ingredient.id] = parsed < 0 ? 0 : parsed;
    });
  }

  Future<void> _link(DeductionLine line, List<Product> products) async {
    final product = await pickPantryProduct(
      context,
      products: products,
      initialQuery: line.ingredient.productName,
      // Vincular no sirve de nada si el producto todavía no existe, que es
      // lo más probable justo aquí: se puede crear sin salir del selector.
      onCreate: (query) => quickAddProduct(context, ref, initialName: query),
    );
    if (product == null || !mounted) return;

    await ref.read(recipesProvider.notifier).linkIngredient(
          ingredientId: line.ingredient.id,
          productId: product.id,
        );
    if (!mounted) return;

    // La receta guardada ya quedó vinculada; la copia local lo aplica ahora
    // para que la fila se mueva a "se descuenta" sin cerrar la hoja.
    setState(() {
      _recipe = _recipe.copyWith(
        ingredients: [
          for (final ingredient in _recipe.ingredients)
            ingredient.id == line.ingredient.id
                ? ingredient.copyWith(productId: product.id)
                : ingredient,
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final media = MediaQuery.of(context);

    final products =
        ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final plan = _planFrom(products);
    final lines = plan.deductible;
    final skipped = plan.skipped;
    final deltas = _deltas(plan);
    final nothingToDeduct = lines.isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      nothingToDeduct
                          ? 'No se pudo descontar nada'
                          : 'Descontar de la despensa',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    nothingToDeduct
                        ? 'Ningún ingrediente de ${widget.recipe.name} se pudo '
                            'cruzar con la despensa:'
                        : 'Ajusta lo que realmente ocupaste en '
                            '${widget.recipe.name}.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withAlpha(150)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final line in lines) _lineTile(line, theme),
                  if (skipped.isNotEmpty) ...[
                    if (!nothingToDeduct) ...[
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'No se descuentan',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: cs.onSurface.withAlpha(150)),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    for (final line in skipped)
                      _skippedTile(line, theme, products),
                  ],
                  // Al final y solo si hace falta: explica el "≈" sin empujar
                  // hacia abajo lo que el usuario sí tiene que tocar.
                  if (lines.any((l) => l.isEstimate))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                      child: Text(
                        '≈ equivalencia de referencia. Si en tu caso es otra, '
                        'decláralo en el producto y manda la tuya.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurface.withAlpha(130)),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: nothingToDeduct
                    ? SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              Navigator.pop(context, <String, double>{}),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Registrar de todos modos'),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: deltas.isEmpty
                                  ? null
                                  : () => Navigator.pop(context, deltas),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Descontar y registrar'),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, <String, double>{}),
                              child: const Text('Solo registrar la receta'),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineTile(DeductionLine line, ThemeData theme) {
    final cs = theme.colorScheme;
    final product = line.product!;
    final enabled = !_excluded.contains(line.ingredient.id);

    final String detail;
    final bool warns;
    if (!enabled || line.effectiveAmount <= 0) {
      detail = 'No se descuenta';
      warns = false;
    } else if (line.status == DeductionStatus.partial) {
      detail = 'Solo hay ${formatQuantity(product.currentQuantity)} '
          '${product.unit}: quedará en 0';
      warns = true;
    } else {
      // El "≈" no es un adorno: separa lo que sale de la ficha de este
      // producto de lo que sale de una tabla de cocina general.
      final approx = line.isEstimate ? '≈' : '';
      detail = 'Quedan $approx${formatQuantity(line.remainingAfter!)} '
          '${product.unit}';
      warns = false;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        children: [
          Checkbox(
            value: enabled,
            onChanged: (value) => setState(() {
              if (value ?? false) {
                _excluded.remove(line.ingredient.id);
              } else {
                _excluded.add(line.ingredient.id);
              }
            }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: enabled ? null : cs.onSurface.withAlpha(110),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: warns ? cs.error : cs.onSurface.withAlpha(140),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: TextField(
              controller: _controllerFor(line),
              enabled: enabled,
              textAlign: TextAlign.end,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onChanged: (text) => _onAmountChanged(line, text),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 46,
            child: Text(
              line.ingredient.unit,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withAlpha(150)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Declara a cuánto equivale la unidad de la receta y recalcula la hoja.
  Future<void> _declare(DeductionLine line) async {
    final product = line.product;
    if (product == null) return;
    final saved = await declareUnitEquivalence(
      context,
      ref,
      product: product,
      recipeUnit: line.ingredient.unit,
    );
    // No hace falta tocar nada más: el plan se recalcula solo porque `build`
    // observa las equivalencias, y la línea salta de "no se descuenta" a la
    // lista de arriba sin cerrar la hoja.
    if (saved && mounted) setState(() {});
  }

  Widget _fixButton(String label, VoidCallback onPressed) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label),
      );

  Widget _skippedTile(
      DeductionLine line, ThemeData theme, List<Product> products) {
    final cs = theme.colorScheme;
    // Cada motivo se arregla en un sitio distinto —o en ninguno—, así que se
    // dicen por separado en vez de un "no se pudo" que deja al usuario
    // adivinando cuál de los tres le tocó.
    final missing = line.status == DeductionStatus.unmatched;
    final unquantified = line.status == DeductionStatus.unquantified;
    final reason = switch (line.status) {
      DeductionStatus.unmatched => 'no está en la despensa',
      DeductionStatus.unquantified =>
        'la receta no dice cuánto (${line.ingredient.unit})',
      _ => 'no consta cuántos ${line.ingredient.unit} rinde '
          '1 ${line.product!.unit}',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Row(
        children: [
          Icon(Icons.remove_rounded,
              size: 16, color: cs.onSurface.withAlpha(90)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: line.ingredient.productName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: ' — $reason'),
                ],
              ),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withAlpha(150)),
            ),
          ),
          // Cada botón arregla su motivo. Vincular no sirve de nada si el
          // problema son las unidades, y declarar la equivalencia no sirve si
          // todavía no hay producto al que atarla. Y "al gusto" no se arregla:
          // ofrecer un botón ahí sería mandar al usuario a una tarea que no
          // existe.
          //
          // "Declarar" a secas y no "Declarar equivalencia": el texto de la
          // izquierda ya dice qué falta, y la etiqueta larga desborda la fila
          // en un teléfono de 320.
          if (missing)
            _fixButton('Vincular', () => _link(line, products))
          else if (!unquantified)
            _fixButton('Declarar', () => _declare(line)),
        ],
      ),
    );
  }
}
