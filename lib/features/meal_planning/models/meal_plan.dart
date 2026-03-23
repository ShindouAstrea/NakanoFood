import 'meal_plan_item.dart';

class MealPlan {
  final String id;
  final DateTime date;
  final String categoryId;
  final String? notes;
  final List<MealPlanItem> items;

  // Joined
  final String? categoryName;
  final String? categoryColor;

  const MealPlan({
    required this.id,
    required this.date,
    required this.categoryId,
    this.notes,
    this.items = const [],
    this.categoryName,
    this.categoryColor,
  });

  factory MealPlan.fromMap(Map<String, dynamic> map) {
    return MealPlan(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      categoryId: map['category_id'] as String,
      notes: map['notes'] as String?,
      categoryName: map['category_name'] as String?,
      categoryColor: map['category_color'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String().split('T').first,
      'category_id': categoryId,
      'notes': notes,
    };
  }

  MealPlan copyWith({
    String? id,
    DateTime? date,
    String? categoryId,
    Object? notes = _sentinel,
    List<MealPlanItem>? items,
    Object? categoryName = _sentinel,
    Object? categoryColor = _sentinel,
  }) {
    return MealPlan(
      id: id ?? this.id,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      notes: notes == _sentinel ? this.notes : notes as String?,
      items: items ?? this.items,
      categoryName:
          categoryName == _sentinel ? this.categoryName : categoryName as String?,
      categoryColor:
          categoryColor == _sentinel ? this.categoryColor : categoryColor as String?,
    );
  }

  /// Display label: first item title or category name as fallback.
  String get displayTitle {
    if (items.isNotEmpty) return items.first.title;
    return categoryName ?? 'Comida';
  }
}

const _sentinel = Object();
