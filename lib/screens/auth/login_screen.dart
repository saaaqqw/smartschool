import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firebase_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../core/stores/user_profile_store.dart';
import '../../core/stores/study_timer_store.dart';
import '../shell/main_navigation_screen.dart';
import 'profile_editor_screen.dart';
import 'register_screen.dart';
import '../../services/fcm_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.showVerificationMessage = false});
  final bool showVerificationMessage;

  static Route<void> route({bool showVerificationMessage = false}) {
    return MaterialPageRoute<void>(builder: (_) => LoginScreen(showVerificationMessage: showVerificationMessage));
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
  bool _isPasswordlessMode = false; // الوضع الافتراضي: تسجيل الدخول بكلمة المرور

  @override
  void initState() {
    super.initState();
    if (widget.showVerificationMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء الحساب! يرجى مراجعة بريدك الإلكتروني والضغط على رابط التفعيل قبل تسجيل الدخول.', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.blue.shade700,
            duration: const Duration(seconds: 8),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendEmailLink() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    try {
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://saqer1-448ea.firebaseapp.com/login',
        handleCodeInApp: true,
        androidPackageName: 'com.example.smart_school1',
        androidInstallApp: true,
        androidMinimumVersion: '1',
      );

      await _firebaseService.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      if (!mounted) return;
      _showEmailSentDialog(email);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إرسال رابط التحقق: $e', style: GoogleFonts.tajawal())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmailSentDialog(String email) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Colors.green, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تم إرسال رابط التحقق!',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أرسلنا رابط التحقق المباشر إلى بريدك الإلكتروني:',
                style: GoogleFonts.tajawal(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  email,
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'يرجى فتح بريدك الإلكتروني والضغط على الرابط ليتم تفعيل حسابك ونقلك تلقائياً دون الحاجة لأي رمز.',
                style: GoogleFonts.tajawal(fontSize: 13, height: 1.5, color: Colors.grey.shade700),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('حسناً، فهمت', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// إرسال بريد إعادة تعيين كلمة المرور
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('أدخل بريدك الإلكتروني أولاً', style: GoogleFonts.tajawal()),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال رابط إعادة تعيين كلمة المرور إلى $email', style: GoogleFonts.tajawal()),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر الإرسال. تحقق من البريد الإلكتروني.', style: GoogleFonts.tajawal()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _loginWithPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      final creds = await _firebaseService.signInWithEmailAndPassword(email, password);
      
      // ── التحقق من تفعيل البريد الإلكتروني ───────────────────────
      if (creds.user != null && !creds.user!.emailVerified) {
        await _firebaseService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حسابك غير مفعل! يرجى مراجعة صندوق الوارد والضغط على رابط التفعيل.', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final uid = creds.user?.uid ?? '';
      
      // Load user profile from Firestore
      final model = await _firebaseService.getUserProfile(uid);
      bool isProfileIncomplete = false;

      if (model != null) {
        final profile = UserProfile.fromUserModel(model).copyWith(
          email: model.email.isNotEmpty ? model.email : email,
          pin: model.pin.isNotEmpty ? model.pin : password,
        );
        await saveUserProfile(profile);
        isProfileIncomplete = profile.fullName.trim().isEmpty;
      } else if (uid.isNotEmpty) {
        await saveUserProfile(UserProfile(
          uid: uid,
          fullName: '',
          school: '',
          grade: ProfileEditorScreen.gradeOptions.first,
          age: 0,
          gender: ProfileEditorScreen.genderOptions.first,
          email: email,
          pin: password,
        ));
        isProfileIncomplete = true;
      }

      if (!mounted) return;

      // ── تهيئة Firebase بعد تسجيل الدخول ───────────────────────
      FirebaseSyncService.initializeAllSubjects().ignore();
      FirebaseSyncService.initializeUserProgress(uid).ignore();
      FcmService.saveToken(uid).ignore();

      // استعادة حالة المؤقت من آخر جلسة
      try {
        final saved = await FirebaseSyncService.loadTimerState(uid);
        if (saved.isNotEmpty) {
          final seconds = (saved['elapsedSeconds'] as num?)?.toInt() ?? 0;
          final target = (saved['targetMinutes'] as num?)?.toInt() ?? 120;
          studyTimerStore.setTarget(target);
          if (seconds > 0) studyTimerStore.restoreElapsed(Duration(seconds: seconds));
        }
      } catch (_) {}

      if (!mounted) return;
      
      if (isProfileIncomplete) {
        Navigator.of(context).pushAndRemoveUntil<void>(
          ProfileEditorScreen.route(isOnboarding: true),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (context) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'تعذر تسجيل الدخول، يرجى المحاولة مرة أخرى.';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      } else if (e.code == 'invalid-email') {
        message = 'صيغة البريد الإلكتروني غير صحيحة.';
      } else if (e.code == 'user-disabled') {
        message = 'هذا الحساب معطل.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.tajawal()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تسجيل الدخول: $e', style: GoogleFonts.tajawal()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
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
      bool isProfileIncomplete = false;

      if (model != null) {
        await saveUserProfile(UserProfile.fromUserModel(model));
        isProfileIncomplete = model.fullName.trim().isEmpty;
      } else if (uid.isNotEmpty) {
        await saveUserProfile(UserProfile(
          uid: uid,
          fullName: creds.user?.displayName ?? '',
          school: '',
          grade: ProfileEditorScreen.gradeOptions.first,
          age: 0,
          gender: ProfileEditorScreen.genderOptions.first,
          profileImageUrl: creds.user?.photoURL ?? '',
        ));
        isProfileIncomplete = creds.user?.displayName == null || creds.user!.displayName!.isEmpty;
      }

      if (!mounted) return;

      // ── تهيئة Firebase بعد تسجيل الدخول بجوجل ─────────────────
      FirebaseSyncService.initializeAllSubjects().ignore();
      FirebaseSyncService.initializeUserProgress(uid).ignore();

      try {
        final saved = await FirebaseSyncService.loadTimerState(uid);
        if (saved.isNotEmpty) {
          final seconds = (saved['elapsedSeconds'] as num?)?.toInt() ?? 0;
          final target = (saved['targetMinutes'] as num?)?.toInt() ?? 120;
          studyTimerStore.setTarget(target);
          if (seconds > 0) studyTimerStore.restoreElapsed(Duration(seconds: seconds));
        }
      } catch (_) {}

      if (!mounted) return;
      if (isProfileIncomplete) {
        Navigator.of(context).pushAndRemoveUntil<void>(
          ProfileEditorScreen.route(isOnboarding: true),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (context) => const MainNavigationScreen()),
          (route) => false,
        );
      }
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
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPasswordlessMode ? Icons.mark_email_read_outlined : Icons.lock_person_rounded,
                          size: 64,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Text(
                        _isPasswordlessMode ? 'الدخول السريع عبر الرابط' : 'تسجيل الدخول',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isPasswordlessMode
                            ? 'أدخل بريدك الإلكتروني وسنرسل لك رابطاً سحرياً لتسجيل الدخول فوراً.'
                            : 'أدخل بريدك الإلكتروني وكلمة المرور للوصول إلى حسابك الدراسي.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

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
                            if (!_isPasswordlessMode) ...[
                              const SizedBox(height: 18),
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
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: _forgotPassword,
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: scheme.primary,
                                  ),
                                  child: Text(
                                    'نسيت كلمة المرور؟',
                                    style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // أزرار العمليات
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        FilledButton(
                          onPressed: _isPasswordlessMode ? _sendEmailLink : _loginWithPassword,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            _isPasswordlessMode ? 'إرسال رابط التحقق السريع 🚀' : 'تسجيل الدخول',
                            style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // زر إنشاء حساب جديد البارز
                        if (!_isPasswordlessMode) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(context).push(
                                    RegisterScreen.route(email: _emailController.text.trim()),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add_rounded, color: scheme.primary, size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ليس لديك حساب؟ إنشاء حساب جديد الآن',
                                        style: GoogleFonts.tajawal(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        
                        // زر التبديل بين وضع رابط البريد ووضع كلمة المرور
                        TextButton(
                          onPressed: () {
                            setState(() => _isPasswordlessMode = !_isPasswordlessMode);
                          },
                          child: Text(
                            _isPasswordlessMode
                                ? 'الدخول بواسطة كلمة المرور'
                                : 'الدخول السريع عبر رابط البريد (بدون كلمة مرور)',
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: scheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
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
