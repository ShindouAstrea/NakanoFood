import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/providers/auth_provider.dart';
import 'core/services/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/meal_planning/providers/notification_service.dart';
import 'features/pantry/screens/pantry_screen.dart';
import 'features/recipes/screens/recipes_screen.dart';
import 'features/meal_planning/screens/meal_planning_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'shared/widgets/splash_screen.dart';

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

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) return const SplashScreen();

    if (!SupabaseConfig.isConfigured) return const MainNavigation();

    // Dispara fullDownload al iniciar sesión (email o Google) en cualquier dispositivo.
    // Se filtra solo el evento signedIn para no re-descargar en cada reinicio de app.
    ref.listen(authStateProvider, (_, next) {
      next.whenData((authState) {
        if (authState.event == AuthChangeEvent.signedIn) {
          ref.read(initialSyncProvider.notifier).state = true;
          ref.read(syncServiceProvider).fullDownload();
        }
      });
    });

    final user = ref.watch(currentUserProvider);
    final isInitialSyncing = ref.watch(initialSyncProvider);

    if (user != null) {
      if (isInitialSyncing) return const _InitialSyncScreen();
      return const MainNavigation();
    }
    return const LoginScreen();
  }
}

class _InitialSyncScreen extends StatelessWidget {
  const _InitialSyncScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_download_outlined, size: 64, color: cs.primary),
            const SizedBox(height: 24),
            Text('Sincronizando tus datos',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Esto puede tomar unos segundos...',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurface.withAlpha(140)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                backgroundColor: cs.surfaceContainerHighest,
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
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
