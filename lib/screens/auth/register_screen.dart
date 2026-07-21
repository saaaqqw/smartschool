import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/stores/user_profile_store.dart';
import '../../services/firebase_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.initialEmail,
    this.initialPassword,
  });

  final String? initialEmail;
  final String? initialPassword;

  static Route<void> route({
    String? email,
    String? password,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          RegisterScreen(
            initialEmail: email,
            initialPassword: password,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
    );
  }

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _obscurePassword = true;

  bool _isLoading = false;
  static const double _fieldRadius = 16;

  @override
  void initState() {
    super.initState();
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    final autoEmail = widget.initialEmail ?? currentAuthUser?.email ?? '';
    _emailController = TextEditingController(text: autoEmail);
    _passwordController = TextEditingController(text: widget.initialPassword ?? '');
    _confirmPasswordController = TextEditingController(text: widget.initialPassword ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (password != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('كلمة المرور وتأكيد كلمة المرور غير متطابقين', style: GoogleFonts.tajawal()),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    User? createdUser;
    try {
      final firebaseService = FirebaseService();

      final currentUser = firebaseService.currentUser;
      if (currentUser != null && (currentUser.isAnonymous || currentUser.email == email)) {
        createdUser = currentUser;
        if (currentUser.isAnonymous) {
          try {
            final cred = await currentUser.linkWithCredential(
              EmailAuthProvider.credential(email: email, password: password),
            );
            createdUser = cred.user;
          } catch (_) {
            final creds = await firebaseService.signUpWithEmailAndPassword(email, password);
            createdUser = creds.user;
          }
        }
      } else {
        // إنشاء حساب جديد
        final creds = await firebaseService.signUpWithEmailAndPassword(
          email,
          password,
        );
        createdUser = creds.user;
      }

      // ── إرسال رابط التفعيل للبريد الإلكتروني ───────────────────────
      if (createdUser != null && !createdUser.emailVerified) {
        await createdUser.sendEmailVerification();
      }

      // حفظ بيانات أولوية في Local Cache كـ uid و pin فقط، الباقي سيتم تعبئته في شاشة Onboarding
      final profile = UserProfile(
        uid: createdUser?.uid ?? '',
        fullName: '',
        school: '',
        grade: 'الصف السابع', // Default placeholder
        age: 0,
        gender: 'ذكر', // Default placeholder
        email: email,
        pin: password,
      );
      
      // لا نحفظها في Firestore بعد، سيتم الحفظ بعد Onboarding
      userProfileNotifier.value = profile;

      if (!mounted) return;

      // العودة لشاشة تسجيل الدخول لإخباره بتفعيل بريده
      Navigator.of(context).pushReplacement(LoginScreen.route(showVerificationMessage: true));

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'حدث خطأ أثناء إنشاء الحساب.';
      if (e.code == 'email-already-in-use') {
        message = 'البريد الإلكتروني مسجل مسبقاً.';
      } else if (e.code == 'invalid-email') {
        message = 'صيغة البريد الإلكتروني غير صحيحة.';
      } else if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة جداً.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.tajawal()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل التسجيل: $e', style: GoogleFonts.tajawal()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration(ColorScheme scheme, {required String label, Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.tajawal(color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
      prefixIcon: prefix != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: prefix,
            )
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      suffixIcon: suffix,
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.error),
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
        title: Text(
          'إنشاء حساب جديد',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
          children: [
            Text(
              'خطوتك الأولى للتفوق! 🌟',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w900, color: scheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'سجل بريدك الإلكتروني لإنشاء حسابك بسرعة',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 48),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(
                scheme,
                label: 'البريد الإلكتروني',
                prefix: const Icon(Icons.email_outlined),
              ),
              style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!regex.hasMatch(v.trim())) return 'يرجى إدخال بريد إلكتروني صحيح';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _fieldDecoration(
                scheme,
                label: 'كلمة المرور (6 أحرف أو أكثر)',
                prefix: const Icon(Icons.lock_outline_rounded),
                suffix: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              style: GoogleFonts.tajawal(fontSize: 16),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال كلمة المرور';
                if (v.trim().length < 6) return 'كلمة المرور يجب أن لا تقل عن 6 خانات';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              decoration: _fieldDecoration(
                scheme,
                label: 'تأكيد كلمة المرور',
                prefix: const Icon(Icons.lock_reset_rounded),
              ),
              style: GoogleFonts.tajawal(fontSize: 16),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى تأكيد كلمة المرور';
                if (v.trim() != _passwordController.text.trim()) return 'كلمتا المرور غير متطابقتين';
                return null;
              },
            ),
            const SizedBox(height: 48),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_fieldRadius)),
                ),
                child: Text(
                  'إنشاء الحساب',
                  style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(LoginScreen.route());
                },
                child: Text(
                  'لديك حساب بالفعل؟ تسجيل الدخول',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
