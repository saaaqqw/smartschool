import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared theme mode for [MaterialApp] and [SettingsScreen].
final ValueNotifier<ThemeMode> appThemeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.light);

const _kThemeModeKey = 'app_theme_mode';

Future<void> loadTheme() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeModeKey);
    if (saved == 'dark') {
      appThemeModeNotifier.value = ThemeMode.dark;
    } else if (saved == 'light') {
      appThemeModeNotifier.value = ThemeMode.light;
    }
  } catch (_) {}
}

Future<void> setAndSaveThemeMode(ThemeMode mode) async {
  appThemeModeNotifier.value = mode;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  } catch (_) {}
}
