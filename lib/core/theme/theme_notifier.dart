import 'package:flutter/material.dart';

/// Shared theme mode for [MaterialApp] and [SettingsScreen].
final ValueNotifier<ThemeMode> appThemeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.light);
