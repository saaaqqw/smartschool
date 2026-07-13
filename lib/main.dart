import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/locale/locale_notifier.dart';
import 'core/l10n/app_localizations.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/email_link_listener.dart';
import 'screens/shell/main_navigation_screen.dart';
import 'core/theme/theme_notifier.dart';
import 'core/stores/user_profile_store.dart';
import 'core/stores/study_timer_store.dart';
import 'services/firebase_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {}

  await loadUserProfile();
  await loadLocale();

  // ── تهيئة Firebase عند وجود مستخدم مسجّل ────────────────────
  final uid = userProfileNotifier.value.uid;
  if (uid.isNotEmpty) {
    // تهيئة المواد في Firestore (تنشئ المستندات إن لم تكن موجودة)
    FirebaseSyncService.initializeAllSubjects().ignore();

    // تهيئة تقدم الطالب في كل المواد
    FirebaseSyncService.initializeUserProgress(uid).ignore();

    // استعادة حالة المؤقت من آخر جلسة
    _restoreTimerState(uid);
  }

  runApp(const SmartSchoolApp());
}

/// استعادة حالة المؤقت من Firestore عند فتح التطبيق
Future<void> _restoreTimerState(String uid) async {
  try {
    final saved = await FirebaseSyncService.loadTimerState(uid);
    if (saved.isNotEmpty) {
      final seconds = (saved['elapsedSeconds'] as num?)?.toInt() ?? 0;
      final target = (saved['targetMinutes'] as num?)?.toInt() ?? 120;
      studyTimerStore.setTarget(target);
      if (seconds > 0) {
        studyTimerStore.restoreElapsed(Duration(seconds: seconds));
      }
    }
  } catch (_) {}
}


class SmartSchoolApp extends StatelessWidget {
  const SmartSchoolApp({super.key});

  static ThemeData _themedBase(Brightness brightness, Locale locale) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B6B93),
        brightness: brightness,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: base.colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocaleNotifier,
      builder: (context, locale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: appThemeModeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              navigatorKey: appNavigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'المدرسة الذكية',
              locale: locale,
              supportedLocales: const [
                Locale('ar', 'SA'),
                Locale('en', 'US'),
              ],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              themeMode: mode,
              theme: _themedBase(Brightness.light, locale),
              darkTheme: _themedBase(Brightness.dark, locale),
              builder: (context, child) => EmailLinkListener(child: child ?? const SizedBox.shrink()),
              home: (FirebaseAuth.instance.currentUser != null)
                  ? const MainNavigationScreen()
                  : const WelcomeScreen(),
            );
          },
        );
      },
    );
  }
}
