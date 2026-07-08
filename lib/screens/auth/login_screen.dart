import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/firebase_service.dart';
import '../../core/stores/user_profile_store.dart';
import '../shell/main_navigation_screen.dart';
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
  final _formKey = GlobalKey<FormState>();
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
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      final creds = await _firebaseService.signInWithEmailAndPassword(email, password);
      final uid = creds.user?.uid ?? '';
      
      // Load user profile from Firestore
      final model = await _firebaseService.getUserProfile(uid);
      if (model != null) {
        await saveUserProfile(UserProfile.fromUserModel(model));
      } else if (uid.isNotEmpty) {
        await saveUserProfile(UserProfile(
          uid: uid,
          fullName: '',
          school: '',
          grade: RegisterScreen.gradeOptions.first,
          age: 0,
          gender: RegisterScreen.genderOptions.first,
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'يرجى إكمال ملفك الشخصي من الإعدادات',
                style: GoogleFonts.tajawal(),
              ),
            ),
          );
        }
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

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final creds = await _firebaseService.signInWithGoogle();
      final uid = creds.user?.uid ?? '';
      
      final model = await _firebaseService.getUserProfile(uid);
      if (model != null) {
        await saveUserProfile(UserProfile.fromUserModel(model));
      } else if (uid.isNotEmpty) {
        await saveUserProfile(UserProfile(
          uid: uid,
          fullName: creds.user?.displayName ?? '',
          school: '',
          grade: RegisterScreen.gradeOptions.first,
          age: 0,
          gender: RegisterScreen.genderOptions.first,
          profileImageUrl: creds.user?.photoURL ?? '',
        ));
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (context) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تسجيل الدخول بواسطة جوجل: $e', style: GoogleFonts.tajawal())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration(ColorScheme scheme, {required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.tajawal(color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
      prefixIcon: Icon(icon, color: scheme.primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: scheme.surface.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      body: Stack(
        children: [
          // خلفية متدرجة متناسقة مع شاشة الترحيب
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        scheme.surfaceContainerLowest,
                        scheme.primaryContainer.withValues(alpha: 0.15),
                        scheme.surfaceContainerHigh,
                      ]
                    : [
                        scheme.primary.withValues(alpha: 0.08),
                        scheme.surface,
                        scheme.primaryContainer.withValues(alpha: 0.12),
                      ],
              ),
            ),
          ),
          
          // دوائر جمالية ناعمة في الخلفية
          Positioned(
            top: -size.height * 0.1,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.5,
              height: size.width * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.05,
            right: -size.width * 0.1,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondary.withValues(alpha: 0.04),
              ),
            ),
          ),

          // المحتوى الأساسي
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // الأيقونة العلوية مع لمسة جمالية
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_person_rounded,
                          size: 64,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // عنوان الشاشة
                      Text(
                        'مرحباً بك مجدداً!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'قم بتسجيل الدخول لمتابعة رحلتك التعليمية.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // بطاقة النموذج الزجاجية
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.black.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            // حقل البريد الإلكتروني
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _fieldDecoration(scheme, label: 'البريد الإلكتروني', icon: Icons.email_outlined),
                              style: GoogleFonts.tajawal(fontSize: 16),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                                final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                if (!regex.hasMatch(v.trim())) return 'يرجى إدخال بريد إلكتروني صحيح';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            
                            // حقل كلمة المرور
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: _fieldDecoration(
                                scheme,
                                label: 'كلمة المرور',
                                icon: Icons.lock_outline_rounded,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // أزرار العمليات
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        // زر تسجيل الدخول الأساسي
                        FilledButton(
                          onPressed: _login,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            'تسجيل الدخول',
                            style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // زر تسجيل الدخول بواسطة جوجل
                        OutlinedButton.icon(
                          onPressed: _loginWithGoogle,
                          icon: Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                            height: 22,
                            errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, size: 28),
                          ),
                          label: Text(
                            'تسجيل الدخول بواسطة Google',
                            style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: scheme.outline.withValues(alpha: 0.25)),
                            backgroundColor: isDark 
                                ? Colors.white.withValues(alpha: 0.04) 
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // السؤال والرابط لإنشاء حساب جديد
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ليس لديك حساب؟',
                            style: GoogleFonts.tajawal(
                              color: scheme.onSurfaceVariant,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(RegisterScreen.route(
                                email: _emailController.text.trim(),
                                password: _passwordController.text.trim(),
                              ));
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: Text(
                              'إنشاء حساب جديد',
                              style: GoogleFonts.tajawal(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
