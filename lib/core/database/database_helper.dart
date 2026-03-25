import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nakano_food.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // On web, getDatabasesPath() is not available — just use the filename.
    // sqflite_common_ffi_web persists it in IndexedDB automatically.
    final path = kIsWeb
        ? filePath
        : join(await getDatabasesPath(), filePath);
    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE shopping_items ADD COLUMN subcategory_id TEXT');
      await db.execute(
          'ALTER TABLE shopping_items ADD COLUMN subcategory_name TEXT');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE products ADD COLUMN price_ref_qty REAL DEFAULT 1.0');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_price_history (
          id TEXT PRIMARY KEY,
          product_id TEXT NOT NULL,
          price REAL NOT NULL,
          price_ref_qty REAL DEFAULT 1.0,
          unit TEXT NOT NULL,
          purchased_at TEXT NOT NULL,
          FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS meal_plan_items (
          id TEXT PRIMARY KEY,
          meal_plan_id TEXT NOT NULL,
          title TEXT NOT NULL,
          recipe_id TEXT,
          sort_order INTEGER DEFAULT 0,
          FOREIGN KEY (meal_plan_id) REFERENCES meal_plans(id) ON DELETE CASCADE,
          FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE SET NULL
        )
      ''');
      // Migrate existing meal plans: turn title + recipe_id into items
      final plans = await db.query('meal_plans');
      for (final plan in plans) {
        final title = plan['title'] as String?;
        if (title != null && title.isNotEmpty) {
          final itemId =
              'mpi_${(plan['id'] as String).replaceAll('-', '').substring(0, 8)}';
          await db.insert('meal_plan_items', {
            'id': itemId,
            'meal_plan_id': plan['id'],
            'title': title,
            'recipe_id': plan['recipe_id'],
            'sort_order': 0,
          });
        }
      }
    }
    if (oldVersion < 7) {
      // Add missing updated_at to tables that had it in Supabase but not locally
      const missingUpdatedAt = [
        'recipe_ingredients',
        'recipe_steps',
        'recipe_images',
        'nutritional_values',
        'product_price_history',
        'meal_category_days',
      ];
      final now = DateTime.now().toIso8601String();
      for (final table in missingUpdatedAt) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
          await db.execute(
              'UPDATE $table SET updated_at = ? WHERE updated_at IS NULL',
              [now]);
        } catch (_) {}
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute(
            'ALTER TABLE recipes ADD COLUMN rating INTEGER DEFAULT 0');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recipe_cookings (
          id TEXT PRIMARY KEY,
          recipe_id TEXT NOT NULL,
          cooked_at TEXT NOT NULL,
          updated_at TEXT,
          user_id TEXT,
          synced_at TEXT,
          FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 6) {
      // Add sync columns to all root tables
      const syncTables = [
        'product_categories',
        'product_subcategories',
        'products',
        'nutritional_values',
        'product_price_history',
        'recipes',
        'recipe_ingredients',
        'recipe_steps',
        'recipe_images',
        'meal_categories',
        'meal_category_days',
        'meal_plans',
        'meal_plan_items',
        'shopping_sessions',
        'shopping_items',
      ];
      for (final table in syncTables) {
        try {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN user_id TEXT');
        } catch (_) {}
        try {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN synced_at TEXT');
        } catch (_) {}
      }
      // Add updated_at to tables that don't have it
      const needsUpdatedAt = [
        'product_categories',
        'product_subcategories',
        'meal_categories',
        'meal_plans',
        'meal_plan_items',
        'shopping_sessions',
        'shopping_items',
      ];
      for (final table in needsUpdatedAt) {
        try {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN updated_at TEXT');
        } catch (_) {}
      }
      // Set updated_at to now for existing rows
      final now = DateTime.now().toIso8601String();
      for (final table in needsUpdatedAt) {
        try {
          await db
              .execute('UPDATE $table SET updated_at = ? WHERE updated_at IS NULL', [now]);
        } catch (_) {}
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE product_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_custom INTEGER DEFAULT 0,
        icon TEXT,
        color TEXT,
        user_id TEXT,
        updated_at TEXT,
        synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE product_subcategories (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        name TEXT NOT NULL,
        user_id TEXT,
        updated_at TEXT,
        synced_at TEXT,
        FOREIGN KEY (category_id) REFERENCES product_categories(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
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
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (category_id) REFERENCES product_categories(id),
        FOREIGN KEY (subcategory_id) REFERENCES product_subcategories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE nutritional_values (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL UNIQUE,
        serving_size REAL,
        serving_unit TEXT,
        kcal REAL,
        carbs REAL,
        sugars REAL,
        fiber REAL,
        total_fats REAL,
        saturated_fats REAL,
        trans_fats REAL,
        proteins REAL,
        sodium REAL,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_sessions (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        total_cost REAL DEFAULT 0,
        status TEXT DEFAULT 'active',
        notes TEXT,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT
      )
    ''');

    await db.execute('''
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
        category_id TEXT,
        category_name TEXT,
        subcategory_id TEXT,
        subcategory_name TEXT,
        last_place TEXT,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (session_id) REFERENCES shopping_sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
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
        user_id TEXT,
        synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE recipe_cookings (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        cooked_at TEXT NOT NULL,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recipe_ingredients (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recipe_steps (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        step_number INTEGER NOT NULL,
        description TEXT NOT NULL,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recipe_images (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        image_path TEXT NOT NULL,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        default_time TEXT,
        color TEXT DEFAULT '#2E7D32',
        notification_enabled INTEGER DEFAULT 0,
        notification_minutes_before INTEGER DEFAULT 15,
        is_custom INTEGER DEFAULT 0,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_category_days (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (category_id) REFERENCES meal_categories(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_plans (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        category_id TEXT NOT NULL,
        notes TEXT,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (category_id) REFERENCES meal_categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_plan_items (
        id TEXT PRIMARY KEY,
        meal_plan_id TEXT NOT NULL,
        title TEXT NOT NULL,
        recipe_id TEXT,
        sort_order INTEGER DEFAULT 0,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (meal_plan_id) REFERENCES meal_plans(id) ON DELETE CASCADE,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE product_price_history (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        price REAL NOT NULL,
        price_ref_qty REAL DEFAULT 1.0,
        unit TEXT NOT NULL,
        purchased_at TEXT NOT NULL,
        updated_at TEXT,
        user_id TEXT,
        synced_at TEXT,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    await _insertDefaultData(db);
  }

  Future<void> _insertDefaultData(Database db) async {
    // Default product categories
    final categories = [
      {'id': 'cat_alimentacion', 'name': 'Alimentación', 'is_custom': 0, 'icon': 'restaurant', 'color': '#4CAF50'},
      {'id': 'cat_aseo', 'name': 'Aseo', 'is_custom': 0, 'icon': 'cleaning_services', 'color': '#2196F3'},
      {'id': 'cat_hogar', 'name': 'Hogar', 'is_custom': 0, 'icon': 'home', 'color': '#FF9800'},
    ];
    for (final cat in categories) {
      await db.insert('product_categories', cat);
    }

    // Default subcategories for Alimentación
    final subcategories = [
      {'id': 'sub_carbohidratos', 'category_id': 'cat_alimentacion', 'name': 'Carbohidratos'},
      {'id': 'sub_lacteos', 'category_id': 'cat_alimentacion', 'name': 'Lácteos'},
      {'id': 'sub_proteina', 'category_id': 'cat_alimentacion', 'name': 'Proteína'},
      {'id': 'sub_cereales', 'category_id': 'cat_alimentacion', 'name': 'Cereales'},
      {'id': 'sub_frutas', 'category_id': 'cat_alimentacion', 'name': 'Frutas'},
      {'id': 'sub_vegetales', 'category_id': 'cat_alimentacion', 'name': 'Vegetales'},
      {'id': 'sub_aceites', 'category_id': 'cat_alimentacion', 'name': 'Aceites'},
    ];
    for (final sub in subcategories) {
      await db.insert('product_subcategories', sub);
    }

    // Default meal categories
    final mealCategories = [
      {'id': 'meal_desayuno', 'name': 'Desayuno', 'default_time': '07:00', 'color': '#FF9800', 'notification_enabled': 0, 'notification_minutes_before': 15, 'is_custom': 0},
      {'id': 'meal_almuerzo', 'name': 'Almuerzo', 'default_time': '12:00', 'color': '#4CAF50', 'notification_enabled': 0, 'notification_minutes_before': 15, 'is_custom': 0},
      {'id': 'meal_cena', 'name': 'Cena', 'default_time': '19:00', 'color': '#3F51B5', 'notification_enabled': 0, 'notification_minutes_before': 15, 'is_custom': 0},
      {'id': 'meal_snack', 'name': 'Snack', 'default_time': '16:00', 'color': '#E91E63', 'notification_enabled': 0, 'notification_minutes_before': 15, 'is_custom': 0},
    ];
    for (final cat in mealCategories) {
      await db.insert('meal_categories', cat);
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
