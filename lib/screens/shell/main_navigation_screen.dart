import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/dashboard_screen.dart';
import '../grades/grades_screen.dart';
import '../study/plan_screen.dart';
import '../settings/settings_screen.dart';
import '../subjects/subjects_screen.dart';

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

    return Scaffold(
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            activeIcon: Icon(Icons.home_rounded, size: 28),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            activeIcon: Icon(Icons.menu_book_rounded, size: 28),
            label: 'المواد',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_rounded),
            activeIcon: Icon(Icons.event_note_rounded, size: 28),
            label: 'الخطة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            activeIcon: Icon(Icons.bar_chart_rounded, size: 28),
            label: 'الدرجات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            activeIcon: Icon(Icons.settings_rounded, size: 28),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
