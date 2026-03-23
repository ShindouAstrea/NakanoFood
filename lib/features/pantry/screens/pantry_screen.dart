import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pantry_provider.dart';
import '../providers/shopping_provider.dart';
import '../widgets/product_card.dart';
import 'add_edit_product_screen.dart';
import 'product_detail_screen.dart';
import 'shopping_screen.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeletons/product_card_skeleton.dart';
import '../../../shared/widgets/ios_install_banner.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen>
    with SingleTickerProviderStateMixin {
  bool _fabOpen = false;
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.grey;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() => _fabOpen = !_fabOpen);
    _fabOpen ? _animCtrl.forward() : _animCtrl.reverse();
  }

  void _closeFab() {
    if (_fabOpen) {
      setState(() => _fabOpen = false);
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(pantryFilterProvider);
    ref.watch(pantrySearchProvider);
    final lowStockAsync = ref.watch(lowStockProductsProvider);
    final activeSession = ref.watch(activeSessionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Despensa'),
        actions: [
          activeSession.when(
            data: (session) => session != null
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart),
                        tooltip: 'Carro de compras activo',
                        onPressed: () {
                          _closeFab();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ShoppingScreen()),
                          );
                        },
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox(),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _closeFab,
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // iOS install hint (web only)
            const IosInstallBanner(),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar productos...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) =>
                    ref.read(pantrySearchProvider.notifier).state = v,
                onTap: _closeFab,
              ),
            ),
            // Category filter chips
            categoriesAsync.when(
              data: (categories) => SizedBox(
                height: 40,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: const Text('Todos'),
                        selected: selectedCategory == null,
                        onSelected: (_) {
                          _closeFab();
                          ref
                              .read(pantryFilterProvider.notifier)
                              .state = null;
                        },
                      ),
                    ),
                    ...categories.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(cat.name),
                            selected: selectedCategory == cat.id,
                            selectedColor:
                                _parseColor(cat.color).withAlpha(60),
                            onSelected: (_) {
                              _closeFab();
                              ref
                                  .read(pantryFilterProvider.notifier)
                                  .state = selectedCategory == cat.id
                                  ? null
                                  : cat.id;
                            },
                          ),
                        )),
                  ],
                ),
              ),
              loading: () => const SizedBox(height: 40),
              error: (_, __) => const SizedBox(height: 40),
            ),
            // Low stock banner
            lowStockAsync.when(
              data: (lowItems) => lowItems.isEmpty
                  ? const SizedBox(height: 6)
                  : Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.orange.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange.shade800, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${lowItems.length} producto${lowItems.length > 1 ? 's' : ''} por agotarse',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
                      subtitle:
                          'Agrega productos a tu despensa\npara comenzar a gestionar tu inventario',
                      actionLabel: 'Agregar producto',
                      onAction: () => _navigateToAddProduct(context),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(productsProvider),
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.only(top: 8, bottom: 100),
                      itemCount: products.length,
                      itemBuilder: (_, i) => ProductCard(
                        product: products[i],
                        onTap: () {
                          _closeFab();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                productId: products[i].id,
                              ),
                            ),
                          ).then((_) => ref.invalidate(productsProvider));
                        },
                      ),
                    ),
                  );
                },
                loading: () => const ProductListSkeleton(),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Speed-dial actions
          AnimatedBuilder(
            animation: _expandAnim,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Shopping action
                  _SpeedDialItem(
                    animation: _expandAnim,
                    icon: Icons.shopping_cart_checkout_rounded,
                    label: 'Ir de compras',
                    color: colorScheme.tertiary,
                    onPressed: () {
                      _closeFab();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ShoppingScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Add product action
                  _SpeedDialItem(
                    animation: _expandAnim,
                    icon: Icons.add_box_rounded,
                    label: 'Agregar producto',
                    color: colorScheme.primary,
                    onPressed: () {
                      _closeFab();
                      _navigateToAddProduct(context);
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              );
            },
          ),
          // Main FAB
          FloatingActionButton(
            heroTag: 'fab_main',
            onPressed: _toggleFab,
            child: AnimatedRotation(
              turns: _fabOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: const Icon(Icons.add),
            ),
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

// ── Speed-dial item ───────────────────────────────────────────────────────────

class _SpeedDialItem extends StatelessWidget {
  final Animation<double> animation;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _SpeedDialItem({
    required this.animation,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(animation),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label chip
            AnimatedBuilder(
              animation: animation,
              builder: (_, __) => Opacity(
                opacity: animation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FloatingActionButton.small(
              heroTag: 'fab_$label',
              onPressed: onPressed,
              backgroundColor: color,
              foregroundColor: Colors.white,
              child: Icon(icon, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
