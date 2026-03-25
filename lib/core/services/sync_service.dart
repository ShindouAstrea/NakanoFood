import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../database/database_helper.dart';
import '../providers/auth_provider.dart';
import 'image_storage_service.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return SyncService(userId: userId, ref: ref);
});

// ─── Sync status ──────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, error }

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

// ─── SyncService ──────────────────────────────────────────────────────────────

/// Upload order respects foreign key constraints:
/// categories → subcategories → products → recipes → meal_categories
/// → meal_plans → shopping_sessions + their child tables.
const _uploadOrder = [
  'product_categories',
  'product_subcategories',
  'products',
  'nutritional_values',
  'product_price_history',
  'recipes',
  'recipe_ingredients',
  'recipe_steps',
  'recipe_images',
  'recipe_cookings',
  'meal_categories',
  'meal_category_days',
  'meal_plans',
  'meal_plan_items',
  'shopping_sessions',
  'shopping_items',
];

class SyncService {
  final String? userId;
  final Ref ref;

  SyncService({required this.userId, required this.ref});

  SupabaseClient get _client => Supabase.instance.client;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Call after any local write. Uploads pending rows if online.
  void queueSync() {
    if (userId == null || !SupabaseConfig.isConfigured) return;
    _runSync();
  }

  /// Full upload: push all local rows to Supabase (used after login).
  Future<void> fullUpload() async {
    if (userId == null || !SupabaseConfig.isConfigured) return;
    final online = await _isOnline();
    if (!online) return;
    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    try {
      final db = await DatabaseHelper.instance.database;
      await _claimLocalRecords(db, userId!);
      await _uploadPendingImages(db, userId!);
      for (final table in _uploadOrder) {
        await _uploadTable(db, table, userId!);
      }
      ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    } catch (e, st) {
      debugPrint('[SyncService] fullUpload error: $e\n$st');
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
    }
  }

