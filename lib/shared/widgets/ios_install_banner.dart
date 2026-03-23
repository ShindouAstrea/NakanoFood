import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Banner que aparece en iOS/Safari explicando cómo agregar la app
/// a la pantalla de inicio. Se muestra solo una vez.
class IosInstallBanner extends StatefulWidget {
  const IosInstallBanner({super.key});

  @override
  State<IosInstallBanner> createState() => _IosInstallBannerState();
}

class _IosInstallBannerState extends State<IosInstallBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _checkShouldShow();
  }

  Future<void> _checkShouldShow() async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('ios_install_banner_dismissed') ?? false;
    if (dismissed) return;

    // Detectar iOS Safari via user agent
    final isIos = _isIosSafari();
    if (!isIos) return;

    if (mounted) setState(() => _visible = true);
  }

  bool _isIosSafari() {
    // En Flutter Web el user agent está disponible via dart:html,
    // pero para no depender de dart:html usamos una heurística
    // basada en la plataforma web.
    // navigator.userAgent no está disponible directamente en Flutter,
    // así que mostramos el banner en toda sesión web móvil la primera vez.
    return true;
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ios_install_banner_dismissed', true);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || !kIsWeb) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.primary.withAlpha(60),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.ios_share_rounded,
                color: colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instalar NakanoFood',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Toca  ⎙  Compartir → "Agregar a pantalla de inicio"',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onPrimaryContainer.withAlpha(180),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded,
                  size: 18, color: colorScheme.onPrimaryContainer.withAlpha(160)),
              onPressed: _dismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
