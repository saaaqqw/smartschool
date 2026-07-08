import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/subject_curriculum.dart';
import '../services/firebase_service.dart';
import '../user_profile_store.dart';
import '../widgets/youtube_lesson_player.dart';
import 'chat_screen.dart';

/// صفحة تفاصيل الدرس: تشغيل يوتيوب + زر تحديد كمكتمل.
class LessonDetailScreen extends StatefulWidget {
  const LessonDetailScreen({
    super.key,
    required this.subject,
    required this.unit,
    required this.lessonNumber,
    required this.videoId,
  });

  final SchoolSubject subject;
  final CurriculumUnit unit;
  final int lessonNumber;
  final String videoId;

  static Route<void> route({
    required SchoolSubject subject,
    required CurriculumUnit unit,
    required int lessonNumber,
    required String videoId,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          LessonDetailScreen(
        subject: subject,
        unit: unit,
        lessonNumber: lessonNumber,
        videoId: videoId,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 260),
    );
  }

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final _firebaseService = FirebaseService();
  bool _isUpdating = false;

  /// ملاحظة مهمة:
  /// حالياً FirebaseService لا يدعم progress للدرس بشكل منفصل.
  /// سنستخدم [unitProgress] لتفعيل تجربة زر الدرس.
  /// لو رغبت لاحقاً نضيف lessonProgress داخل Firestore.
  Future<void> _markAsComplete() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;

    setState(() => _isUpdating = true);
    try {
      await _firebaseService.updateUnitProgress(
        uid,
        widget.subject.title,
        widget.unit.title,
        1.0,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديد الدرس ${widget.lessonNumber} كمكتمل (تجريبي)!',
            style: GoogleFonts.tajawal(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء التحديث: $e',
            style: GoogleFonts.tajawal(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الدرس ${widget.lessonNumber}',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.subject.color,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.of(context).push(
            ChatScreen.route(
              subjectTitle:
                  '${widget.subject.title} - ${widget.unit.title} - درس ${widget.lessonNumber}',
            ),
          );
        },
        child: const Icon(Icons.auto_awesome_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: widget.subject.color.withValues(alpha: 0.12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.subject.title,
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.subject.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.unit.title,
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'شاهد الدرس ثم حدده كمكتمل.',
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // الفيديو
          YoutubeLessonPlayer(
            videoId: widget.videoId,
            autoPlay: false,
          ),

          const SizedBox(height: 18),

          FilledButton.icon(
            onPressed: _isUpdating ? null : _markAsComplete,
            icon: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              'تحديد كمكتمل',
              style: GoogleFonts.tajawal(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: widget.subject.color,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'محتوى الدرس (placeholder):',
            style: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك لاحقاً ربط هذا النص بمحتوى حقيقي (ملخص/أسئلة/روابط).',
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