  /// Full download: pull all Supabase rows into local DB (used on new device).
  Future<void> fullDownload() async {
    if (userId == null || !SupabaseConfig.isConfigured) return;
    final online = await _isOnline();
    if (!online) return;
    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    try {
      final db = await DatabaseHelper.instance.database;
      // Download in FK order
      for (final table in _uploadOrder) {
        await _downloadTable(db, table, userId!);
      }
      ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    } catch (e, st) {
      debugPrint('[SyncService] fullDownload error: $e\n$st');
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
    }
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  Future<void> _runSync() async {
    if (userId == null) return;
    final online = await _isOnline();
    if (!online) return;
    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    try {
      final db = await DatabaseHelper.instance.database;
      for (final table in _uploadOrder) {
        await _uploadPending(db, table, userId!);
      }
      ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    } catch (e, st) {
      debugPrint('[SyncService] _runSync error: $e\n$st');
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
    }
  }

  /// Assign user_id to locally-created records that have no user_id yet.
  Future<void> _claimLocalRecords(Database db, String uid) async {
    for (final table in _uploadOrder) {
      if (await _hasColumn(db, table, 'user_id')) {
        await db.execute(
          'UPDATE $table SET user_id = ? WHERE user_id IS NULL',
          [uid],
        );
      }
    }
  }

  /// Upload any local image files to Supabase Storage and replace their paths
  /// with public URLs in the local DB (migration for pre-existing local images).
  Future<void> _uploadPendingImages(Database db, String uid) async {
    // recipe_images table
    final imageRows = await db.query(
      'recipe_images',
      where: "image_path NOT LIKE 'http%' AND (user_id = ? OR user_id IS NULL)",
      whereArgs: [uid],
    );
    for (final row in imageRows) {
      final localPath = row['image_path'] as String;
      final recipeId = row['recipe_id'] as String;
      final id = row['id'] as String;
      final url = await ImageStorageService.uploadImage(
        localPath: localPath,
        userId: uid,
        recipeId: recipeId,
      );
      if (url != null) {
        await db.update(
          'recipe_images',
          {'image_path': url, 'synced_at': null},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    // main_image_path in recipes table
    final recipeRows = await db.query(
      'recipes',
      columns: ['id', 'main_image_path'],
      where:
          "main_image_path IS NOT NULL AND main_image_path NOT LIKE 'http%' AND (user_id = ? OR user_id IS NULL)",
      whereArgs: [uid],
    );
    for (final row in recipeRows) {
      final localPath = row['main_image_path'] as String;
      final recipeId = row['id'] as String;
      final url = await ImageStorageService.uploadImage(
        localPath: localPath,
        userId: uid,
        recipeId: recipeId,
      );
      if (url != null) {
        await db.update(
          'recipes',
          {'main_image_path': url, 'synced_at': null},
          where: 'id = ?',
          whereArgs: [recipeId],
        );
      }
    }
  }

  /// Upload rows where synced_at IS NULL to Supabase (upsert).
  Future<void> _uploadPending(
      Database db, String table, String uid) async {
    if (!await _hasColumn(db, table, 'synced_at')) return;
    final rows = await db.query(
      table,
      where: 'synced_at IS NULL AND (user_id = ? OR user_id IS NULL)',
      whereArgs: [uid],
    );
    if (rows.isEmpty) return;

    // Strip SQLite-only columns that don't exist in Supabase
    final cleaned = rows.map((r) => _prepareForSupabase(r, uid, table)).toList();
    await _client.from(table).upsert(cleaned);

    final now = DateTime.now().toIso8601String();
    await db.execute(
      'UPDATE $table SET synced_at = ? WHERE synced_at IS NULL AND (user_id = ? OR user_id IS NULL)',
      [now, uid],
    );
  }

  /// Upload ALL rows of a table (used during fullUpload).
  Future<void> _uploadTable(Database db, String table, String uid) async {
    if (!await _hasColumn(db, table, 'user_id')) return;
    final rows = await db.query(
      table,
      where: 'user_id = ? OR user_id IS NULL',
      whereArgs: [uid],
    );
    if (rows.isEmpty) return;
    final cleaned = rows.map((r) => _prepareForSupabase(r, uid, table)).toList();
    await _client.from(table).upsert(cleaned);

    if (await _hasColumn(db, table, 'synced_at')) {
      final now = DateTime.now().toIso8601String();
      await db.execute(
        'UPDATE $table SET synced_at = ? WHERE user_id = ?',
        [now, uid],
      );
    }
  }

  /// Download all rows from Supabase and upsert into local DB.
  Future<void> _downloadTable(
      Database db, String table, String uid) async {
    final List<dynamic> rows;
    try {
      rows = await _client.from(table).select().eq('user_id', uid);
    } catch (_) {
      return; // table might not exist in Supabase yet
    }
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row as Map);
      // Mark as synced locally
      map['synced_at'] = DateTime.now().toIso8601String();
      try {
        await db.insert(
          table,
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {
        // Column mismatch — skip this row
      }
    }
  }

  /// Columns that exist in local SQLite (legacy migrations) but NOT in Supabase.
  static const _localOnlyColumns = <String, List<String>>{
    // meal_plans had title + recipe_id before v5 migration; SQLite can't DROP COLUMN
    'meal_plans': ['title', 'recipe_id'],
  };

  Map<String, dynamic> _prepareForSupabase(
      Map<String, dynamic> row, String uid, String table) {
    final map = Map<String, dynamic>.from(row);
    map['user_id'] = uid;
    // Remove local-only sync tracking column before uploading
    map.remove('synced_at');
    // Remove columns that only exist locally (legacy migrations)
    for (final col in (_localOnlyColumns[table] ?? [])) {
      map.remove(col);
    }
    return map;
  }

  Future<bool> _hasColumn(Database db, String table, String column) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.any((col) => col['name'] == column);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
