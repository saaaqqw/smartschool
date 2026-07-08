import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'settings': 'Settings',
      'language': 'Language',
      'change_language': 'Change Language',
      'dark_mode': 'Dark Mode',
      'notifications': 'Notifications',
      'help_center': 'Help Center',
      'terms_of_service': 'Terms of Service',
      'team': 'Working Team',
      'logout': 'Logout',
      'version': 'Smart School — Version 1.0.0',
      'subjects': 'Subjects',
      'dashboard': 'Dashboard',
      'today_plan': 'Today Plan',
      'completed': 'Completed',
      'quick_actions': 'Quick Actions',
      'start_study': 'Start Study',
      'grades': 'Grades',
      'review': 'Review',
      'ai_assistant': 'AI Assistant',
      'welcome_back': 'Welcome back,',
      'grade': 'Grade:',
      'account': 'Account',
      'support': 'Support',
    },
    'ar': {
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'change_language': 'تغيير اللغة',
      'dark_mode': 'الوضع الليلي',
      'notifications': 'الإشعارات',
      'help_center': 'مركز المساعدة',
      'terms_of_service': 'شروط الخدمة',
      'team': 'فريق العمل',
      'logout': 'تسجيل الخروج',
      'version': 'المدرسة الذكية — الإصدار 1.0.0',
      'subjects': 'المواد الدراسية',
      'dashboard': 'لوحة التحكم',
      'today_plan': 'خطة اليوم',
      'completed': 'تم الإنجاز',
      'quick_actions': 'اختصارات سريعة',
      'start_study': 'بدء الدراسة',
      'grades': 'الدرجات',
      'review': 'المراجعة',
      'ai_assistant': 'مساعد AI',
      'welcome_back': 'مرحباً بك يا',
      'grade': 'الصف:',
      'account': 'الحساب',
      'support': 'الدعم',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
