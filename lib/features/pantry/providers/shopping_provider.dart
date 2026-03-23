import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../models/shopping_session.dart';
import '../models/product.dart';
import 'pantry_provider.dart';

const _uuid = Uuid();

// Active session provider
final activeSessionProvider =
    AsyncNotifierProvider<ActiveSessionNotifier, ShoppingSession?>(
  ActiveSessionNotifier.new,
);

class ActiveSessionNotifier extends AsyncNotifier<ShoppingSession?> {
  @override
  Future<ShoppingSession?> build() => _loadActiveSession();

  Future<ShoppingSession?> _loadActiveSession() async {
    final db = await DatabaseHelper.instance.database;
    final sessions = await db.query(
      'shopping_sessions',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (sessions.isEmpty) return null;
    final session = ShoppingSession.fromMap(sessions.first);
    return _loadSessionWithItems(session);
  }

  Future<ShoppingSession> _loadSessionWithItems(ShoppingSession session) async {
    final db = await DatabaseHelper.instance.database;
    final itemMaps = await db.query(
      'shopping_items',
      where: 'session_id = ?',
      whereArgs: [session.id],
    );
    final items = itemMaps.map(ShoppingItem.fromMap).toList();
    return session.copyWith(items: items);
  }

  Future<ShoppingSession> startNewSession() async {
    final db = await DatabaseHelper.instance.database;
    // Get all products
    final products = await ref.read(productsProvider.future);
    final categories = await ref.read(categoriesProvider.future);

    final session = ShoppingSession(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      status: ShoppingStatus.active,
    );
    await db.insert('shopping_sessions', session.toMap());

    // Add all products as shopping items (prioritize low stock)
    final items = <ShoppingItem>[];
    for (final product in products) {
      final catName = categories
          .firstWhere(
            (c) => c.id == product.categoryId,
            orElse: () => const ProductCategory(id: '', name: 'Sin categoría'),
          )
          .name;

      final neededQty = product.isLow
          ? product.neededQuantity
          : product.quantityToMaintain;

      final item = ShoppingItem(
        id: _uuid.v4(),
        sessionId: session.id,
        productId: product.id,
        productName: product.name,
        plannedQuantity: neededQty > 0 ? neededQty : product.quantityToMaintain,
        unit: product.unit,
        plannedPrice: product.lastPrice,
        categoryId: product.categoryId,
        categoryName: catName,
        lastPlace: product.lastPlace,
      );
      items.add(item);
      await db.insert('shopping_items', item.toMap());
    }

    final fullSession = session.copyWith(items: items);
    state = AsyncValue.data(fullSession);
    return fullSession;
  }

  Future<void> markItemPurchased({
    required String itemId,
    required double actualQuantity,
    required double actualPrice,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'shopping_items',
      {
        'actual_quantity': actualQuantity,
        'actual_price': actualPrice,
        'is_purchased': 1,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
    ref.invalidateSelf();
  }

  Future<void> markItemUnpurchased(String itemId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'shopping_items',
      {'is_purchased': 0},
      where: 'id = ?',
      whereArgs: [itemId],
    );
    ref.invalidateSelf();
  }

  Future<void> completeSession() async {
    final session = state.value;
    if (session == null) return;

    final db = await DatabaseHelper.instance.database;
    double totalCost = 0;

    // Update product quantities and prices for purchased items
    for (final item in session.items.where((i) => i.isPurchased)) {
      final qty = item.actualQuantity ?? item.plannedQuantity;
      final price = item.actualPrice > 0 ? item.actualPrice : item.plannedPrice;
      totalCost += qty * price;

      // Get current product and add purchased quantity
      final prodMaps = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [item.productId],
        limit: 1,
      );
      if (prodMaps.isNotEmpty) {
        final product = Product.fromMap(prodMaps.first);
        await db.update(
          'products',
          {
            'current_quantity': product.currentQuantity + qty,
            'last_price': price > 0 ? price : product.lastPrice,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [item.productId],
        );
      }
    }

    await db.update(
      'shopping_sessions',
      {
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'total_cost': totalCost,
      },
      where: 'id = ?',
      whereArgs: [session.id],
    );

    state = const AsyncValue.data(null);
    ref.invalidate(sessionsHistoryProvider);
    ref.invalidate(productsProvider);
  }

  Future<void> cancelSession() async {
    final session = state.value;
    if (session == null) return;

    final db = await DatabaseHelper.instance.database;
    await db.update(
      'shopping_sessions',
      {
        'status': 'cancelled',
        'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [session.id],
    );

    state = const AsyncValue.data(null);
    ref.invalidate(sessionsHistoryProvider);
  }
}

// ─── Sessions History ─────────────────────────────────────────────────────────

final sessionsHistoryProvider =
    AsyncNotifierProvider<SessionsHistoryNotifier, List<ShoppingSession>>(
  SessionsHistoryNotifier.new,
);

class SessionsHistoryNotifier extends AsyncNotifier<List<ShoppingSession>> {
  @override
  Future<List<ShoppingSession>> build() => _loadHistory();

  Future<List<ShoppingSession>> _loadHistory() async {
    final db = await DatabaseHelper.instance.database;
    final sessionMaps = await db.query(
      'shopping_sessions',
      where: 'status != ?',
      whereArgs: ['active'],
      orderBy: 'created_at DESC',
    );

    final sessions = <ShoppingSession>[];
    for (final m in sessionMaps) {
      final session = ShoppingSession.fromMap(m);
      final itemMaps = await db.query(
        'shopping_items',
        where: 'session_id = ?',
        whereArgs: [session.id],
      );
      final items = itemMaps.map(ShoppingItem.fromMap).toList();
      sessions.add(session.copyWith(items: items));
    }
    return sessions;
  }
}

// Shopping items organized by area (category + place)
final shoppingItemsByAreaProvider =
    Provider<AsyncValue<Map<String, List<ShoppingItem>>>>((ref) {
  final sessionAsync = ref.watch(activeSessionProvider);
  return sessionAsync.whenData((session) {
    if (session == null) return {};
    final items = session.items;

    // Sort: low stock items first, then by category/area
    final lowItems = items.where((i) => !i.isPurchased).toList()
      ..sort((a, b) {
        final aKey = '${a.lastPlace ?? a.categoryName ?? "Otros"}';
        final bKey = '${b.lastPlace ?? b.categoryName ?? "Otros"}';
        return aKey.compareTo(bKey);
      });
    final purchasedItems =
        items.where((i) => i.isPurchased).toList();

    final allItems = [...lowItems, ...purchasedItems];

    final grouped = <String, List<ShoppingItem>>{};
    for (final item in allItems) {
      final area = item.lastPlace?.isNotEmpty == true
          ? item.lastPlace!
          : (item.categoryName ?? 'Sin categoría');
      grouped.putIfAbsent(area, () => []).add(item);
    }
    return grouped;
  });
});
