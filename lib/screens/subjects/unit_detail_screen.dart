import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/lesson_service.dart';
import '../../services/unit_exam_service.dart';
import '../../data/models/lesson_model.dart';
import '../../core/stores/user_profile_store.dart';
import '../../data/subject_curriculum.dart';
import '../chat/chat_screen.dart';
import 'lesson_detail_screen.dart';
import 'unit_exam_screen.dart';

class UnitDetailScreen extends StatefulWidget {
  const UnitDetailScreen({
    super.key,
    required this.subject,
    required this.unit,
    required this.unitIndex,
  });

  final SchoolSubject subject;
  final CurriculumUnit unit;
  final int unitIndex;

  static Route<void> route({
    required SchoolSubject subject,
    required CurriculumUnit unit,
    required int unitIndex,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => UnitDetailScreen(
        subject: subject,
        unit: unit,
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
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  final _examSvc = UnitExamService();
  bool _isLoadingExam = false;

  // ─── فتح اختبار الوحدة ───────────────────────────────────────
  Future<void> _startUnitExam({
    required String subjectDocId,
    required int totalLessons,
    required double? previousScore,
  }) async {
    if (_isLoadingExam) return;
    setState(() => _isLoadingExam = true);

    try {
      final questions = await _examSvc.fetchUnitExamQuestions(
        subjectId: subjectDocId,
        unitIndex: widget.unitIndex,
        questionsPerLesson: 5,
      );

      if (!mounted) return;

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا توجد أسئلة متاحة لاختبار هذه الوحدة بعد.',
              style: GoogleFonts.tajawal(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        UnitExamScreen.route(
          subject: widget.subject,
          unit: widget.unit,
          unitIndex: widget.unitIndex,
          questions: questions,
          subjectDocId: subjectDocId,
          previousScore: previousScore,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingExam = false);
    }
  }

  // ─── بناء كرت الدرس ──────────────────────────────────────────
  Widget _buildLessonCard({
    required BuildContext context,
    required ColorScheme scheme,
    required int lessonNumber,
    required String lessonTitle,
    required String videoId,
    required String subjectDocId,
    required int unitIndex,
    double lessonGrade = 0.0,
    required bool isCompleted,
    required bool isLocked,
  }) {
    final pctScore = (lessonGrade > 1 ? lessonGrade : lessonGrade * 100).round();

    return Card(
      elevation: 0,
      color: isLocked
          ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
          : isCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.08)
              : widget.subject.color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCompleted && !isLocked
            ? const BorderSide(color: Color(0xFF10B981), width: 1.2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isLocked
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('أكمل الدرس السابق أولاً لتتمكن من الدخول.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: scheme.error,
                  ),
                );
              }
            : () {
                Navigator.of(context).push(
                  LessonDetailScreen.route(
                    subject: widget.subject,
                    unit: widget.unit,
                    lessonNumber: lessonNumber,
                    lessonTitle: lessonTitle,
                    videoId: videoId,
                    subjectDocId: subjectDocId,
                    unitIndex: unitIndex,
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isLocked
                      ? scheme.onSurface.withValues(alpha: 0.1)
                      : isCompleted
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : widget.subject.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isLocked
                      ? Icons.lock_rounded
                      : isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.school_rounded,
                  color: isLocked
                      ? scheme.onSurfaceVariant
                      : isCompleted
                          ? const Color(0xFF10B981)
                          : widget.subject.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lessonTitle,
                      style: GoogleFonts.tajawal(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: isLocked
                            ? scheme.onSurface.withValues(alpha: 0.5)
                            : scheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isLocked
                              ? 'الدرس مقفل'
                              : isCompleted
                                  ? 'مكتمل ✓'
                                  : 'شاهد الدرس + أكمل الاختبار',
                          style: GoogleFonts.tajawal(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isLocked
                                ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                                : isCompleted
                                    ? const Color(0xFF10B981)
                                    : scheme.onSurfaceVariant,
                          ),
                        ),
                        if (lessonGrade > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : widget.subject.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'الدرجة: $pctScore%',
                              style: GoogleFonts.tajawal(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isCompleted
                                    ? const Color(0xFF10B981)
                                    : widget.subject.color,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: isLocked ? 'الدرس مقفل' : 'فتح صفحة الدرس',
                icon: Icon(
                  isLocked ? Icons.lock_outline_rounded : Icons.play_circle_outline_rounded,
                  size: 26,
                ),
                color: isLocked
                    ? scheme.outline.withValues(alpha: 0.5)
                    : isCompleted
                        ? const Color(0xFF10B981)
                        : widget.subject.color,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                onPressed: isLocked
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('أكمل الدرس السابق أولاً لتتمكن من الدخول.'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: scheme.error,
                          ),
                        );
                      }
                    : () {
                        Navigator.of(context).push(
                          LessonDetailScreen.route(
                            subject: widget.subject,
                            unit: widget.unit,
                            lessonNumber: lessonNumber,
                            lessonTitle: lessonTitle,
                            videoId: videoId,
                            subjectDocId: subjectDocId,
                            unitIndex: unitIndex,
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── بطاقة اختبار الوحدة ──────────────────────────────────────
  Widget _buildUnitExamCard({
    required ColorScheme scheme,
    required bool allLessonsCompleted,
    required double? examScore,
    required String subjectDocId,
    required int totalLessons,
  }) {
    final color = widget.subject.color;
    final examPct = examScore != null ? (examScore * 100).round() : null;
    final examPassed = examScore != null && examScore >= 0.6;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: allLessonsCompleted
            ? LinearGradient(
                colors: [
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: allLessonsCompleted ? null : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: examPassed
              ? const Color(0xFF10B981)
              : allLessonsCompleted
                  ? color.withValues(alpha: 0.5)
                  : scheme.outlineVariant.withValues(alpha: 0.4),
          width: examPassed ? 2 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── رأس البطاقة ──────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: examPassed
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : allLessonsCompleted
                            ? color.withValues(alpha: 0.15)
                            : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    examPassed
                        ? Icons.verified_rounded
                        : allLessonsCompleted
                            ? Icons.quiz_rounded
                            : Icons.lock_rounded,
                    color: examPassed
                        ? const Color(0xFF10B981)
                        : allLessonsCompleted
                            ? color
                            : scheme.onSurfaceVariant,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختبار الوحدة الشامل',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        examPassed
                            ? 'اجتزت الاختبار بنجاح! 🎉'
                            : allLessonsCompleted
                                ? 'جاهز للبدء — 5 أسئلة من كل درس'
                                : 'أكمل جميع الدروس أولاً لفتح الاختبار',
                        style: GoogleFonts.tajawal(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: examPassed
                              ? const Color(0xFF10B981)
                              : allLessonsCompleted
                                  ? color
                                  : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (examPct != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: examPassed
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : scheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$examPct٪',
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: examPassed
                            ? const Color(0xFF10B981)
                            : scheme.error,
                      ),
                    ),
                  ),
              ],
            ),

            // ── شريط تقدم الاختبار ────────────────────────────────
            if (examScore != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: examScore.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHigh,
                  color: examPassed ? const Color(0xFF10B981) : scheme.error,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                examPassed
                    ? 'الحد الأدنى للنجاح 60٪ ✓'
                    : 'الحد الأدنى للنجاح 60٪ — لم تصل بعد',
                style: GoogleFonts.tajawal(
                  fontSize: 11,
                  color: examPassed ? const Color(0xFF10B981) : scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            // ── زر البدء ─────────────────────────────────────────
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: !allLessonsCompleted || _isLoadingExam
                    ? null
                    : () => _startUnitExam(
                          subjectDocId: subjectDocId,
                          totalLessons: totalLessons,
                          previousScore: examScore,
                        ),
                icon: _isLoadingExam
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        allLessonsCompleted
                            ? Icons.play_arrow_rounded
                            : Icons.lock_rounded,
                      ),
                label: Text(
                  _isLoadingExam
                      ? 'جاري التحميل...'
                      : examPassed
                          ? 'أعد الاختبار'
                          : allLessonsCompleted
                              ? 'ابدأ اختبار الوحدة'
                              : 'مقفل — أكمل الدروس أولاً',
                  style: GoogleFonts.tajawal(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: allLessonsCompleted ? color : null,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = userProfileNotifier.value.uid;
    final grade = userProfileNotifier.value.grade;
    final cleanGrade = grade.isEmpty ? 'الصف السابع' : grade;
    final semester = userProfileNotifier.value.semester;
    final subjectDocId = FirebaseSyncService.getSubjectDocId(
      widget.subject.title,
      cleanGrade,
      semester: semester,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.unit.title,
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: uid.isNotEmpty
            ? FirebaseService().getProgressStream(
                uid,
                widget.subject.title,
                semester: semester,
                grade: cleanGrade,
              )
            : const Stream.empty(),
        builder: (context, progressSnapshot) {
          final progressData = progressSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final currentUnitIdx = progressData['currentUnitIndex'] as int? ?? 0;
          final currentLessonNum = progressData['currentLessonNumber'] as int? ?? 1;
          final completedSet = progressData['completed_lessons_set'] as List? ?? [];

          return StreamBuilder<List<LessonModel>>(
            stream: LessonService().lessonsStream(
              subjectId: subjectDocId,
              unitIndex: widget.unitIndex,
            ),
            builder: (context, lessonsSnapshot) {
              final lessonsList = lessonsSnapshot.data ?? [];
              final totalLessons = lessonsList.isNotEmpty ? lessonsList.length : 0;

              // حساب عدد الدروس المكتملة
              int completedCount = 0;
              for (final l in lessonsList) {
                bool lessonIsCompleted = false;
                if (l.lessonGrade >= 0.5) {
                  lessonIsCompleted = true;
                } else if (completedSet.contains('u${widget.unitIndex}_l${l.lessonNumber}')) {
                  lessonIsCompleted = true;
                } else if (currentUnitIdx > widget.unitIndex ||
                    (currentUnitIdx == widget.unitIndex && currentLessonNum > l.lessonNumber)) {
                  lessonIsCompleted = true;
                }
                if (lessonIsCompleted) completedCount++;
              }

              final allCompleted =
                  totalLessons > 0 && completedCount >= totalLessons;

          return StreamBuilder<double?>(
            stream: _examSvc.unitExamScoreStreamAuto(
              subjectTitle: widget.subject.title,
              unitTitle: widget.unit.title,
            ),
            builder: (context, examScoreSnap) {
              final examScore = examScoreSnap.data;
              final showPlaceholder = lessonsList.isEmpty;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── بطاقة رأس الوحدة ──────────────────────────────
                  Card(
                    elevation: 0,
                    color: widget.subject.color.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: widget.subject.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              widget.unit.icon,
                              color: widget.subject.color,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.subject.title,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: widget.subject.color,
                                  ),
                                ),
                                Text(
                                  'الوحدة ${widget.unitIndex + 1}',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── مؤشر تقدم الدروس ─────────────────────────────
                  _buildLessonsProgressCard(
                    scheme: scheme,
                    completedCount: completedCount,
                    totalLessons: totalLessons,
                    allCompleted: allCompleted,
                    showPlaceholder: showPlaceholder,
                  ),
                  const SizedBox(height: 24),

                  // ── قائمة الدروس ──────────────────────────────────
                  Text(
                    showPlaceholder
                        ? 'قائمة الدروس (10) لهذه الوحدة:'
                        : 'قائمة الدروس لهذه الوحدة (${lessonsList.length}):',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (showPlaceholder)
                    ...List.generate(10, (i) {
                      final lessonNumber = i + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildLessonCard(
                          context: context,
                          scheme: scheme,
                          lessonNumber: lessonNumber,
                          lessonTitle: 'الدرس $lessonNumber',
                          videoId: 'dQw4w9WgXcQ',
                          subjectDocId: subjectDocId,
                          unitIndex: widget.unitIndex,
                          lessonGrade: 0.0,
                          isCompleted: false,
                          isLocked: (widget.unitIndex > currentUnitIdx) ||
                              (widget.unitIndex == currentUnitIdx && lessonNumber > currentLessonNum),
                        ),
                      );
                    })
                  else
                    ...List.generate(lessonsList.length, (i) {
                      final lesson = lessonsList[i];
                      
                      bool lessonIsCompleted = false;
                      if (lesson.lessonGrade >= 0.5) {
                        lessonIsCompleted = true;
                      } else if (completedSet.contains('u${widget.unitIndex}_l${lesson.lessonNumber}')) {
                        lessonIsCompleted = true;
                      } else if (currentUnitIdx > widget.unitIndex ||
                          (currentUnitIdx == widget.unitIndex && currentLessonNum > lesson.lessonNumber)) {
                        lessonIsCompleted = true;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildLessonCard(
                          context: context,
                          scheme: scheme,
                          lessonNumber: lesson.lessonNumber,
                          lessonTitle: lesson.title.isNotEmpty
                              ? lesson.title
                              : 'الدرس ${lesson.lessonNumber}',
                          videoId: lesson.videoUrl.isEmpty
                              ? 'dQw4w9WgXcQ'
                              : lesson.videoUrl,
                          subjectDocId: subjectDocId,
                          unitIndex: widget.unitIndex,
                          lessonGrade: lesson.lessonGrade,
                          isCompleted: lessonIsCompleted,
                          isLocked: (widget.unitIndex > currentUnitIdx) ||
                              (widget.unitIndex == currentUnitIdx && lesson.lessonNumber > currentLessonNum),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // ── بطاقة اختبار الوحدة ───────────────────────────
                  _buildUnitExamCard(
                    scheme: scheme,
                    allLessonsCompleted: allCompleted,
                    examScore: examScore,
                    subjectDocId: subjectDocId,
                    totalLessons: totalLessons,
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          );
        },
      );
    },
  ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            ChatScreen.route(
              subjectName: '${widget.subject.title} - ${widget.unit.title}',
            ),
          );
        },
        backgroundColor: widget.subject.color,
        foregroundColor: Colors.white,
        child: const Icon(Icons.auto_awesome_rounded),
      ),
    );
  }

  // ─── مؤشر تقدم الدروس ────────────────────────────────────────
  Widget _buildLessonsProgressCard({
    required ColorScheme scheme,
    required int completedCount,
    required int totalLessons,
    required bool allCompleted,
    required bool showPlaceholder,
  }) {
    if (showPlaceholder) return const SizedBox.shrink();

    final progress = totalLessons > 0 ? completedCount / totalLessons : 0.0;
    final color = allCompleted ? const Color(0xFF10B981) : widget.subject.color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allCompleted
                    ? Icons.check_circle_rounded
                    : Icons.auto_stories_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'الشرط الأول — إكمال الدروس',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '$completedCount / $totalLessons',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            allCompleted
                ? '✅ أكملت جميع دروس الوحدة — يمكنك الآن بدء اختبار الوحدة'
                : 'أكمل ${totalLessons - completedCount} درس متبقية لفتح اختبار الوحدة',
            style: GoogleFonts.tajawal(
              fontSize: 12,
              color: allCompleted ? const Color(0xFF10B981) : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
