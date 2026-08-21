import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/db_write_helper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/sync_service.dart';
import '../../../shared/utils/number_input.dart';
import '../models/product.dart';
import '../models/price_history_entry.dart';

const _uuid = Uuid();

// ─── Categories ───────────────────────────────────────────────────────────────

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<ProductCategory>>(
  CategoriesNotifier.new,
);

class CategoriesNotifier extends AsyncNotifier<List<ProductCategory>> {
  @override
  Future<List<ProductCategory>> build() {
    ref.watch(syncCompletionCountProvider);
    return _loadCategories();
  }

  String? get _uid => ref.read(currentUserIdProvider);

  Future<List<ProductCategory>> _loadCategories() async {
    final db = await DatabaseHelper.instance.database;
    final catMaps = await db.query('product_categories', orderBy: 'name ASC');
    final subMaps =
        await db.query('product_subcategories', orderBy: 'name ASC');

    return catMaps.map((c) {
      final subs = subMaps
          .where((s) => s['category_id'] == c['id'])
          .map(ProductSubcategory.fromMap)
          .toList();
      return ProductCategory.fromMap(c).copyWith(subcategories: subs);
    }).toList();
  }

  Future<ProductCategory> addCategory(
      String name, String? icon, String? color) async {
    final db = await DatabaseHelper.instance.database;
    final cat = ProductCategory(
      id: _uuid.v4(),
      name: name,
      isCustom: true,
      icon: icon,
      color: color ?? '#9E9E9E',
    );
    await db.insert('product_categories', withSync(cat.toMap(), _uid));
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
    return cat;
  }

  Future<void> addSubcategory(String categoryId, String name) async {
    final db = await DatabaseHelper.instance.database;
    final sub = ProductSubcategory(
      id: _uuid.v4(),
      categoryId: categoryId,
      name: name,
    );
    await db.insert(
        'product_subcategories', withSync(sub.toMap(), _uid));
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> deleteCategory(String id) async {
    final db = await DatabaseHelper.instance.database;
    await ref.read(syncServiceProvider).recordDeletion('product_categories', id);
    await db.delete('product_categories', where: 'id = ?', whereArgs: [id]);
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }
}

// ─── Products ─────────────────────────────────────────────────────────────────

final productsProvider =
    AsyncNotifierProvider<ProductsNotifier, List<Product>>(
  ProductsNotifier.new,
);

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() {
    ref.watch(syncCompletionCountProvider);
    return _loadProducts();
  }

  String? get _uid => ref.read(currentUserIdProvider);

  Future<List<Product>> _loadProducts() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.rawQuery('''
      SELECT p.*,
             pc.name as category_name,
             pc.color as category_color,
             ps.name as subcategory_name
      FROM products p
      LEFT JOIN product_categories pc ON p.category_id = pc.id
      LEFT JOIN product_subcategories ps ON p.subcategory_id = ps.id
      ORDER BY pc.name ASC, p.name ASC
    ''');

