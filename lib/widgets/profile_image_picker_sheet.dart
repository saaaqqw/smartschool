import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/stores/user_profile_store.dart';
import '../services/firebase_service.dart';

/// قائمة الأفاتارات الكرتونية الجاهزة المخصصة لطلاب المدرسة الذكية
class StudentAvatarOption {
  final String title;
  final String url;
  const StudentAvatarOption({required this.title, required this.url});
}

const List<StudentAvatarOption> kSmartSchoolAvatars = [
  StudentAvatarOption(
    title: 'طالب متفوق 👦',
    url: 'https://api.dicebear.com/7.x/adventurer/png?seed=StudentBoy1&backgroundColor=b6e3f4',
  ),
  StudentAvatarOption(
    title: 'طالبة متفوقة 👧',
    url: 'https://api.dicebear.com/7.x/adventurer/png?seed=StudentGirl1&backgroundColor=ffdfbf',
  ),
  StudentAvatarOption(
    title: 'بطل الذكاء 🤖',
    url: 'https://api.dicebear.com/7.x/bottts/png?seed=SmartSchool1&backgroundColor=1B6B93',
  ),
  StudentAvatarOption(
    title: 'مستكشف العلوم 🔬',
    url: 'https://api.dicebear.com/7.x/adventurer/png?seed=Explorer&backgroundColor=d1d4f9',
  ),
  StudentAvatarOption(
    title: 'مفكر مبدع 💡',
    url: 'https://api.dicebear.com/7.x/lorelei/png?seed=Thinker&backgroundColor=c0aede',
  ),
  StudentAvatarOption(
    title: 'قارئة ماهرة 📚',
    url: 'https://api.dicebear.com/7.x/lorelei/png?seed=Reader&backgroundColor=ffd5dc',
  ),
  StudentAvatarOption(
    title: 'رائد الفضاء 🚀',
    url: 'https://api.dicebear.com/7.x/bottts/png?seed=Astro&backgroundColor=6366f1',
  ),
  StudentAvatarOption(
    title: 'نجمة القمة ⭐',
    url: 'https://api.dicebear.com/7.x/fun-emoji/png?seed=StarTop',
  ),
  StudentAvatarOption(
    title: 'بطل الرياضيات 🧮',
    url: 'https://api.dicebear.com/7.x/fun-emoji/png?seed=MathHero',
  ),
  StudentAvatarOption(
    title: 'فنان المدرسة 🎨',
    url: 'https://api.dicebear.com/7.x/adventurer-neutral/png?seed=ScienceArt&backgroundColor=a0e7e5',
  ),
];

/// دالة مساعدة لإنشاء ImageProvider آمن سواء كان رابط سحابي http/https أو مسار ملف محلي File
ImageProvider<Object>? getProfileImageProvider(String imageUrl) {
  if (imageUrl.trim().isEmpty) return null;
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    return CachedNetworkImageProvider(imageUrl);
  }
  final file = File(imageUrl);
  if (file.existsSync()) {
    return FileImage(file);
  }
  return null;
}

/// نافذة سفلية تفاعلية لعرض خيارات تغيير وتحديث الصورة الشخصية (معرض، كاميرا، أفاتارات دراسية، حذف)
class ProfileImagePickerSheet extends StatefulWidget {
  const ProfileImagePickerSheet({super.key});

  /// فتح النافذة برمجياً من شاشة الإعدادات أو غيرها
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const ProfileImagePickerSheet(),
    );
  }

  @override
  State<ProfileImagePickerSheet> createState() => _ProfileImagePickerSheetState();
}

class _ProfileImagePickerSheetState extends State<ProfileImagePickerSheet> {
  bool _isLoading = false;
  String _statusMessage = '';
  final _picker = ImagePicker();
  final _firebaseService = FirebaseService();

  Future<void> _updateAndSave(String newUrl, {String toastText = 'تم تحديث الصورة الشخصية بنجاح ✅'}) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري حفظ التغييرات...';
    });

    try {
      final currentProfile = userProfileNotifier.value;
      final updatedProfile = currentProfile.copyWith(profileImageUrl: newUrl);
      await saveUserProfile(updatedProfile);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toastText,
              style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
            ),
            backgroundColor: const Color(0xFF1B6B93),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حفظ الصورة: $e', style: GoogleFonts.tajawal()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFromSource(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 600,
      );
      if (picked == null) return;

      setState(() {
        _isLoading = true;
        _statusMessage = 'جاري رفع الصورة على السحابة...';
      });

      final file = File(picked.path);
      final uid = userProfileNotifier.value.uid;

      String resultUrl = picked.path; // احتياطي: مسار الملف المحلي على الجهاز في حال عدم توفر سحابة أو عند التجربة محلياً

      if (uid.isNotEmpty) {
        try {
          final cloudUrl = await _firebaseService.uploadProfileImage(uid, file);
          if (cloudUrl.isNotEmpty) {
            resultUrl = cloudUrl;
          }
        } catch (cloudError) {
          debugPrint('Notice: Cloud upload fallback to local storage ($cloudError)');
          // في حال فشل الرفع السحابي (مثلاً عدم تفعيل Storage أو عدم اتصال الإنترنت على سطح المكتب)، يتم الاحتفاظ بالمسار المحلي
        }
      }

      await _updateAndSave(resultUrl, toastText: 'تم تحديث صورة الملف الشخصي بنجاح 🖼️✅');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر اختيار الصورة: $e', style: GoogleFonts.tajawal()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentProfile = userProfileNotifier.value;
    final hasImage = currentProfile.profileImageUrl.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تحديث الصورة الشخصية 🖼️',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'اختر صورة من جهازك، التقط صورة جديدة، أو اختر من الأفاتارات الكرتونية الذكية',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              if (_isLoading) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(
                        _statusMessage,
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // أزرار سريعة (معرض، كاميرا، حذف)
                Row(
                  children: [
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.photo_library_rounded,
                        label: 'معرض الصور',
                        color: scheme.primary,
                        onTap: () => _pickFromSource(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.camera_alt_rounded,
                        label: 'الكاميرا',
                        color: scheme.secondary,
                        onTap: () => _pickFromSource(ImageSource.camera),
                      ),
                    ),
                    if (hasImage) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.delete_outline_rounded,
                          label: 'إزالة الصورة',
                          color: scheme.error,
                          onTap: () => _updateAndSave('', toastText: 'تم إزالة الصورة الشخصية وحفظ الافتراضي 🗑️'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // قسم الأفاتارات الكرتونية الجاهزة
                Row(
                  children: [
                    Icon(Icons.face_retouching_natural_rounded, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'أو اختر شخصية دراسية جاهزة (Avatars):',
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.76,
                  ),
                  itemCount: kSmartSchoolAvatars.length,
                  itemBuilder: (context, index) {
                    final avatar = kSmartSchoolAvatars[index];
                    final isSelected = currentProfile.profileImageUrl == avatar.url;

                    return InkWell(
                      onTap: () => _updateAndSave(avatar.url, toastText: 'تم اختيار الشخصية الكرتونية بنجاح 🎨✅'),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? scheme.primary : Colors.transparent,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: scheme.primary.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: avatar.url,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 48,
                                  height: 48,
                                  color: scheme.surfaceContainerHighest,
                                  child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 48,
                                  height: 48,
                                  color: scheme.primaryContainer,
                                  child: Icon(Icons.person_rounded, color: scheme.primary, size: 28),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            avatar.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
