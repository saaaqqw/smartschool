import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/subject_curriculum.dart';
import '../../services/firebase_service.dart';
import '../../core/stores/user_profile_store.dart';
import '../../widgets/youtube_lesson_player.dart';
import '../chat/chat_screen.dart';
import 'quick_quiz_screen.dart';

/// صفحة تفاصيل الدرس: تشغيل يوتيوب + زر تحديد كمكتمل.
class LessonDetailScreen extends StatefulWidget {
  const LessonDetailScreen({
    super.key,
    required this.subject,
    required this.unit,
    required this.lessonNumber,
    required this.videoId,
    required this.subjectDocId,
    required this.unitIndex,
  });

  final SchoolSubject subject;
  final CurriculumUnit unit;
  final int lessonNumber;
  final String videoId;
  final String subjectDocId;
  final int unitIndex;

  static Route<void> route({
    required SchoolSubject subject,
    required CurriculumUnit unit,
    required int lessonNumber,
    required String videoId,
    String subjectDocId = '',
    int unitIndex = 0,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          LessonDetailScreen(
        subject: subject,
        unit: unit,
        lessonNumber: lessonNumber,
        videoId: videoId,
        subjectDocId: subjectDocId,
        unitIndex: unitIndex,
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

  /// عند الضغط على "أكملت الدرس": يتحقق من وجود أسئلة في Firestore.
  /// إذا وُجدت → يفتح QuickQuizScreen.
  /// إذا لم تُوجد → يحفظ التقدم مباشرة.
  Future<void> _onLessonComplete() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;
    setState(() => _isUpdating = true);

    try {
      // جلب بيانات الدرس من Firestore
      List<QuizQuestion> questions = [];
      if (widget.subjectDocId.isNotEmpty) {
        final lessonDocId = 'lesson_${widget.lessonNumber}';
        final lessonDoc = await FirebaseFirestore.instance
            .collection('subjects')
            .doc(widget.subjectDocId)
            .collection('units')
            .doc('unit_${widget.unitIndex + 1}')
            .collection('lessons')
            .doc(lessonDocId)
            .get();

        if (lessonDoc.exists) {
          final data = lessonDoc.data() ?? {};
          final rawQuestions = data['questions'] as List? ?? [];
          questions = rawQuestions.map((q) {
            final qMap = q as Map<String, dynamic>? ?? {};
            // correctIndex قد يأتي كـ int أو String من Firestore
            final rawIdx = qMap['correctIndex'];
            final correctIdx = rawIdx is int
                ? rawIdx
                : int.tryParse(rawIdx?.toString() ?? '0') ?? 0;
            return QuizQuestion(
              question: qMap['question']?.toString() ?? '',
              options: (qMap['options'] as List? ?? [])
                  .map((o) => o.toString())
                  .toList(),
              correctIndex: correctIdx,
            );
          }).toList();
        }
      }

      if (!mounted) return;

      if (questions.isNotEmpty) {
        // فتح شاشة الاختبار السريع
        setState(() => _isUpdating = false);
        Navigator.of(context).push(
          QuickQuizScreen.route(
            subject: widget.subject,
            unit: widget.unit,
            lessonNumber: widget.lessonNumber,
            questions: questions,
          ),
        );
      } else {
        // لا توجد أسئلة — احفظ التقدم مباشرة
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
              'تم تحديد الدرس ${widget.lessonNumber} كمكتمل!',
              style: GoogleFonts.tajawal(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isUpdating = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e', style: GoogleFonts.tajawal()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isUpdating = false);
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
            onPressed: _isUpdating ? null : _onLessonComplete,
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
              'أكملت الدرس',
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
        ],
      ),
    );
  }
}
