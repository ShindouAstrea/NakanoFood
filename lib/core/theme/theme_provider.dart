import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── ThemeMode ────────────────────────────────────────────────────────────────

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == 'dark') {
      state = ThemeMode.dark;
    } else if (value == 'light') {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

// ── Accent color ─────────────────────────────────────────────────────────────

/// Colores de énfasis disponibles en la aplicación.
class AccentOption {
  final String name;
  final Color color;
  const AccentOption(this.name, this.color);
}

const List<AccentOption> accentOptions = [
  AccentOption('Verde',    Color(0xFF2E7D32)),
  AccentOption('Esmeralda',Color(0xFF00695C)),
  AccentOption('Cyan',     Color(0xFF00838F)),
  AccentOption('Azul',     Color(0xFF1565C0)),
  AccentOption('Índigo',   Color(0xFF283593)),
  AccentOption('Púrpura',  Color(0xFF6A1B9A)),
  AccentOption('Violeta',  Color(0xFF4527A0)),
  AccentOption('Rosado',   Color(0xFFC2185B)),
  AccentOption('Rosa',     Color(0xFFAD1457)),
  AccentOption('Rojo',     Color(0xFFC62828)),
  AccentOption('Naranja',  Color(0xFFE64A19)),
  AccentOption('Mostaza',  Color(0xFFF57F17)),
  AccentOption('Oliva',    Color(0xFF827717)),
  AccentOption('Marrón',   Color(0xFF4E342E)),
  AccentOption('Gris azul',Color(0xFF37474F)),
];

final accentColorProvider =
    StateNotifierProvider<AccentColorNotifier, Color>((ref) {
  return AccentColorNotifier();
});

class AccentColorNotifier extends StateNotifier<Color> {
  static const _key = 'accent_color';
  static const _defaultColor = Color(0xFF1565C0);

  AccentColorNotifier() : super(_defaultColor) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_key);
    if (value != null) {
      state = Color(value);
    }
  }

  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, color.toARGB32());
  }
}
