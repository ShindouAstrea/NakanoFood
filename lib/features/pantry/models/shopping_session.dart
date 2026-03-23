enum ShoppingStatus { active, completed, cancelled }

class ShoppingItem {
  final String id;
  final String sessionId;
  final String productId;
  final String productName;
  final double plannedQuantity;
  final double? actualQuantity;
  final String unit;
  final double plannedPrice;
  final double actualPrice;
  final bool isPurchased;
  final String? categoryId;
  final String? categoryName;
  final String? subcategoryId;
  final String? subcategoryName;
  final String? lastPlace;

  const ShoppingItem({
    required this.id,
    required this.sessionId,
    required this.productId,
    required this.productName,
    required this.plannedQuantity,
    this.actualQuantity,
    required this.unit,
    this.plannedPrice = 0,
    this.actualPrice = 0,
    this.isPurchased = false,
    this.categoryId,
    this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    this.lastPlace,
  });

  double get effectiveQuantity => actualQuantity ?? plannedQuantity;
  double get effectivePrice => actualPrice > 0 ? actualPrice : plannedPrice;
  double get totalCost => effectiveQuantity * effectivePrice;

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      plannedQuantity: (map['planned_quantity'] as num).toDouble(),
      actualQuantity: (map['actual_quantity'] as num?)?.toDouble(),
      unit: map['unit'] as String,
      plannedPrice: (map['planned_price'] as num?)?.toDouble() ?? 0,
      actualPrice: (map['actual_price'] as num?)?.toDouble() ?? 0,
      isPurchased: (map['is_purchased'] as int? ?? 0) == 1,
      categoryId: map['category_id'] as String?,
      categoryName: map['category_name'] as String?,
      subcategoryId: map['subcategory_id'] as String?,
      subcategoryName: map['subcategory_name'] as String?,
      lastPlace: map['last_place'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'product_id': productId,
      'product_name': productName,
      'planned_quantity': plannedQuantity,
      'actual_quantity': actualQuantity,
      'unit': unit,
      'planned_price': plannedPrice,
      'actual_price': actualPrice,
      'is_purchased': isPurchased ? 1 : 0,
      'category_id': categoryId,
      'category_name': categoryName,
      'subcategory_id': subcategoryId,
      'subcategory_name': subcategoryName,
      'last_place': lastPlace,
    };
  }

  ShoppingItem copyWith({
    String? id,
    String? sessionId,
    String? productId,
    String? productName,
    double? plannedQuantity,
    double? actualQuantity,
    String? unit,
    double? plannedPrice,
    double? actualPrice,
    bool? isPurchased,
    String? categoryId,
    String? categoryName,
    String? subcategoryId,
    String? subcategoryName,
    String? lastPlace,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      plannedQuantity: plannedQuantity ?? this.plannedQuantity,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      unit: unit ?? this.unit,
      plannedPrice: plannedPrice ?? this.plannedPrice,
      actualPrice: actualPrice ?? this.actualPrice,
      isPurchased: isPurchased ?? this.isPurchased,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      lastPlace: lastPlace ?? this.lastPlace,
    );
  }
}

class ShoppingSession {
  final String id;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double totalCost;
  final ShoppingStatus status;
  final String? notes;
  final List<ShoppingItem> items;

  const ShoppingSession({
    required this.id,
    required this.createdAt,
    this.completedAt,
    this.totalCost = 0,
    this.status = ShoppingStatus.active,
    this.notes,
    this.items = const [],
  });

  int get purchasedCount => items.where((i) => i.isPurchased).length;
  int get totalCount => items.length;
  double get calculatedTotal =>
      items.fold(0, (sum, item) => sum + item.totalCost);

  factory ShoppingSession.fromMap(Map<String, dynamic> map) {
    return ShoppingSession(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0,
      status: _statusFromString(map['status'] as String? ?? 'active'),
      notes: map['notes'] as String?,
    );
  }

  static ShoppingStatus _statusFromString(String s) {
    switch (s) {
      case 'completed':
        return ShoppingStatus.completed;
      case 'cancelled':
        return ShoppingStatus.cancelled;
      default:
        return ShoppingStatus.active;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'total_cost': totalCost,
      'status': status.name,
      'notes': notes,
    };
  }

  ShoppingSession copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? completedAt,
    double? totalCost,
    ShoppingStatus? status,
    String? notes,
    List<ShoppingItem>? items,
  }) {
    return ShoppingSession(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      totalCost: totalCost ?? this.totalCost,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }
}
