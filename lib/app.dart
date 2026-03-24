import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';
import 'core/providers/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/meal_planning/providers/notification_service.dart';
import 'features/pantry/screens/pantry_screen.dart';
import 'features/recipes/screens/recipes_screen.dart';
import 'features/meal_planning/screens/meal_planning_screen.dart';
import 'features/profile/screens/profile_screen.dart';

class NakanoFoodApp extends ConsumerWidget {
  const NakanoFoodApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentColorProvider);

    return MaterialApp(
      title: 'NakanoFood',
      theme: AppTheme.lightTheme(accent),
      darkTheme: AppTheme.darkTheme(accent),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (_) => const MainNavigation(),
        '/login': (_) => const LoginScreen(),
      },
      home: const _AuthGate(),
    );
  }
}

/// Redirects to LoginScreen when Supabase is configured and no user is logged
/// in. Otherwise opens the main app directly (offline-only mode).
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If Supabase not configured → go straight to main app
    if (!SupabaseConfig.isConfigured) return const MainNavigation();

    // Watch the stream so the widget rebuilds on login/logout events
    ref.watch(authStateProvider);

    // currentUserProvider is synchronous — no loading state, no splash freeze
    final user = ref.watch(currentUserProvider);
    if (user != null) return const MainNavigation();
    return const LoginScreen();
  }
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.initialize().catchError((e) {
      debugPrint('[Notifications] init error: $e');
    });
  }

  final List<Widget> _screens = const [
    PantryScreen(),
    RecipesScreen(),
    MealPlanningScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Despensa',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Recetas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Planificación',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
