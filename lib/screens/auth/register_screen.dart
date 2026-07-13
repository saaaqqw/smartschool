import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/stores/user_profile_store.dart';
import '../../services/firebase_service.dart';
import '../../services/firebase_sync_service.dart';
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
  late String _selectedGrade;
  late String _gender;

  final _picker = ImagePicker();
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
      _selectedGrade = _coerceGrade(p.grade);
      _gender = _coerceGender(p.gender);
    } else {
      _fullNameController = TextEditingController();
      _schoolController = TextEditingController();
      _ageController = TextEditingController();
      final currentAuthUser = FirebaseAuth.instance.currentUser;
      final autoEmail = widget.initialEmail ?? currentAuthUser?.email ?? '';
      _emailController = TextEditingController(text: autoEmail);
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
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
      );
      if (picked != null) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final age = int.parse(_ageController.text.trim());
    final fullName = _fullNameController.text.trim();
    final school = _schoolController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    User? createdUser;
    try {
      final firebaseService = FirebaseService();
      String uid = userProfileNotifier.value.uid;

      if (!widget.isEditMode) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          createdUser = currentUser;
          uid = createdUser.uid;
        } else {
          // إذا لم يكن هناك مستخدم مسجل الدخول، يتم إنشاء حساب بكلمة مرور عشوائية أو مجهول
          final creds = await firebaseService.signUpWithEmailAndPassword(
            email,
            'Pass_${DateTime.now().millisecondsSinceEpoch}',
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
                  : (userProfileNotifier.value.profileImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: userProfileNotifier.value.profileImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (context, url, error) => Icon(Icons.person_rounded, size: 64, color: scheme.onPrimaryContainer),
                        )
                      : Icon(Icons.person_rounded, size: 64, color: scheme.onPrimaryContainer)),
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
              readOnly: _emailController.text.isNotEmpty,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(
                scheme,
                label: 'البريد الإلكتروني (مؤكد تلقائياً)',
                prefix: const Icon(Icons.mark_email_read_rounded, color: Colors.green),
                suffix: _emailController.text.isNotEmpty
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
