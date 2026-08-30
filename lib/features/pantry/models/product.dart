import '../../../shared/utils/unit_conversion.dart';
import '../data/unit_conversion_seed.dart';

class ProductCategory {
  final String id;
  final String name;
  final bool isCustom;
  final String? icon;
  final String? color;
  final List<ProductSubcategory> subcategories;

  const ProductCategory({
    required this.id,
    required this.name,
    this.isCustom = false,
    this.icon,
    this.color,
    this.subcategories = const [],
  });

  factory ProductCategory.fromMap(Map<String, dynamic> map) {
    return ProductCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      isCustom: (map['is_custom'] as int? ?? 0) == 1,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_custom': isCustom ? 1 : 0,
      'icon': icon,
      'color': color,
    };
  }

  ProductCategory copyWith({
    String? id,
    String? name,
    bool? isCustom,
    String? icon,
    String? color,
    List<ProductSubcategory>? subcategories,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      isCustom: isCustom ?? this.isCustom,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      subcategories: subcategories ?? this.subcategories,
    );
  }
}

class ProductSubcategory {
  final String id;
  final String categoryId;
  final String name;

  const ProductSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
  });

  factory ProductSubcategory.fromMap(Map<String, dynamic> map) {
    return ProductSubcategory(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
    };
  }
}

class NutritionalValues {
  final String id;
  final String productId;
  final double? servingSize;
  final String? servingUnit;
  final double? kcal;
  final double? carbs;
  final double? sugars;
  final double? fiber;
  final double? totalFats;
  final double? saturatedFats;
  final double? transFats;
  final double? proteins;
  final double? sodium;

  const NutritionalValues({
    required this.id,
    required this.productId,
    this.servingSize,
    this.servingUnit,
    this.kcal,
    this.carbs,
    this.sugars,
    this.fiber,
    this.totalFats,
    this.saturatedFats,
    this.transFats,
    this.proteins,
    this.sodium,
  });

  factory NutritionalValues.fromMap(Map<String, dynamic> map) {
    return NutritionalValues(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      servingSize: map['serving_size'] as double?,
      servingUnit: map['serving_unit'] as String?,
      kcal: map['kcal'] as double?,
      carbs: map['carbs'] as double?,
      sugars: map['sugars'] as double?,
      fiber: map['fiber'] as double?,
      totalFats: map['total_fats'] as double?,
      saturatedFats: map['saturated_fats'] as double?,
      transFats: map['trans_fats'] as double?,
      proteins: map['proteins'] as double?,
      sodium: map['sodium'] as double?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'serving_size': servingSize,
      'serving_unit': servingUnit,
      'kcal': kcal,
      'carbs': carbs,
      'sugars': sugars,
      'fiber': fiber,
      'total_fats': totalFats,
      'saturated_fats': saturatedFats,
      'trans_fats': transFats,
      'proteins': proteins,
      'sodium': sodium,
    };
  }

  NutritionalValues copyWith({
    String? id,
    String? productId,
    double? servingSize,
    String? servingUnit,
    double? kcal,
    double? carbs,
    double? sugars,
    double? fiber,
    double? totalFats,
    double? saturatedFats,
    double? transFats,
    double? proteins,
    double? sodium,
  }) {
    return NutritionalValues(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      kcal: kcal ?? this.kcal,
      carbs: carbs ?? this.carbs,
      sugars: sugars ?? this.sugars,
      fiber: fiber ?? this.fiber,
      totalFats: totalFats ?? this.totalFats,
      saturatedFats: saturatedFats ?? this.saturatedFats,
      transFats: transFats ?? this.transFats,
      proteins: proteins ?? this.proteins,
      sodium: sodium ?? this.sodium,
    );
  }
}

/// Unidades en que se guarda un producto de la despensa.
///
/// Viven aquí y no en la pantalla porque las ofrecen dos sitios —la ficha
/// completa y el alta rápida— y tienen que ser las mismas: un producto dado
/// de alta con una unidad que la ficha no ofrece no se puede volver a editar
/// sin cambiarla.
const List<String> productUnits = [
  'unidad',
  'g',
  'kg',
  'ml',
  'L',
  'lata',
  'botella',
  'caja',
  'bolsa',
  'paquete',
];

class Product {
  final String id;
  final String name;
  final String categoryId;
  final String? subcategoryId;
  final String unit;
  final double lastPrice;
  final double priceRefQty;
  final double quantityToMaintain;
  final double currentQuantity;
  final String? lastPlace;
  final String? notes;

