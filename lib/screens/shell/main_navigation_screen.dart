import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/dashboard_screen.dart';
import '../grades/grades_screen.dart';
import '../settings/settings_screen.dart';
import '../study/plan_screen.dart';
import '../subjects/subjects_screen.dart';
import '../../core/l10n/app_localizations.dart';

/// الحاوية الرئيسية: شريط سفلي + تمرير أفقي بين 5 شاشات.
///
/// ترتيب ثابت من **اليسار إلى اليمين**: 0 الرئيسية → 1 المواد → 2 الخطة →
/// 3 الدرجات → 4 الإعدادات (يُفرض اتجاه LTR للتنقل رغم RTL التطبيق).
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  static const Duration _pageAnimDuration = Duration(milliseconds: 340);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (index < 0 || index > 4) return;
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
    _pageController.animateToPage(
      index,
      duration: _pageAnimDuration,
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            AppLocalizations.of(context).translate('confirm_exit'),
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Text(
            AppLocalizations.of(context).translate('exit_warning'),
            style: GoogleFonts.tajawal(
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                AppLocalizations.of(context).translate('no'),
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppLocalizations.of(context).translate('yes'),
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // فهرس 0 = أقصى اليسار … 4 = أقصى اليمين (محور LTR للصفحات).
    final pages = <Widget>[
      DashboardScreen(onNavigateToPage: _goToPage),
      const SubjectsScreen(),
      const PlanScreen(),
      const GradesScreen(),
      const SettingsScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          reverse: false,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: scheme.primary,
          unselectedItemColor: scheme.onSurfaceVariant,
          selectedLabelStyle: GoogleFonts.tajawal(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.tajawal(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          onTap: _goToPage,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded, size: 28),
              label: AppLocalizations.of(context).translate('nav_home'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              activeIcon: Icon(Icons.menu_book_rounded, size: 28),
              label: AppLocalizations.of(context).translate('nav_subjects'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_rounded),
              activeIcon: Icon(Icons.event_note_rounded, size: 28),
              label: AppLocalizations.of(context).translate('nav_plan'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              activeIcon: Icon(Icons.bar_chart_rounded, size: 28),
              label: AppLocalizations.of(context).translate('nav_grades'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              activeIcon: Icon(Icons.settings_rounded, size: 28),
              label: AppLocalizations.of(context).translate('nav_settings'),
            ),
          ],
        ),
      ),
    );
  }
}