    final products = <Product>[];
    for (final m in maps) {
      final product = Product.fromMap(m);
      final nutMaps = await db.query(
        'nutritional_values',
        where: 'product_id = ?',
        whereArgs: [product.id],
        limit: 1,
      );
      final nut =
          nutMaps.isNotEmpty ? NutritionalValues.fromMap(nutMaps.first) : null;
      products.add(product.copyWith(nutritionalValues: nut));
    }
    return products;
  }

  Future<void> addProduct(
    Product product, {
    NutritionalValues? nutritionalValues,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('products', withSync(product.toMap(), _uid));
    if (nutritionalValues != null) {
      await db.insert(
          'nutritional_values', withSync(nutritionalValues.toMap(), _uid));
    }
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> updateProduct(
    Product product, {
    NutritionalValues? nutritionalValues,
    bool deleteNutritional = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'products',
      withSync(product.toMap(), _uid),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    if (deleteNutritional) {
      await db.delete(
        'nutritional_values',
        where: 'product_id = ?',
        whereArgs: [product.id],
      );
    } else if (nutritionalValues != null) {
      final existing = await db.query(
        'nutritional_values',
        where: 'product_id = ?',
        whereArgs: [product.id],
        limit: 1,
      );
      final data = withSync(nutritionalValues.toMap(), _uid);
      if (existing.isEmpty) {
        await db.insert('nutritional_values', data);
      } else {
        await db.update(
          'nutritional_values',
          data,
          where: 'product_id = ?',
          whereArgs: [product.id],
        );
      }
    }
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> updateCurrentQuantity(String productId, double quantity) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'products',
      {
        'current_quantity': quantity,
        'updated_at': DateTime.now().toIso8601String(),
        'synced_at': null,
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  /// Descuenta de la despensa lo que se consumió, por ejemplo al cocinar.
  ///
  /// Recibe cuánto restar por producto, en unidades del producto, y lo aplica
  /// todo en una transacción: escribir producto a producto dejaba la despensa
  /// a medio actualizar si algo fallaba a la mitad, y disparaba un sync por
  /// cada uno.
  ///
  /// El stock nunca baja de cero. Un negativo no significa nada en una
  /// despensa y contaminaría el costo estimado y la predicción de consumo,
  /// que multiplican por la cantidad guardada.
  Future<void> consumeQuantities(Map<String, double> amountByProductId) async {
    if (amountByProductId.isEmpty) return;

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final entry in amountByProductId.entries) {
        if (entry.value <= 0) continue;

        // Se relee el stock dentro de la transacción en vez de confiar en el
        // que traía la pantalla: entre que se abrió la receta y se confirmó,
        // el usuario pudo editar el producto o entrar un sync.
        final rows = await txn.query(
          'products',
          columns: ['current_quantity'],
          where: 'id = ?',
          whereArgs: [entry.key],
          limit: 1,
        );
        if (rows.isEmpty) continue;

        final current = (rows.first['current_quantity'] as num?)?.toDouble() ?? 0;
        final left = current - entry.value;

        await txn.update(
          'products',
          {
            'current_quantity': left > 0 ? roundQuantity(left) : 0,
            'updated_at': now,
            'synced_at': null,
          },
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
    });

    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }

  Future<void> deleteProduct(String id) async {
    final db = await DatabaseHelper.instance.database;
    await ref.read(syncServiceProvider).recordDeletion('products', id);
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    ref.invalidateSelf();
    ref.read(syncServiceProvider).queueSync();
  }
}

// ─── Filters ──────────────────────────────────────────────────────────────────

final pantryFilterProvider = StateProvider<String?>((ref) => null);
final pantrySearchProvider = StateProvider<String>((ref) => '');
final pantryLowStockFilterProvider = StateProvider<bool>((ref) => false);

final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(productsProvider);
  final filter = ref.watch(pantryFilterProvider);
  final search = ref.watch(pantrySearchProvider).toLowerCase();
  final lowStockOnly = ref.watch(pantryLowStockFilterProvider);

  return products.whenData((list) {
    return list.where((p) {
      final matchesCategory = filter == null || p.categoryId == filter;
      final matchesSearch = search.isEmpty ||
          p.name.toLowerCase().contains(search) ||
          (p.categoryName?.toLowerCase().contains(search) ?? false);
      final matchesLowStock = !lowStockOnly || p.isLow;
      return matchesCategory && matchesSearch && matchesLowStock;
    }).toList();
  });
});

final lowStockProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(productsProvider);
  return products.whenData(
      (list) => list.where((p) => p.isLow).toList()
        ..sort((a, b) => a.currentQuantity.compareTo(b.currentQuantity)));
});

final productPriceHistoryProvider =
    FutureProvider.family<List<PriceHistoryEntry>, String>((ref, productId) async {
  final db = await DatabaseHelper.instance.database;
  final maps = await db.query(
    'product_price_history',
    where: 'product_id = ?',
    whereArgs: [productId],
    orderBy: 'purchased_at ASC',
  );
  return maps.map(PriceHistoryEntry.fromMap).toList();
});
