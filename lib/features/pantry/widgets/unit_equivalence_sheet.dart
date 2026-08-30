import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/number_input.dart';
import '../../../shared/utils/unit_conversion.dart';
import '../models/product.dart';
import '../models/unit_conversion.dart';
import '../providers/unit_conversion_provider.dart';

/// Unidades en las que tiene sentido declarar una equivalencia.
///
/// Son las que llevan a alguna parte: pesos y volúmenes se encadenan con todo
/// lo demás, y 'unidad' cierra el caso de contar piezas. Declarar "1 cucharada
/// = 0,06 paquetes" sería correcto y también inútil, porque no vale para el
/// siguiente producto ni para la siguiente receta.
const _targetUnits = ['g', 'kg', 'ml', 'L', 'unidad'];

/// Pregunta a cuánto equivale [recipeUnit] para [product] y lo guarda.
///
/// Es la salida del callejón: la receta pide cucharadas, la despensa guarda
/// paquetes y hasta ahora la app solo sabía decir que no se podía descontar.
/// Se abre desde donde falla —la hoja de "la cociné" y la lista de la compra—
/// porque una equivalencia que hay que ir a declarar a otra pantalla no la
/// declara nadie.
///
/// Devuelve true si se guardó algo.
Future<bool> declareUnitEquivalence(
  BuildContext context,
  WidgetRef ref, {
  required Product product,
  required String recipeUnit,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DeclareSheet(product: product, recipeUnit: recipeUnit),
  );
  return saved ?? false;
}

/// Las equivalencias de un producto: verlas, añadir y borrar.
Future<void> manageUnitEquivalences(
  BuildContext context,
  WidgetRef ref, {
  required Product product,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ManageSheet(product: product),
  );
}

class _DeclareSheet extends ConsumerStatefulWidget {
  final Product product;
  final String recipeUnit;

  const _DeclareSheet({required this.product, required this.recipeUnit});

  @override
  ConsumerState<_DeclareSheet> createState() => _DeclareSheetState();
}

class _DeclareSheetState extends ConsumerState<_DeclareSheet> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  late String _targetUnit;

  /// Si la equivalencia vale para cualquier producto que se llame igual.
  ///
  /// Por defecto no: lo estrecho se puede ensanchar después, y lo ancho se
  /// aplica calladamente donde el usuario no miraba.
  bool _forAnyWithThisName = false;

  @override
  void initState() {
    super.initState();
    // La unidad base del envase es la que mejor encadena: si el producto ya
    // declaró "1 paquete = 1 kg", decir cuántos kg es una cucharada completa
    // la cadena entera de una vez.
    final base = widget.product.packageBaseUnit ?? widget.product.unit;
    final canonical = canonicalUnit(base);
    _targetUnit = _targetUnits.firstWhere(
      (u) => canonicalUnit(u) == canonical,
      orElse: () => 'g',
    );
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final quantity = parseDecimal(_qtyCtrl.text);
    if (quantity == null || quantity <= 0) return;

    await ref.read(unitConversionsProvider.notifier).declare(
          productId: _forAnyWithThisName ? null : widget.product.id,
          ingredientKey: _forAnyWithThisName ? widget.product.name : null,
          fromQty: 1,
          fromUnit: widget.recipeUnit,
          toQty: quantity,
          toUnit: _targetUnit,
        );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final product = widget.product;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Cuánto es 1 ${widget.recipeUnit} de ${product.name}?',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'La receta lo pide en ${widget.recipeUnit} y tu despensa lo '
                  'guarda en ${product.unit}. Con esta equivalencia se puede '
                  'descontar; sin ella la app prefiere no tocar el stock antes '
                  'que inventarse el factor.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurface.withAlpha(150)),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text('1 ${widget.recipeUnit}  =',
                          style: theme.textTheme.bodyLarge),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _qtyCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          isDense: true,
                        ),
                        validator: validatePositiveNumber,
                        onFieldSubmitted: (_) => _save(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _targetUnit,
                        decoration: const InputDecoration(isDense: true),
                        items: [
                          for (final unit in _targetUnits)
                            DropdownMenuItem(value: unit, child: Text(unit)),
                        ],
                        onChanged: (value) => setState(
                            () => _targetUnit = value ?? _targetUnit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  value: _forAnyWithThisName,
                  onChanged: (value) =>
                      setState(() => _forAnyWithThisName = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(
                    'Vale para cualquier ${product.name.toLowerCase()}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    'Y no solo para este producto de la despensa.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withAlpha(140)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Guardar equivalencia'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageSheet extends ConsumerWidget {
  final Product product;

  const _ManageSheet({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final conversions = ref.watch(
        productConversionsProvider((id: product.id, name: product.name)));

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equivalencias de ${product.name}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              conversions.isEmpty
                  ? 'Todavía no has declarado ninguna. Hacen falta cuando una '
                      'receta pide este ingrediente en otra unidad —cucharadas, '
                      'tazas— y hay que saber a cuánto equivale.'
                  : 'Se usan para descontar de la despensa lo que pide una '
                      'receta escrita en otra unidad.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withAlpha(150)),
            ),
            const SizedBox(height: 12),
            for (final conversion in conversions)
              _row(context, ref, theme, cs, conversion),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Añadir equivalencia'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, ThemeData theme,
      ColorScheme cs, UnitConversion conversion) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, size: 18,
              color: cs.onSurface.withAlpha(120)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conversion.label, style: theme.textTheme.bodyMedium),
                // Se dice cuando afecta a más cosas que este producto: si no,
                // borrarla desde aquí parecería un cambio local y no lo es.
                if (!conversion.isForProduct)
                  Text(
                    'Vale para cualquier ${product.name.toLowerCase()}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withAlpha(130)),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Borrar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: () =>
                ref.read(unitConversionsProvider.notifier).remove(conversion.id),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final unit = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('¿Qué unidad quieres equivaler?'),
        children: [
          for (final unit in const [
            'cucharada',
            'cucharadita',
            'taza',
            'unidad',
            'rodaja',
            'diente',
            'sobre',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, unit),
              child: Text(unit),
            ),
        ],
      ),
    );
    if (unit == null || !context.mounted) return;
    await declareUnitEquivalence(context, ref,
        product: product, recipeUnit: unit);
  }
}
