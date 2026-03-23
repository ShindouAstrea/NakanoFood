import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../database/database_helper.dart';

// ─── Current user ─────────────────────────────────────────────────────────────

final currentUserProvider = Provider<User?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return Supabase.instance.client.auth.currentUser;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  if (!SupabaseConfig.isConfigured) return const Stream.empty();
  return Supabase.instance.client.auth.onAuthStateChange;
});

// ─── Auth notifier ────────────────────────────────────────────────────────────

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    if (!SupabaseConfig.isConfigured) return null;
    ref.watch(authStateProvider);
    return Supabase.instance.client.auth.currentUser;
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.user;
    });
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      return res.user;
    });
  }

  /// Abre el flujo OAuth de Google.
  /// - Web: abre un popup en el mismo tab.
  /// - Android: abre Chrome Custom Tab y vuelve via deep link.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? null // Supabase maneja el redirect en web automáticamente
            : 'io.supabase.nakanofood://login-callback',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      // supabase_flutter handles the deep link internally via its own app_links
      // subscription. The auth state updates via onAuthStateChange which _AuthGate watches.
      return Supabase.instance.client.auth.currentUser;
    });
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = const AsyncData(null);
  }

  /// Elimina todos los datos del usuario en Supabase (via CASCADE desde auth.users)
  /// y borra la base de datos local. No reversible.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    try {
      // 1. Borrar cuenta + datos en Supabase (CASCADE borra todas las tablas)
      await Supabase.instance.client.rpc('delete_user_account');
    } catch (e) {
      debugPrint('[Auth] deleteAccount Supabase error: $e');
    }
    try {
      // 2. Limpiar base de datos local
      final db = await DatabaseHelper.instance.database;
      for (final table in _localTables) {
        await db.delete(table);
      }
    } catch (e) {
      debugPrint('[Auth] deleteAccount local DB error: $e');
    }
    state = const AsyncData(null);
  }
}

const _localTables = [
  'shopping_items',
  'shopping_sessions',
  'meal_plan_items',
  'meal_plans',
  'meal_category_days',
  'meal_categories',
  'recipe_images',
  'recipe_steps',
  'recipe_ingredients',
  'recipes',
  'product_price_history',
  'nutritional_values',
  'products',
  'product_subcategories',
  'product_categories',
];
