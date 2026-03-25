class RecipeIngredient {
  final String id;
  final String recipeId;
  final String? productId;
  final String productName;
  final double quantity;
  final String unit;

  // Runtime state
  final double? availableQuantity;
  final bool? isAvailable;

  const RecipeIngredient({
    required this.id,
    required this.recipeId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    this.availableQuantity,
    this.isAvailable,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      id: map['id'] as String,
      recipeId: map['recipe_id'] as String,
      productId: map['product_id'] as String?,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit': unit,
    };
  }

  RecipeIngredient copyWith({
    String? id,
    String? recipeId,
    String? productId,
    String? productName,
    double? quantity,
    String? unit,
    double? availableQuantity,
    bool? isAvailable,
  }) {
    return RecipeIngredient(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class RecipeStep {
  final String id;
  final String recipeId;
  final int stepNumber;
  final String description;

  const RecipeStep({
    required this.id,
    required this.recipeId,
    required this.stepNumber,
    required this.description,
  });

  factory RecipeStep.fromMap(Map<String, dynamic> map) {
    return RecipeStep(
      id: map['id'] as String,
      recipeId: map['recipe_id'] as String,
      stepNumber: map['step_number'] as int,
      description: map['description'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'step_number': stepNumber,
      'description': description,
    };
  }

  RecipeStep copyWith({
    String? id,
    String? recipeId,
    int? stepNumber,
    String? description,
  }) {
    return RecipeStep(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      stepNumber: stepNumber ?? this.stepNumber,
      description: description ?? this.description,
    );
  }
}

const List<String> recipeTypes = [
  'Desayuno',
  'Comida Principal',
  'Cena',
  'Snack',
  'Postre',
  'Pastelería',
  'Ensalada',
  'Sopa',
  'Bebida',
  'Otro',
];

const List<String> commonUnits = [
  'g',
  'kg',
  'ml',
  'L',
  'taza',
  'cucharada',
  'cucharadita',
  'unidad',
  'rodaja',
  'pizca',
  'sobre',
];

const List<String> pantryUnits = [
  'unidad',
  'g',
  'kg',
  'ml',
  'L',
  'lata',
  'botella',
  'caja',
  'bolsa',
  'docena',
  'litro',
  'frasco',
  'paquete',
];

class Recipe {
  final String id;
  final String name;
  final String type;
  final String? description;
  final String? mainImagePath;
  final int portions;
  final int? prepTime;
  final int? cookTime;
  final double estimatedCost;
  final String? notes;
  final int rating; // 0–5
  final int cookCount; // veces cocinada (runtime, cargado desde recipe_cookings)
  final DateTime? lastCookedAt; // última vez cocinada (runtime)
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> imagePaths;

  const Recipe({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.mainImagePath,
    this.portions = 1,
    this.prepTime,
    this.cookTime,
    this.estimatedCost = 0,
    this.notes,
    this.rating = 0,
    this.cookCount = 0,
    this.lastCookedAt,
    required this.createdAt,
    required this.updatedAt,
    this.ingredients = const [],
    this.steps = const [],
    this.imagePaths = const [],
  });

  int get totalTime => (prepTime ?? 0) + (cookTime ?? 0);

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      description: map['description'] as String?,
      mainImagePath: map['main_image_path'] as String?,
      portions: map['portions'] as int? ?? 1,
      prepTime: map['prep_time'] as int?,
      cookTime: map['cook_time'] as int?,
      estimatedCost: (map['estimated_cost'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      rating: map['rating'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'main_image_path': mainImagePath,
      'portions': portions,
      'prep_time': prepTime,
      'cook_time': cookTime,
      'estimated_cost': estimatedCost,
      'notes': notes,
      'rating': rating,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Recipe copyWith({
    String? id,
    String? name,
    String? type,
    String? description,
    String? mainImagePath,
    int? portions,
    int? prepTime,
    int? cookTime,
    double? estimatedCost,
    String? notes,
    int? rating,
    int? cookCount,
    DateTime? lastCookedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RecipeIngredient>? ingredients,
    List<RecipeStep>? steps,
    List<String>? imagePaths,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      mainImagePath: mainImagePath ?? this.mainImagePath,
      portions: portions ?? this.portions,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      notes: notes ?? this.notes,
      rating: rating ?? this.rating,
      cookCount: cookCount ?? this.cookCount,
      lastCookedAt: lastCookedAt ?? this.lastCookedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }
}
