import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/stores/user_profile_store.dart';
import '../../services/firebase_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../widgets/profile_image_picker_sheet.dart';
import '../shell/main_navigation_screen.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({
    super.key,
    this.isOnboarding = false,
  });

  final bool isOnboarding;

  static Route<void> route({bool isOnboarding = false}) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          ProfileEditorScreen(isOnboarding: isOnboarding),
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
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

String _coerceGrade(String saved) {
  if (ProfileEditorScreen.gradeOptions.contains(saved)) return saved;
  for (final g in ProfileEditorScreen.gradeOptions) {
    if (saved.isNotEmpty && (g.contains(saved) || saved.contains(g))) {
      return g;
    }
  }
  return ProfileEditorScreen.gradeOptions.first;
}

String _coerceGender(String saved) {
  if (ProfileEditorScreen.genderOptions.contains(saved)) return saved;
  return ProfileEditorScreen.genderOptions.first;
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _schoolController;
  late final TextEditingController _ageController;
  late String _selectedGrade;
  late String _gender;

  File? _imageFile;
  bool _isLoading = false;

  static const double _fieldRadius = 16;

  @override
  void initState() {
    super.initState();
    final p = userProfileNotifier.value;
    _fullNameController = TextEditingController(text: p.fullName);
    _schoolController = TextEditingController(text: p.school);
    _ageController = TextEditingController(
      text: p.age > 0 ? p.age.toString() : '',
    );
    _selectedGrade = _coerceGrade(p.grade);
    _gender = _coerceGender(p.gender);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _schoolController.dispose();
    _ageController.dispose();
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

    setState(() => _isLoading = true);

    try {
      final firebaseService = FirebaseService();
      String uid = userProfileNotifier.value.uid;

      String profileImageUrl = userProfileNotifier.value.profileImageUrl;
      if (_imageFile != null) {
        try {
          profileImageUrl = await firebaseService.uploadProfileImage(uid, _imageFile!);
        } catch (e) {
          debugPrint('Error uploading profile image: $e');
        }
      }

      final profile = userProfileNotifier.value.copyWith(
        fullName: fullName,
        school: school,
        grade: _selectedGrade,
        age: age,
        gender: _gender,
        profileImageUrl: profileImageUrl,
      );

      await saveUserProfile(profile);

      if (!mounted) return;

      if (!widget.isOnboarding) {
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
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ البيانات: $e', style: GoogleFonts.tajawal()),
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

  Widget _buildAvatar(ColorScheme scheme) {
    final hasImage = _imageFile != null || userProfileNotifier.value.profileImageUrl.isNotEmpty;
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      imageProvider = FileImage(_imageFile!);
    } else if (userProfileNotifier.value.profileImageUrl.isNotEmpty) {
      imageProvider = NetworkImage(userProfileNotifier.value.profileImageUrl);
    }

    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primary.withValues(alpha: 0.2), width: 3),
                boxShadow: [
                  BoxShadow(color: scheme.primary.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 2)
                ],
              ),
              child: CircleAvatar(
                radius: 54,
                backgroundColor: scheme.surfaceContainerHighest,
                backgroundImage: imageProvider,
                child: !hasImage
                    ? Icon(Icons.person_outline_rounded, size: 48, color: scheme.primary.withValues(alpha: 0.5))
                    : null,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: Icon(Icons.camera_alt_rounded, size: 20, color: scheme.onPrimary),
            ),
          ],
        ),
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
          children: ProfileEditorScreen.genderOptions.map((g) {
            return Expanded(
              child: RadioListTile<String>(
                value: g,
                groupValue: _gender,
                onChanged: (v) { if (v != null) setState(() => _gender = v); },
                title: Text(g, style: GoogleFonts.tajawal(fontSize: 16)),
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
          widget.isOnboarding ? 'إعداد الملف الشخصي' : 'تعديل الملف الشخصي',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          children: [
            if (widget.isOnboarding) ...[
              Text(
                'مرحباً بك! 👋',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(fontSize: 24, fontWeight: FontWeight.w900, color: scheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'الرجاء إكمال بياناتك لتهيئة التطبيق وعرض الدروس المناسبة لصفك.',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
            ],
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
                    items: ProfileEditorScreen.gradeOptions
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
            else
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_fieldRadius)),
                ),
                child: Text(
                  widget.isOnboarding ? 'حفظ وبدء التعلم 🚀' : 'حفظ التعديلات',
                  style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
