import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../user_profile_store.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import 'main_navigation_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.isEditMode = false});

  final bool isEditMode;

  static Route<void> route({bool isEditMode = false}) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          RegisterScreen(isEditMode: isEditMode),
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
  late final TextEditingController _fullNameController;
  late final TextEditingController _schoolController;
  late final TextEditingController _ageController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late String _selectedGrade;
  late String _gender;

  final _picker = ImagePicker();
  File? _imageFile;
  bool _isLoading = false;
  bool _obscurePassword = true;

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
      _emailController = TextEditingController();
      _passwordController = TextEditingController();
      _selectedGrade = _coerceGrade(p.grade);
      _gender = _coerceGender(p.gender);
    } else {
      _fullNameController = TextEditingController();
      _schoolController = TextEditingController();
      _ageController = TextEditingController();
      _emailController = TextEditingController();
      _passwordController = TextEditingController();
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
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 1 || age > 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى إدخال عمر صحيح', style: GoogleFonts.tajawal())),
      );
      return;
    }
    final fullName = _fullNameController.text.trim();
    final school = _schoolController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (fullName.isEmpty || school.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى تعبئة الاسم الرباعي واسم المدرسة', style: GoogleFonts.tajawal())),
      );
      return;
    }

    if (!widget.isEditMode && (email.isEmpty || password.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى إدخال البريد الإلكتروني وكلمة المرور لإنشاء الحساب', style: GoogleFonts.tajawal())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firebaseService = FirebaseService();
      String uid = userProfileNotifier.value.uid;

      if (!widget.isEditMode) {
        final creds = await firebaseService.signUpWithEmailAndPassword(email, password);
        uid = creds.user?.uid ?? '';
      }

      String profileImageUrl = userProfileNotifier.value.profileImageUrl;
      if (_imageFile != null) {
        profileImageUrl = await firebaseService.uploadProfileImage(uid, _imageFile!);
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

      await saveUserProfile(profile);

      if (!mounted) return;

      if (widget.isEditMode) {
        Navigator.of(context).pop();
      } else {
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
        Row(
          children: RegisterScreen.genderOptions.map((g) {
            return Expanded(
              child: RadioListTile<String>(
                value: g,
                groupValue: _gender,
                title: Text(g, style: GoogleFonts.tajawal(fontSize: 16)),
                onChanged: (v) { if (v != null) setState(() => _gender = v); },
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        children: [
          _buildAvatar(scheme),
          const SizedBox(height: 32),
          TextField(
            controller: _fullNameController,
            decoration: _fieldDecoration(scheme, label: 'الاسم الرباعي', prefix: const Icon(Icons.person_outline_rounded)),
            style: GoogleFonts.tajawal(fontSize: 16),
          ),
          if (!widget.isEditMode) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(scheme, label: 'البريد الإلكتروني', prefix: const Icon(Icons.email_outlined)),
              style: GoogleFonts.tajawal(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _fieldDecoration(
                scheme,
                label: 'كلمة المرور',
                prefix: const Icon(Icons.password_rounded),
                suffix: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              ),
              style: GoogleFonts.tajawal(fontSize: 16),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _schoolController,
            decoration: _fieldDecoration(scheme, label: 'المدرسة', prefix: const Icon(Icons.school_outlined)),
            style: GoogleFonts.tajawal(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedGrade,
                  decoration: _fieldDecoration(scheme, label: 'الصف'),
                  items: RegisterScreen.gradeOptions
                      .map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.tajawal())))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedGrade = v); },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration(scheme, label: 'العمر'),
                  style: GoogleFonts.tajawal(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _genderRadios(scheme),
          const SizedBox(height: 32),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
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
        ],
      ),
    );
  }
}
