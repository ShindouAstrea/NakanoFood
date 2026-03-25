

## Clases del Dominio

### Recetas

#### `Recipe` — `lib/features/recipes/models/recipe.dart`
```dart
class Recipe {
  final String id;
  final String name;
  final String type;               // 'Desayuno', 'Comida Principal', etc.
  final String? description;
  final String? mainImagePath;     // Ruta local o URL remota
  final int portions;              // Default: 1
  final int? prepTime;             // Minutos
  final int? cookTime;             // Minutos
  final double estimatedCost;
  final String? notes;
  final int rating;                // 0–5
  final int cookCount;             // Runtime: desde recipe_cookings
  final DateTime? lastCookedAt;    // Runtime
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> imagePaths;
}
```

#### `RecipeIngredient`
```dart
class RecipeIngredient {
  final String id;
  final String recipeId;
  final String? productId;         // FK a products (opcional)
  final String productName;
  final double quantity;
  final String unit;               // 'g', 'ml', 'taza', etc.
  final double? availableQuantity; // Runtime
  final bool? isAvailable;         // Runtime
}
```

#### `RecipeStep`
```dart
class RecipeStep {
  final String id;
  final String recipeId;
  final int stepNumber;
  final String description;
}
```

#### `RecipeSuggestion` — `lib/features/recipes/models/recipe_suggestion.dart`
```dart
class RecipeSuggestion {
  final String name;
  final String type;
  final String description;
  final int? estimatedMinutes;
  final String? difficulty;        // 'Fácil', 'Medio', 'Difícil'
  final String? reason;
}
```

---

### Despensa

#### `Product` — `lib/features/pantry/models/product.dart`
```dart
class Product {
  final String id;
  final String name;
  final String categoryId;
  final String? subcategoryId;
  final String unit;
  final double lastPrice;
  final double priceRefQty;        // Cantidad de referencia para precio
  final double quantityToMaintain; // Stock objetivo
  final double currentQuantity;    // Stock actual
  final String? lastPlace;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Campos joined
  final String? categoryName;
  final String? categoryColor;
  final String? subcategoryName;
  final NutritionalValues? nutritionalValues;
  // Computed
  bool get isLow;          // currentQuantity < quantityToMaintain
  bool get isOut;          // currentQuantity <= 0
  double get pricePerUnit;
  double get neededQuantity;
}
```

#### `ProductCategory`
```dart
class ProductCategory {
  final String id;
  final String name;
  final bool isCustom;
  final String? icon;              // Nombre de icono Material
  final String? color;             // Hex
  final List<ProductSubcategory> subcategories;
}
```

#### `ProductSubcategory`
```dart
class ProductSubcategory {
  final String id;
  final String categoryId;
  final String name;
}
```

#### `NutritionalValues`
```dart
class NutritionalValues {
  final String id;
  final String productId;          // Relación 1-a-1 con Product
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
}
```

#### `ShoppingSession` — `lib/features/pantry/models/shopping_session.dart`
```dart
enum ShoppingStatus { active, completed, cancelled }

class ShoppingSession {
  final String id;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double totalCost;
  final ShoppingStatus status;
  final String? notes;
  final List<ShoppingItem> items;
  // Computed
  int get purchasedCount;
  int get totalCount;
  double get calculatedTotal;
}
```

#### `ShoppingItem`
```dart
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
  // Computed
  double get effectiveQuantity;
  double get effectivePrice;
  double get totalCost;
}
```

#### `PriceHistoryEntry` — `lib/features/pantry/models/price_history_entry.dart`
```dart
class PriceHistoryEntry {
  final String id;
  final String productId;
  final double price;
  final double priceRefQty;
  final String unit;
  final DateTime purchasedAt;
}
```

---

### Planificación de Comidas

#### `MealPlan` — `lib/features/meal_planning/models/meal_plan.dart`
```dart
class MealPlan {
  final String id;
  final DateTime date;
  final String categoryId;
  final String? notes;
  final List<MealPlanItem> items;
  // Campos joined
  final String? categoryName;
  final String? categoryColor;
  // Computed
  String get displayTitle;
}
```

#### `MealPlanItem` — `lib/features/meal_planning/models/meal_plan_item.dart`
```dart
class MealPlanItem {
  final String id;
  final String mealPlanId;
  final String title;
  final String? recipeId;          // FK opcional a Recipe
  final String? recipeName;
  final int sortOrder;
}
```

