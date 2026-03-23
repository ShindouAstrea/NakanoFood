import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../models/product.dart';

const _uuid = Uuid();

// ─── Categories ───────────────────────────────────────────────────────────────

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<ProductCategory>>(
  CategoriesNotifier.new,
);

class CategoriesNotifier extends AsyncNotifier<List<ProductCategory>> {
  @override
  Future<List<ProductCategory>> build() => _loadCategories();

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

  Future<ProductCategory> addCategory(String name, String? icon, String? color) async {
    final db = await DatabaseHelper.instance.database;
    final cat = ProductCategory(
      id: _uuid.v4(),
      name: name,
      isCustom: true,
      icon: icon,
      color: color ?? '#9E9E9E',
    );
    await db.insert('product_categories', cat.toMap());
    ref.invalidateSelf();
    return cat;
  }

  Future<void> addSubcategory(String categoryId, String name) async {
    final db = await DatabaseHelper.instance.database;
    final sub = ProductSubcategory(
      id: _uuid.v4(),
      categoryId: categoryId,
      name: name,
    );
    await db.insert('product_subcategories', sub.toMap());
    ref.invalidateSelf();
  }

  Future<void> deleteCategory(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('product_categories', where: 'id = ?', whereArgs: [id]);
    ref.invalidateSelf();
  }
}

// ─── Products ─────────────────────────────────────────────────────────────────

final productsProvider =
    AsyncNotifierProvider<ProductsNotifier, List<Product>>(
  ProductsNotifier.new,
);

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() => _loadProducts();

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
    await db.insert('products', product.toMap());
    if (nutritionalValues != null) {
      await db.insert('nutritional_values', nutritionalValues.toMap());
    }
    ref.invalidateSelf();
  }

  Future<void> updateProduct(
    Product product, {
    NutritionalValues? nutritionalValues,
    bool deleteNutritional = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'products',
      product.toMap(),
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
      if (existing.isEmpty) {
        await db.insert('nutritional_values', nutritionalValues.toMap());
      } else {
        await db.update(
          'nutritional_values',
          nutritionalValues.toMap(),
          where: 'product_id = ?',
          whereArgs: [product.id],
        );
      }
    }
    ref.invalidateSelf();
  }

  Future<void> updateCurrentQuantity(String productId, double quantity) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'products',
      {
        'current_quantity': quantity,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
    ref.invalidateSelf();
  }

  Future<void> deleteProduct(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    ref.invalidateSelf();
  }
}

// ─── Filters ──────────────────────────────────────────────────────────────────

final pantryFilterProvider = StateProvider<String?>((ref) => null);
final pantrySearchProvider = StateProvider<String>((ref) => '');

final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(productsProvider);
  final filter = ref.watch(pantryFilterProvider);
  final search = ref.watch(pantrySearchProvider).toLowerCase();

  return products.whenData((list) {
    return list.where((p) {
      final matchesCategory = filter == null || p.categoryId == filter;
      final matchesSearch = search.isEmpty ||
          p.name.toLowerCase().contains(search) ||
          (p.categoryName?.toLowerCase().contains(search) ?? false);
      return matchesCategory && matchesSearch;
    }).toList();
  });
});

final lowStockProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final products = ref.watch(productsProvider);
  return products.whenData(
      (list) => list.where((p) => p.isLow).toList()
        ..sort((a, b) => a.currentQuantity.compareTo(b.currentQuantity)));
});
