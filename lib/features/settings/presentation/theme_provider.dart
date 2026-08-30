import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MunibThemePreference { system, light, dark }

class ThemeProvider with ChangeNotifier {
  static const _key = 'themePreference';
  MunibThemePreference _preference = MunibThemePreference.system;

  ThemeProvider() {
    _load();
  }

  MunibThemePreference get preference => _preference;

  ThemeMode get themeMode {
    switch (_preference) {
      case MunibThemePreference.light:
        return ThemeMode.light;
      case MunibThemePreference.dark:
        return ThemeMode.dark;
      case MunibThemePreference.system:
        return ThemeMode.system;
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    _preference = MunibThemePreference.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => MunibThemePreference.system,
    );
    notifyListeners();
  }

  Future<void> setPreference(MunibThemePreference value) async {
    _preference = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
    notifyListeners();
  }
}
