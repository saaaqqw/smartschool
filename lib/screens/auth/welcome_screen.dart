import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'register_screen.dart';
import 'login_screen.dart';

/// شاشة الترحيب — نقطة الدخول قبل التسجيل.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            children: [
              const Spacer(flex: 1),
              Icon(
                Icons.school_rounded,
                size: 88,
                color: scheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'المدرسة الذكية',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'منصة بسيطة لمتابعة دراستك وخططك اليومية.',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: () {
                   Navigator.of(context).push(LoginScreen.route());
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'تسجيل الدخول',
                  style: GoogleFonts.tajawal(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(RegisterScreen.route());
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'إنشاء حساب جديد',
                  style: GoogleFonts.tajawal(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
