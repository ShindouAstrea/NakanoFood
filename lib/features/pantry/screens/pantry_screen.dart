import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pantry_provider.dart';
import '../providers/shopping_provider.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'add_edit_product_screen.dart';
import 'product_detail_screen.dart';
import 'shopping_screen.dart';
import '../../../shared/widgets/empty_state.dart';

class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.grey;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(pantryFilterProvider);
    final search = ref.watch(pantrySearchProvider);
    final lowStockAsync = ref.watch(lowStockProductsProvider);
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Despensa'),
        actions: [
          activeSession.when(
            data: (session) => session != null
                ? Badge(
                    label: Text('${session.purchasedCount}/${session.totalCount}'),
                    child: IconButton(
                      icon: const Icon(Icons.shopping_cart),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ShoppingScreen()),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ShoppingScreen()),
                    ),
                  ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar productos...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) =>
                  ref.read(pantrySearchProvider.notifier).state = v,
            ),
          ),
          // Category filter chips
          categoriesAsync.when(
            data: (categories) => SizedBox(
              height: 44,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('Todos'),
                      selected: selectedCategory == null,
                      onSelected: (_) => ref
                          .read(pantryFilterProvider.notifier)
                          .state = null,
                    ),
                  ),
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(cat.name),
                          selected: selectedCategory == cat.id,
                          selectedColor:
                              _parseColor(cat.color).withAlpha(50),
                          onSelected: (_) => ref
                              .read(pantryFilterProvider.notifier)
                              .state = selectedCategory == cat.id
                              ? null
                              : cat.id,
                        ),
                      )),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 44),
            error: (_, __) => const SizedBox(height: 44),
          ),
          // Low stock banner
          lowStockAsync.when(
            data: (lowItems) => lowItems.isEmpty
                ? const SizedBox()
                : Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${lowItems.length} producto${lowItems.length > 1 ? 's' : ''} por agotarse',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          // Product list
          Expanded(
            child: productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return EmptyState(
                    icon: Icons.kitchen_outlined,
                    title: 'Sin productos',
                    subtitle: 'Agrega productos a tu despensa\npara comenzar a gestionar tu inventario',
                    actionLabel: 'Agregar producto',
                    onAction: () => _navigateToAddProduct(context),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(productsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: products.length,
                    itemBuilder: (_, i) => ProductCard(
                      product: products[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(
                            productId: products[i].id,
                          ),
                        ),
                      ).then((_) => ref.invalidate(productsProvider)),
                    ),
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_shopping',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShoppingScreen()),
            ),
            icon: const Icon(Icons.shopping_cart_checkout),
            label: const Text('Ir de Compras'),
            backgroundColor: Colors.orange,
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'fab_add',
            onPressed: () => _navigateToAddProduct(context),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _navigateToAddProduct(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
    );
  }
}
