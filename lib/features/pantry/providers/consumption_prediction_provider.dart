import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../models/product.dart';
import 'pantry_provider.dart';

/// Urgency level for a product in the shopping list.
enum StockUrgency {
  /// Will run out in ≤ 3 days
  critical,

  /// Will run out in 4–7 days
  warning,

  /// Will run out in 8–14 days
  soon,

  /// Stock is sufficient or no data available
  ok,
}

class ProductPrediction {
  final Product product;

  /// Estimated days until stock runs out. null = not enough data.
  final int? daysUntilEmpty;

  /// Average daily consumption in product units. null = no history.
  final double? dailyConsumption;

  final StockUrgency urgency;

  const ProductPrediction({
    required this.product,
    this.daysUntilEmpty,
    this.dailyConsumption,
    required this.urgency,
  });
}

final consumptionPredictionsProvider =
    FutureProvider<List<ProductPrediction>>((ref) async {
  final products = await ref.watch(productsProvider.future);
  return _computePredictions(products);
});

/// Provider scoped to a single product id — used in shopping list tiles.
final productPredictionProvider =
    FutureProvider.family<ProductPrediction?, String>((ref, productId) async {
  final predictions = await ref.watch(consumptionPredictionsProvider.future);
  try {
    return predictions.firstWhere((p) => p.product.id == productId);
  } catch (_) {
    return null;
  }
});

Future<List<ProductPrediction>> _computePredictions(
    List<Product> products) async {
  final db = await DatabaseHelper.instance.database;
  final result = <ProductPrediction>[];

  for (final product in products) {
    // Load purchase history ordered by date ascending
    final history = await db.query(
      'product_price_history',
      where: 'product_id = ?',
      whereArgs: [product.id],
      orderBy: 'purchased_at ASC',
    );

    if (history.length < 2) {
      // Not enough data: classify only by current stock vs target
      result.add(ProductPrediction(
        product: product,
        urgency: product.isLow ? StockUrgency.warning : StockUrgency.ok,
      ));
      continue;
    }

    // Compute average days between purchases as a proxy for consumption rate.
    // Each purchase represents refilling ~quantityToMaintain units.
    final dates = history
        .map((r) => DateTime.parse(r['purchased_at'] as String))
        .toList();

    double totalDays = 0;
    for (int i = 1; i < dates.length; i++) {
      totalDays += dates[i].difference(dates[i - 1]).inHours / 24.0;
    }
    final avgDaysBetweenPurchases = totalDays / (dates.length - 1);

    // Consumption per day ≈ quantityToMaintain / avgDaysBetweenPurchases
    final dailyConsumption = avgDaysBetweenPurchases > 0
        ? product.quantityToMaintain / avgDaysBetweenPurchases
        : null;

    int? daysUntilEmpty;
    StockUrgency urgency;

    if (dailyConsumption != null && dailyConsumption > 0) {
      daysUntilEmpty =
          (product.currentQuantity / dailyConsumption).floor();

      if (daysUntilEmpty <= 3) {
        urgency = StockUrgency.critical;
      } else if (daysUntilEmpty <= 7) {
        urgency = StockUrgency.warning;
      } else if (daysUntilEmpty <= 14) {
        urgency = StockUrgency.soon;
      } else {
        urgency = StockUrgency.ok;
      }
    } else {
      urgency = product.isLow ? StockUrgency.warning : StockUrgency.ok;
    }

    result.add(ProductPrediction(
      product: product,
      daysUntilEmpty: daysUntilEmpty,
      dailyConsumption: dailyConsumption,
      urgency: urgency,
    ));
  }

  // Sort: critical first, then warning, then soon, then ok
  result.sort((a, b) => a.urgency.index.compareTo(b.urgency.index));
  return result;
}
