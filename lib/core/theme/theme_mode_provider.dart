import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo de tema de la app. Por defecto: oscuro. `main` lo arranca con el
/// guardado ([ThemeModeStore]) y lo guarda cada vez que cambia.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

abstract final class ThemeModeStore {
  static const _key = 'iris_theme_mode';

  static Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        _ => ThemeMode.dark,
      };
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  static Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode == ThemeMode.light ? 'light' : 'dark');
  }
}
