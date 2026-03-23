import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

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
}