  /// Equivalencia por unidad: a cuánto equivale UNA unidad de [unit] expresada
  /// en [packageBaseUnit]. Ejemplo: un producto en 'paquete' que trae 1 kg se
  /// guarda como packageSize 1 y packageBaseUnit 'kg'.
  ///
  /// Permite comparar la despensa con recetas escritas en otra unidad: sin
  /// esto, 2 paquetes frente a una receta que pide 500 g no se pueden cruzar.
  final double? packageSize;
  final String? packageBaseUnit;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields
  final String? categoryName;
  final String? categoryColor;
  final String? subcategoryName;
  final NutritionalValues? nutritionalValues;

  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    this.subcategoryId,
    required this.unit,
    this.lastPrice = 0,
    this.priceRefQty = 1.0,
    this.quantityToMaintain = 1,
    this.currentQuantity = 0,
    this.lastPlace,
    this.notes,
    this.packageSize,
    this.packageBaseUnit,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryColor,
    this.subcategoryName,
    this.nutritionalValues,
  });

  bool get isLow => currentQuantity < quantityToMaintain;
  bool get isOut => currentQuantity <= 0;

  double get pricePerUnit => priceRefQty > 0 ? lastPrice / priceRefQty : lastPrice;

  /// True si el producto declara a cuánto equivale una de sus unidades.
  bool get hasPackageEquivalence =>
      packageSize != null && packageSize! > 0 && packageBaseUnit != null;

  /// La equivalencia que el propio producto declara en su ficha, como arista
  /// para el conversor: una unidad de [unit] son [packageSize] de la base.
  List<UnitEdge> get _packageEdges => hasPackageEquivalence
      ? [
          UnitEdge(
            from: canonicalUnit(unit),
            to: canonicalUnit(packageBaseUnit!),
            factor: packageSize!,
          ),
        ]
      : const [];

  /// Convierte [quantity] de este producto a [targetUnit], con la marca de si
  /// el resultado se apoya en alguna equivalencia estimada.
  ///
  /// Devuelve null a propósito en vez de un número aproximado cuando no hay
  /// forma de afirmarlo: es preferible mostrar "no se sabe" a decirle al
  /// usuario que le falta harina cuando le sobra.
  ///
  /// El encadenado lo resuelve [UnitConverter]: de 'paquete' a 'kg' por lo que
  /// declara la ficha, de 'kg' a 'g' porque es exacto, y de 'g' a 'cucharada'
  /// por lo que se sepa de ese ingrediente en concreto. Sin [converter] solo
  /// se cuenta con el catálogo de referencia, no con lo que haya declarado el
  /// usuario.
  UnitAmount? amountInRecipeUnit(
    double quantity,
    String targetUnit, {
    UnitConverter? converter,
  }) =>
      (converter ?? seededConverter).convert(
        quantity,
        from: unit,
        to: targetUnit,
        productId: id,
        ingredientKey: name,
        extraEdges: _packageEdges,
      );

  /// [amountInRecipeUnit] cuando solo interesa el número.
  double? convertToRecipeUnit(
    double quantity,
    String targetUnit, {
    UnitConverter? converter,
  }) =>
      amountInRecipeUnit(quantity, targetUnit, converter: converter)?.value;

  /// Cuántas unidades de este producto son [quantity] de [recipeUnit].
  ///
  /// Es lo que hace falta para descontar: la receta pide 200 g, la despensa
  /// guarda la harina en kg, y del stock hay que restar 0,2. Devuelve null en
  /// los mismos casos y por la misma razón: restar con un factor inventado
  /// vacía la despensa de golpe, y un error de 1000 aquí es la diferencia
  /// entre un gramo y un kilo.
  UnitAmount? amountInProductUnit(
    double quantity,
    String recipeUnit, {
    UnitConverter? converter,
  }) =>
      (converter ?? seededConverter).convert(
        quantity,
        from: recipeUnit,
        to: unit,
        productId: id,
        ingredientKey: name,
        extraEdges: _packageEdges,
      );

  /// [amountInProductUnit] cuando solo interesa el número.
  double? convertFromRecipeUnit(
    double quantity,
    String recipeUnit, {
    UnitConverter? converter,
  }) =>
      amountInProductUnit(quantity, recipeUnit, converter: converter)?.value;

  double get neededQuantity =>
      isLow ? (quantityToMaintain - currentQuantity) : 0;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      categoryId: map['category_id'] as String,
      subcategoryId: map['subcategory_id'] as String?,
      unit: map['unit'] as String? ?? 'unidad',
      lastPrice: (map['last_price'] as num?)?.toDouble() ?? 0,
      priceRefQty: (map['price_ref_qty'] as num?)?.toDouble() ?? 1.0,
      quantityToMaintain:
          (map['quantity_to_maintain'] as num?)?.toDouble() ?? 1,
      currentQuantity: (map['current_quantity'] as num?)?.toDouble() ?? 0,
      lastPlace: map['last_place'] as String?,
      packageSize: (map['package_size'] as num?)?.toDouble(),
      packageBaseUnit: map['package_base_unit'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      categoryName: map['category_name'] as String?,
      categoryColor: map['category_color'] as String?,
      subcategoryName: map['subcategory_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'unit': unit,
      'last_price': lastPrice,
      'price_ref_qty': priceRefQty,
      'quantity_to_maintain': quantityToMaintain,
      'current_quantity': currentQuantity,
      'last_place': lastPlace,
      'package_size': packageSize,
      'package_base_unit': packageBaseUnit,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? subcategoryId,
    String? unit,
    double? lastPrice,
    double? priceRefQty,
    double? quantityToMaintain,
    double? currentQuantity,
    String? lastPlace,
    double? packageSize,
    String? packageBaseUnit,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryName,
    String? categoryColor,
    String? subcategoryName,
    NutritionalValues? nutritionalValues,
    bool clearSubcategory = false,
    bool clearNutritional = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: clearSubcategory ? null : (subcategoryId ?? this.subcategoryId),
      unit: unit ?? this.unit,
      lastPrice: lastPrice ?? this.lastPrice,
      priceRefQty: priceRefQty ?? this.priceRefQty,
      quantityToMaintain: quantityToMaintain ?? this.quantityToMaintain,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      lastPlace: lastPlace ?? this.lastPlace,
      packageSize: packageSize ?? this.packageSize,
      packageBaseUnit: packageBaseUnit ?? this.packageBaseUnit,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      nutritionalValues: clearNutritional ? null : (nutritionalValues ?? this.nutritionalValues),
    );
  }
}
