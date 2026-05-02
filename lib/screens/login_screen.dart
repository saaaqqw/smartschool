import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/firebase_service.dart';
import '../user_profile_store.dart';
import 'main_navigation_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const LoginScreen());
  }

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firebaseService = FirebaseService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى إدخال البريد الإلكتروني وكلمة المرور', style: GoogleFonts.tajawal())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final creds = await _firebaseService.signInWithEmailAndPassword(email, password);
      final uid = creds.user?.uid ?? '';
      
      // Load user profile from Firestore
      final model = await _firebaseService.getUserProfile(uid);
      if (model != null) {
        final profile = UserProfile.fromUserModel(model);
        userProfileNotifier.value = profile;
        await saveUserProfile(profile);
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (context) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تسجيل الدخول: $e', style: GoogleFonts.tajawal())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration(ColorScheme scheme, {required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.tajawal(),
      prefixIcon: Icon(icon, color: scheme.primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text('تسجيل الدخول', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        children: [
          Icon(Icons.lock_person_rounded, size: 80, color: scheme.primary),
          const SizedBox(height: 24),
          Text(
            'مرحباً بك مجدداً!',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w800, color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بتسجيل الدخول لمتابعة رحلتك التعليمية.',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecoration(scheme, label: 'البريد الإلكتروني', icon: Icons.email_outlined),
            style: GoogleFonts.tajawal(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _fieldDecoration(
              scheme,
              label: 'كلمة المرور',
              icon: Icons.password_rounded,
              suffix: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              ),
            ),
            style: GoogleFonts.tajawal(fontSize: 16),
          ),
          const SizedBox(height: 32),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(
              onPressed: _login,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('تسجيل الدخول', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(RegisterScreen.route());
            },
            child: Text('ليس لديك حساب؟ إنشاء حساب جديد', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