#### `MealCategory` — `lib/features/meal_planning/models/meal_category.dart`
```dart
class MealCategory {
  final String id;
  final String name;               // 'Desayuno', 'Almuerzo', etc.
  final String? defaultTime;       // 'HH:mm'
  final String color;              // Hex
  final bool notificationEnabled;
  final int notificationMinutesBefore;
  final bool isCustom;
  final List<int> daysOfWeek;      // Runtime
}
```

---

## Esquema de Base de Datos

**Archivo:** `lib/core/database/database_helper.dart`
**BD:** `nakano_food.db` (SQLite local) | **Versión:** 8

> Todas las tablas incluyen `user_id TEXT`, `updated_at TEXT` y `synced_at TEXT` para sincronización con Supabase.

---

### Despensa

```sql
CREATE TABLE product_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  is_custom INTEGER DEFAULT 0,
  icon TEXT,
  color TEXT,
  user_id TEXT, updated_at TEXT, synced_at TEXT
);

CREATE TABLE product_subcategories (
  id TEXT PRIMARY KEY,
  category_id TEXT NOT NULL,
  name TEXT NOT NULL,
  user_id TEXT, updated_at TEXT, synced_at TEXT,
  FOREIGN KEY (category_id) REFERENCES product_categories(id) ON DELETE CASCADE
);

CREATE TABLE products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category_id TEXT NOT NULL,
  subcategory_id TEXT,
  unit TEXT NOT NULL DEFAULT 'unidad',
  last_price REAL DEFAULT 0,
  price_ref_qty REAL DEFAULT 1.0,
  quantity_to_maintain REAL DEFAULT 1,
  current_quantity REAL DEFAULT 0,
  last_place TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  user_id TEXT, synced_at TEXT,
  FOREIGN KEY (category_id) REFERENCES product_categories(id),
  FOREIGN KEY (subcategory_id) REFERENCES product_subcategories(id)
);

CREATE TABLE nutritional_values (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL UNIQUE,
  serving_size REAL, serving_unit TEXT,
  kcal REAL, carbs REAL, sugars REAL, fiber REAL,
  total_fats REAL, saturated_fats REAL, trans_fats REAL,
  proteins REAL, sodium REAL,
  updated_at TEXT, user_id TEXT, synced_at TEXT,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE TABLE product_price_history (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  price REAL NOT NULL,
  price_ref_qty REAL DEFAULT 1.0,
  unit TEXT NOT NULL,
  purchased_at TEXT NOT NULL,
  updated_at TEXT, user_id TEXT, synced_at TEXT,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);
```

---

### Compras

```sql
CREATE TABLE shopping_sessions (
  id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  completed_at TEXT,
  total_cost REAL DEFAULT 0,
  status TEXT DEFAULT 'active',   -- active | completed | cancelled
  notes TEXT,
  updated_at TEXT, user_id TEXT, synced_at TEXT
);

CREATE TABLE shopping_items (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  planned_quantity REAL NOT NULL,
  actual_quantity REAL,
  unit TEXT NOT NULL,
  planned_price REAL DEFAULT 0,
  actual_price REAL DEFAULT 0,
  is_purchased INTEGER DEFAULT 0,
  category_id TEXT, category_name TEXT,
  subcategory_id TEXT, subcategory_name TEXT,
  last_place TEXT,
  updated_at TEXT, user_id TEXT, synced_at TEXT,
  FOREIGN KEY (session_id) REFERENCES shopping_sessions(id) ON DELETE CASCADE
);
```

---

### Recetas

```sql
CREATE TABLE recipes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  description TEXT,
  main_image_path TEXT,
  portions INTEGER DEFAULT 1,
  prep_time INTEGER,
  cook_time INTEGER,
  estimated_cost REAL DEFAULT 0,
  notes TEXT,
  rating INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  user_id TEXT, synced_at TEXT
);

CREATE TABLE recipe_ingredients (
  id TEXT PRIMARY KEY,
  recipe_id TEXT NOT NULL,
  product_id TEXT,                 -- FK opcional a products
  product_name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL,
  updated_at TEXT, user_id TEXT, synced_at TEXT,
  FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
);

CREATE TABLE recipe_steps (
  id TEXT PRIMARY KEY,
  recipe_id TEXT NOT NULL,
  step_number INTEGER NOT NULL,
  description TEXT NOT NULL,
  updated_at TEXT, user_id TEXT, synced_at TEXT,
  FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
);

CREATE TABLE recipe_images (
  id TEXT PRIMARY KEY,
  recipe_id TEXT NOT NULL,
  image_path TEXT NOT NULL,
  updated_at TEXT, user_id TEXT, synced_at TEXT,
  FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
);

CREATE TABLE recipe_cookings (
  id TEXT PRIMARY KEY,
  recipe_id TEXT NOT NULL,
  cooked_at TEXT NOT NULL,
  updated_at TEXT, user_id TEXT, synced_at TEXT,
  FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
);
```

