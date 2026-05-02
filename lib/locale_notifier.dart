import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLocaleKey = 'app_locale';

final ValueNotifier<Locale> appLocaleNotifier = ValueNotifier<Locale>(const Locale('ar', 'SA'));

Future<void> loadLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final localeCode = prefs.getString(_kLocaleKey);
  if (localeCode != null) {
    if (localeCode == 'en') {
      appLocaleNotifier.value = const Locale('en', 'US');
    } else {
      appLocaleNotifier.value = const Locale('ar', 'SA');
    }
  }
}

Future<void> updateLocale(Locale locale) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLocaleKey, locale.languageCode);
  appLocaleNotifier.value = locale;
}
