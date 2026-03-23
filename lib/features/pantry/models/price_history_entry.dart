class PriceHistoryEntry {
  final String id;
  final String productId;
  final double price;
  final double priceRefQty;
  final String unit;
  final DateTime purchasedAt;

  const PriceHistoryEntry({
    required this.id,
    required this.productId,
    required this.price,
    this.priceRefQty = 1.0,
    required this.unit,
    required this.purchasedAt,
  });

  String get priceLabel {
    final priceStr = price == price.truncateToDouble()
        ? price.toInt().toString()
        : price.toStringAsFixed(0);
    if (priceRefQty != 1.0) {
      final refStr = priceRefQty == priceRefQty.truncateToDouble()
          ? priceRefQty.toInt().toString()
          : priceRefQty.toStringAsFixed(1);
      return '\$$priceStr/$refStr$unit';
    }
    return '\$$priceStr/$unit';
  }

  factory PriceHistoryEntry.fromMap(Map<String, dynamic> map) {
    return PriceHistoryEntry(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      price: (map['price'] as num).toDouble(),
      priceRefQty: (map['price_ref_qty'] as num? ?? 1.0).toDouble(),
      unit: map['unit'] as String,
      purchasedAt: DateTime.parse(map['purchased_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'price': price,
      'price_ref_qty': priceRefQty,
      'unit': unit,
      'purchased_at': purchasedAt.toIso8601String(),
    };
  }
}
