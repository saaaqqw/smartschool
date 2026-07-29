import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/locale/locale_notifier.dart';
import 'core/l10n/app_localizations.dart';
import 'screens/auth/welcome_screen.dart';

import 'screens/shell/main_navigation_screen.dart';
import 'core/theme/theme_notifier.dart';
import 'core/stores/user_profile_store.dart';
import 'widgets/global_study_timer_overlay.dart';
import 'widgets/offline_banner.dart';
import 'services/app_startup_service.dart';
import 'services/fcm_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ① Firebase ضروري قبل كل شيء
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ② إعداد Firestore Cache (synchronous — لا يأخذ وقتاً)
  AppStartupService.configureFirestore();

  // ③ تحميل الإعدادات المحلية فقط (SharedPreferences سريعة)
  await Future.wait([
    loadUserProfile(),
    loadLocale(),
    loadTheme(),
  ]);

  // ④ تشغيل التطبيق فوراً — المستخدم يرى الواجهة مباشرة
  runApp(const SmartSchoolApp());

  // ⑤ باقي التهيئة في الخلفية بعد عرض أول frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeInBackground();
  });
}

/// كل العمليات الثقيلة تُنفَّذ بعد ظهور الواجهة
Future<void> _initializeInBackground() async {
  // طلب إذن الإشعارات — لا يحجب الواجهة
  FcmService.initialize().ignore();

  // مراقبة الاتصال
  AppStartupService.initializeConnectivity().ignore();

  // تهيئة بيانات المستخدم
  final uid = userProfileNotifier.value.uid;
  AppStartupService.initializeForUser(uid).ignore();
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
              scaffoldMessengerKey: appScaffoldMessengerKey,
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
              builder: (context, child) => OfflineBanner(
                child: GlobalStudyTimerOverlay(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
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
