import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _loaderAnim;

  static const String _appVersion = '2.0.1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _loaderAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0288D1),
              Color(0xFF29B6F6),
              Color(0xFF01579B),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Centro: logo + nombre
              Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo con sombra
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(100),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Image.asset(
                              'assets/icon/NakanoFood.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF388E3C),
                                child: const Icon(
                                  Icons.kitchen_rounded,
                                  size: 64,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Nombre
                        Text(
                          'NakanoFood',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tu cocina más ordenada',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withAlpha(180),
                                    letterSpacing: 0.5,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Parte inferior: loader + versión
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: FadeTransition(
                    opacity: _loaderAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 160,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white.withAlpha(40),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'v$_appVersion',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withAlpha(120),
                                    letterSpacing: 1.5,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