---

### Planificación

```sql
CREATE TABLE meal_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  default_time TEXT,
  color TEXT DEFAULT '#2E7D32',
  notification_enabled INTEGER DEFAULT 0,
  notification_minutes_before INTEGER DEFAULT 15,
  is_custom INTEGER DEFAULT 0,
  updated_at TEXT, user_id TEXT, synced_at TEXT
);

CREATE TABLE meal_category_days (
  id TEXT PRIMARY KEY,
  category_id TEXT NOT NULL,
  day_of_week INTEGER NOT NULL,   -- 0=Lunes ... 6=Domingo
  updated_at TEXT, user_id TEXT, synced_at TEXT,
  FOREIGN KEY (category_id) REFERENCES meal_categories(id) ON DELETE CASCADE
);

CREATE TABLE meal_plans (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  category_id TEXT NOT NULL,
  notes TEXT,
  updated_at TEXT, user_id TEXT, synced_at TEXT,
  FOREIGN KEY (category_id) REFERENCES meal_categories(id)
);

CREATE TABLE meal_plan_items (
  id TEXT PRIMARY KEY,
  meal_plan_id TEXT NOT NULL,
  title TEXT NOT NULL,
  recipe_id TEXT,                  -- FK opcional a recipes
  sort_order INTEGER DEFAULT 0,
  updated_at TEXT, user_id TEXT, synced_at TEXT,
  FOREIGN KEY (meal_plan_id) REFERENCES meal_plans(id) ON DELETE CASCADE,
  FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE SET NULL
);
```

---

### Datos por Defecto

| Tabla | Registros |
|---|---|
| `product_categories` | Alimentación, Aseo, Hogar |
| `product_subcategories` | Carbohidratos, Lácteos, Proteína, Cereales, Frutas, Vegetales, Aceites |
| `meal_categories` | Desayuno (07:00), Almuerzo (12:00), Cena (19:00), Snack (16:00) |

---

## Servicios

### `SyncService` — `lib/core/services/sync_service.dart`

Sincronización bidireccional SQLite ↔ Supabase.

| Método | Descripción |
|---|---|
| `queueSync()` | Encola sync tras escrituras locales (requiere conexión) |
| `fullUpload()` | Sube toda la data local a Supabase (post-login) |
| `fullDownload()` | Descarga toda la data de Supabase (dispositivo nuevo) |

Orden de upload (respeta FK): `product_categories → subcategories → products → nutritional_values → price_history → recipes → ingredients → steps → images → cookings → meal_categories → category_days → meal_plans → plan_items → shopping_sessions → shopping_items`

### `ImageStorageService` — `lib/core/services/image_storage_service.dart`

| Propiedad | Valor |
|---|---|
| Bucket | `recipe-images` |
| Ruta | `{userId}/{recipeId}/{uuid}.{ext}` |
| Formatos | jpg, jpeg, png, webp |
| Web | Uploads deshabilitados |

---

## Dependencias Principales

| Paquete | Versión | Uso |
|---|---|---|
| `flutter_riverpod` | ^2.5.1 | State management |
| `sqflite` | ^2.3.3+1 | Base de datos local SQLite |
| `supabase_flutter` | ^2.12.0 | Auth y sincronización cloud |
| `go_router` | ^14.2.7 | Navegación |
| `table_calendar` | ^3.1.2 | Calendario semanal |
| `image_picker` | ^1.1.2 | Selección de imágenes |
| `flutter_local_notifications` | ^17.2.2 | Notificaciones push |
| `share_plus` | ^10.1.4 | Exportar recetas |
| `connectivity_plus` | ^7.0.0 | Estado de red |
| `uuid` | ^4.5.0 | Generación de IDs |
| `intl` | ^0.19.0 | Internacionalización |

## Instalación

```bash
flutter pub get
flutter run
```
