import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/sync_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isRegister = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authNotifierProvider.notifier);

    if (_isRegister) {
      await notifier.signUpWithEmail(
          _emailCtrl.text.trim(), _passCtrl.text.trim());
    } else {
      await notifier.signInWithEmail(
          _emailCtrl.text.trim(), _passCtrl.text.trim());
    }

    final authState = ref.read(authNotifierProvider);
    if (authState.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(authState.error.toString()),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Trigger sync after successful login
    if (authState.value != null) {
      final sync = ref.read(syncServiceProvider);
      if (_isRegister) {
        // New account: upload local data
        sync.fullUpload();
      } else {
        // Existing account: download from cloud
        sync.fullDownload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / header
                  Icon(Icons.kitchen_rounded,
                      size: 64, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('NakanoFood',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      )),
                  const SizedBox(height: 8),
                  Text(
                    _isRegister ? 'Crear cuenta' : 'Iniciar sesión',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: colorScheme.onSurface.withAlpha(140)),
                  ),
                  const SizedBox(height: 32),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (!v.contains('@')) return 'Correo inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextFormField(
                    controller: _passCtrl,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    obscureText: _obscure,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          authAsync.isLoading ? null : _submit,
                      child: authAsync.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isRegister
                              ? 'Crear cuenta'
                              : 'Iniciar sesión'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle register / login
                  TextButton(
                    onPressed: () =>
                        setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister
                        ? '¿Ya tienes cuenta? Inicia sesión'
                        : '¿No tienes cuenta? Regístrate'),
                  ),

                  const _OrDivider(),

                  // Google Sign-In
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: authAsync.isLoading
                          ? null
                          : () async {
                              await ref
                                  .read(authNotifierProvider.notifier)
                                  .signInWithGoogle();
                              final s = ref.read(authNotifierProvider);
                              if (s.hasError && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(s.error.toString()),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      icon: _GoogleLogo(),
                      label: const Text('Continuar con Google'),
                    ),
                  ),

                  const Divider(height: 32),

                  // Skip (offline only)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed('/home'),
                    icon: const Icon(Icons.wifi_off_rounded, size: 16),
                    label: const Text('Usar sin cuenta (solo local)'),
                    style: TextButton.styleFrom(
                        foregroundColor:
                            colorScheme.onSurface.withAlpha(120)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withAlpha(60);
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('o', style: TextStyle(color: color, fontSize: 13)),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // SVG path del logo de Google usando Canvas
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    // Fondo blanco
    canvas.drawCircle(
      Offset(s / 2, s / 2),
      s / 2,
      Paint()..color = Colors.white,
    );

    // Rojo (arriba)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s * 0.42),
      -1.57, // -90°
      2.09,  // 120°
      false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.22,
    );
    // Azul (derecha)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s * 0.42),
      0.52,
      1.57,
      false,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.22,
    );
    // Amarillo (abajo-izquierda)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s * 0.42),
      2.09,
      1.05,
      false,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.22,
    );
    // Verde (izquierda)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s * 0.42),
      3.14,
      1.05,
      false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.22,
    );

    // Barra horizontal derecha (característica "G")
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = s * 0.22
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(s * 0.5, s * 0.5),
      Offset(s * 0.88, s * 0.5),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
