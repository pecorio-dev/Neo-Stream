import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider pour gérer le thème de l'application (clair/sombre)
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';

  // Thème par défaut : sombre (reposant pour les yeux).
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isSystem => _themeMode == ThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);

      if (savedTheme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedTheme,
          orElse: () => ThemeMode.dark,
        );
        notifyListeners();
      }
    } catch (e) {
      // Utiliser le thème par défaut en cas d'erreur
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.toString());
    } catch (e) {
      // Erreur silencieuse pour ne pas bloquer l'UI
    }
  }

  Future<void> toggleTheme() async {
    final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  Future<void> setDark() => setThemeMode(ThemeMode.dark);
  Future<void> setLight() => setThemeMode(ThemeMode.light);
  Future<void> setSystem() => setThemeMode(ThemeMode.system);
}
