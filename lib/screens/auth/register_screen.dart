import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/stores/user_profile_store.dart';
import '../../services/firebase_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../widgets/profile_image_picker_sheet.dart';
import '../shell/main_navigation_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.isEditMode = false,
    this.initialEmail,
    this.initialPassword,
  });

  final bool isEditMode;
  final String? initialEmail;
  final String? initialPassword;

  static Route<void> route({
    bool isEditMode = false,
    String? email,
    String? password,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          RegisterScreen(
            isEditMode: isEditMode,
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

  /// الصف الدراسي: السابع — التاسع فقط.
  static const List<String> gradeOptions = [
    'الصف السابع',
    'الصف الثامن',
    'الصف التاسع',
  ];

  static const List<String> genderOptions = ['ذكر', 'أنثى'];

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

String _coerceGrade(String saved) {
  if (RegisterScreen.gradeOptions.contains(saved)) return saved;
  for (final g in RegisterScreen.gradeOptions) {
    if (saved.isNotEmpty && (g.contains(saved) || saved.contains(g))) {
      return g;
    }
  }
  return RegisterScreen.gradeOptions.first;
}

String _coerceGender(String saved) {
  if (RegisterScreen.genderOptions.contains(saved)) return saved;
  return RegisterScreen.genderOptions.first;
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _schoolController;
  late final TextEditingController _ageController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _obscurePassword = true;
  late String _selectedGrade;
  late String _gender;

  File? _imageFile;
  bool _isLoading = false;

  static const double _fieldRadius = 16;

  @override
  void initState() {
    super.initState();
    final p = userProfileNotifier.value;
    if (widget.isEditMode) {
      _fullNameController = TextEditingController(text: p.fullName);
      _schoolController = TextEditingController(text: p.school);
      _ageController = TextEditingController(
        text: p.age > 0 ? p.age.toString() : '',
      );
      _emailController = TextEditingController(text: p.email);
      _passwordController = TextEditingController(text: p.pin);
      _confirmPasswordController = TextEditingController(text: p.pin);
      _selectedGrade = _coerceGrade(p.grade);
      _gender = _coerceGender(p.gender);
    } else {
      _fullNameController = TextEditingController();
      _schoolController = TextEditingController();
      _ageController = TextEditingController();
      final currentAuthUser = FirebaseAuth.instance.currentUser;
      final autoEmail = widget.initialEmail ?? currentAuthUser?.email ?? '';
      _emailController = TextEditingController(text: autoEmail);
      _passwordController = TextEditingController(text: widget.initialPassword ?? '');
      _confirmPasswordController = TextEditingController(text: widget.initialPassword ?? '');
      _selectedGrade = RegisterScreen.gradeOptions.first;
      _gender = RegisterScreen.genderOptions.first;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _schoolController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    await ProfileImagePickerSheet.show(context);
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final age = int.parse(_ageController.text.trim());
    final fullName = _fullNameController.text.trim();
    final school = _schoolController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!widget.isEditMode && password != _confirmPasswordController.text.trim()) {
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
      String uid = userProfileNotifier.value.uid;

      if (!widget.isEditMode) {
        final currentUser = firebaseService.currentUser;
        if (currentUser != null && (currentUser.isAnonymous || currentUser.email == email)) {
          createdUser = currentUser;
          uid = createdUser.uid;
          if (currentUser.isAnonymous) {
            try {
              final cred = await currentUser.linkWithCredential(
                EmailAuthProvider.credential(email: email, password: password),
              );
              createdUser = cred.user;
              uid = createdUser?.uid ?? uid;
            } catch (_) {
              final creds = await firebaseService.signUpWithEmailAndPassword(email, password);
              createdUser = creds.user;
              uid = createdUser?.uid ?? '';
            }
          }
        } else {
          // إنشاء حساب جديد بالبريد الإلكتروني وكلمة المرور الحقيقية التي أدخلها المستخدم
          final creds = await firebaseService.signUpWithEmailAndPassword(
            email,
            password,
          );
          createdUser = creds.user;
          uid = createdUser?.uid ?? '';
        }
      }

      String profileImageUrl = userProfileNotifier.value.profileImageUrl;
      if (_imageFile != null) {
        try {
          profileImageUrl = await firebaseService.uploadProfileImage(uid, _imageFile!);
        } catch (e) {
          debugPrint('Error uploading profile image: $e');
        }
      }

      final profile = UserProfile(
        uid: uid,
        fullName: fullName,
        school: school,
        grade: _selectedGrade,
        age: age,
        gender: _gender,
        profileImageUrl: profileImageUrl,
        email: email,
        pin: password.isNotEmpty ? password : userProfileNotifier.value.pin,
      );

      try {
        await saveUserProfile(profile);
      } catch (firestoreError) {
        if (!widget.isEditMode && createdUser != null) {
          await createdUser.delete();
        }
        rethrow;
      }

      if (!mounted) return;

      if (widget.isEditMode) {
        Navigator.of(context).pop();
      } else {
        // ── تهيئة Firebase لمستخدم جديد ──────────────────────────────
        FirebaseSyncService.initializeAllSubjects().ignore();
        FirebaseSyncService.initializeUserProgress(uid).ignore();

        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (context) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'حدث خطأ أثناء إنشاء الحساب.';
      if (e.code == 'email-already-in-use') {
        message = 'هذا البريد الإلكتروني مسجل مسبقاً، يرجى تسجيل الدخول بدلاً من ذلك.';
      } else if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة جداً (يجب أن تكون 6 أحرف أو أكثر).';
      } else if (e.code == 'invalid-email') {
        message = 'صيغة البريد الإلكتروني غير صحيحة.';
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
        SnackBar(content: Text('حدث خطأ: $e', style: GoogleFonts.tajawal())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  OutlineInputBorder _outlineBorder(ColorScheme scheme) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_fieldRadius),
      borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.55)),
    );
  }

  InputDecoration _fieldDecoration(ColorScheme scheme, {required String label, Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.tajawal(),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
      border: _outlineBorder(scheme),
      enabledBorder: _outlineBorder(scheme),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildAvatar(ColorScheme scheme) {
    return Center(
      child: ValueListenableBuilder<UserProfile>(
        valueListenable: userProfileNotifier,
        builder: (context, profile, _) {
          final imageProvider = getProfileImageProvider(profile.profileImageUrl);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.2), width: 2),
                  ),
                  child: ClipOval(
                    child: _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                        : (imageProvider != null
                            ? Image(image: imageProvider, fit: BoxFit.cover)
                            : Icon(Icons.person_rounded, size: 64, color: scheme.onPrimaryContainer)),
                  ),
                ),
              ),
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: Material(
                  color: scheme.primary,
                  elevation: 4,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _pickImage,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.camera_alt_rounded, size: 20, color: scheme.onPrimary),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _genderRadios(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Text(
            'الجنس',
            style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
          ),
        ),
        RadioGroup<String>(
          groupValue: _gender,
          onChanged: (v) { if (v != null) setState(() => _gender = v); },
          child: Row(
            children: RegisterScreen.genderOptions.map((g) {
              return Expanded(
                child: RadioListTile<String>(
                  value: g,
                  title: Text(g, style: GoogleFonts.tajawal(fontSize: 16)),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.isEditMode ? 'تعديل الملف الشخصي' : 'إنشاء حساب جديد',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
        leading: widget.isEditMode || Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          children: [
            _buildAvatar(scheme),
            const SizedBox(height: 32),
            TextFormField(
              controller: _fullNameController,
              decoration: _fieldDecoration(scheme, label: 'الاسم الرباعي', prefix: const Icon(Icons.person_outline_rounded)),
              style: GoogleFonts.tajawal(fontSize: 16),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال الاسم الرباعي';
                if (v.trim().split(RegExp(r'\s+')).length < 4) return 'يرجى كتابة الاسم رباعياً كما هو مطلوب';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              readOnly: widget.isEditMode || (widget.initialEmail != null && widget.initialEmail!.isNotEmpty),
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(
                scheme,
                label: widget.isEditMode || (widget.initialEmail != null && widget.initialEmail!.isNotEmpty)
                    ? 'البريد الإلكتروني (مؤكد)'
                    : 'البريد الإلكتروني',
                prefix: const Icon(Icons.mark_email_read_rounded, color: Colors.green),
                suffix: widget.isEditMode || (widget.initialEmail != null && widget.initialEmail!.isNotEmpty)
                    ? const Icon(Icons.verified_rounded, color: Colors.green)
                    : null,
              ),
              style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!regex.hasMatch(v.trim())) return 'يرجى إدخال بريد إلكتروني صحيح';
                return null;
              },
            ),
            if (!widget.isEditMode) ...[
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
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _schoolController,
              decoration: _fieldDecoration(scheme, label: 'المدرسة', prefix: const Icon(Icons.school_outlined)),
              style: GoogleFonts.tajawal(fontSize: 16),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال اسم المدرسة';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGrade,
                    decoration: _fieldDecoration(scheme, label: 'الصف'),
                    items: RegisterScreen.gradeOptions
                        .map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.tajawal())))
                        .toList(),
                    onChanged: (v) { if (v != null) setState(() => _selectedGrade = v); },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(scheme, label: 'العمر'),
                    style: GoogleFonts.tajawal(fontSize: 16),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال العمر';
                      final age = int.tryParse(v.trim());
                      if (age == null || age < 5 || age > 25) return 'عمر غير منطقي';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _genderRadios(scheme),
            const SizedBox(height: 32),
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
                  widget.isEditMode ? 'حفظ التعديلات' : 'إنشاء الحساب والمتابعة',
                  style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (!widget.isEditMode) ...[
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
          ],
        ),
      ),
    );
  }
}
