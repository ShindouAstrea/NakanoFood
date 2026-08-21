import 'package:flutter/material.dart';

import '../../../shared/utils/number_input.dart';
import '../models/product.dart';

/// Productos de la despensa que se parecen a lo escrito, del que más se parece
/// al que menos.
///
/// Compara palabra por palabra en vez de la frase entera: quien busca "papas
/// medianas" quiere ver "Papas", y un `contains` de la frase completa no la
/// encuentra nunca. Con la búsqueda vacía devuelve todo, que es lo útil cuando
/// se abre el selector sin saber cómo se llamó el producto.
List<Product> matchingProducts(List<Product> products, String query) {
  final normalized = normalizeName(query);
  if (normalized.isEmpty) {
    final all = [...products]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return all;
  }

  final tokens =
      normalized.split(' ').where((token) => token.length >= 3).toList();
  // Con lo escrito aún corto ("pa") no queda ninguna palabra larga, pero
  // filtrar por ella es mejor que devolver la despensa entera.
  if (tokens.isEmpty) tokens.add(normalized);

  final scored = <Product, int>{};
  for (final product in products) {
    final score = _score(product, tokens);
    if (score > 0) scored[product] = score;
  }

  final result = scored.keys.toList()
    ..sort((a, b) {
      final byScore = scored[b]!.compareTo(scored[a]!);
      if (byScore != 0) return byScore;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return result;
}

int _score(Product product, List<String> tokens) {
  final name = normalizeName(product.name);
  final words = name.split(' ');
  var score = 0;

  for (final token in tokens) {
    if (name == token) {
      score += 4;
    } else if (name.contains(token) || token.contains(name)) {
      // "papas" encuentra "Papas fritas", y "papas medianas" encuentra "Papa".
      score += 2;
    } else if (words.any((w) => w.startsWith(token) || token.startsWith(w))) {
      score += 1;
    }
  }
  return score;
}

/// Elige un producto de la despensa. Devuelve null si se cierra sin elegir.
///
/// Con [onCreate] el selector también ofrece darlo de alta sin salir de aquí:
/// buscar algo que no existe es justo el momento en que hace falta crearlo, y
/// obligar a cerrar, ir a la despensa y volver es perder el hilo.
Future<Product?> pickPantryProduct(
  BuildContext context, {
  required List<Product> products,
  String? initialQuery,
  Future<Product?> Function(String query)? onCreate,
}) {
  return showDialog<Product>(
    context: context,
    builder: (_) => _ProductPickerDialog(
      products: products,
      initialQuery: initialQuery ?? '',
      onCreate: onCreate,
    ),
  );
}

class _ProductPickerDialog extends StatefulWidget {
  final List<Product> products;
  final String initialQuery;
  final Future<Product?> Function(String query)? onCreate;

  const _ProductPickerDialog({
    required this.products,
    required this.initialQuery,
    this.onCreate,
  });

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    // Arranca con el nombre del ingrediente ya escrito: casi siempre el
    // producto está entre los primeros resultados y basta con tocarlo.
    _search = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await widget.onCreate!(_search.text.trim());
    if (created == null || !mounted) return;
    // Recién creado es, con seguridad, el que se buscaba: se devuelve sin
    // obligar a encontrarlo otra vez en la lista donde ahora sí aparece.
    if (context.mounted) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final query = _search.text.trim();
    final results = matchingProducts(widget.products, query);

    return AlertDialog(
      title: const Text('Vincular con un producto'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 340,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Buscar en la despensa',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        widget.products.isEmpty
                            ? 'No hay productos en la despensa'
                            : 'Ningún producto coincide',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurface.withAlpha(140)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final product = results[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(product.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            'Tienes ${formatQuantity(product.currentQuantity)} '
                            '${product.unit}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withAlpha(140)),
                          ),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
            if (widget.onCreate != null) ...[
              const Divider(height: 8),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.add_rounded, color: cs.primary),
                title: Text(
                  query.isEmpty ? 'Crear un producto' : 'Crear "$query"',
                  style: TextStyle(color: cs.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: _create,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
