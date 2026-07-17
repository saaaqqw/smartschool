import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/lesson_service.dart';
import '../../data/models/lesson_model.dart';
import '../../core/stores/user_profile_store.dart';
import '../../data/subject_curriculum.dart';
import '../chat/chat_screen.dart';
import 'lesson_detail_screen.dart';

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
  final _firebaseService = FirebaseService();
  bool _isUpdating = false;

  Future<void> _markAsComplete() async {
    final uid = userProfileNotifier.value.uid;
    final semester = userProfileNotifier.value.semester;
    if (uid.isEmpty) return;

    setState(() => _isUpdating = true);
    try {
      await _firebaseService.updateUnitProgress(
        uid,
        widget.subject.title,
        widget.unit.title,
        1.0,
        semester: semester,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إكمال الوحدة بنجاح!',
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

  Widget _buildLessonCard({
    required BuildContext context,
    required ColorScheme scheme,
    required int lessonNumber,
    required String lessonTitle,
    required String videoId,
    required String subjectDocId,
    required int unitIndex,
    double lessonGrade = 0.0,
  }) {
    final pctScore = (lessonGrade > 1 ? lessonGrade : lessonGrade * 100).round();
    return Card(
      elevation: 0,
      color: widget.subject.color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            LessonDetailScreen.route(
              subject: widget.subject,
              unit: widget.unit,
              lessonNumber: lessonNumber,
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
                  color: widget.subject.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: widget.subject.color,
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
                        color: scheme.onSurface,
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
                          'شاهد الدرس + حدده كمكتمل',
                          style: GoogleFonts.tajawal(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (lessonGrade > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.subject.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'الدرجة: $pctScore%',
                              style: GoogleFonts.tajawal(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: widget.subject.color,
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
                tooltip: 'فتح صفحة الدرس',
                icon: const Icon(Icons.play_circle_outline_rounded, size: 26),
                color: widget.subject.color,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                onPressed: _isUpdating
                    ? null
                    : () {
                        Navigator.of(context).push(
                          LessonDetailScreen.route(
                            subject: widget.subject,
                            unit: widget.unit,
                            lessonNumber: lessonNumber,
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
        stream: uid.isEmpty
            ? const Stream.empty()
            : _firebaseService.getProgressStream(uid, widget.subject.title, semester: semester),
        builder: (context, snapshot) {
          double progress = widget.unit.progress;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final progressData = data?['unitProgress'] as Map<String, dynamic>? ?? {};
            final firestoreProgress = progressData[widget.unit.title] as double?;
            if (firestoreProgress != null) {
              progress = firestoreProgress;
            }
          }
          final pct = (progress * 100).round();

          return StreamBuilder<List<LessonModel>>(
            stream: LessonService().lessonsStream(
              subjectId: subjectDocId,
              unitIndex: widget.unitIndex,
            ),
            builder: (context, lessonsSnapshot) {
              final lessonsList = lessonsSnapshot.data ?? [];
              final showPlaceholder = lessonsList.isEmpty;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
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
                  Text(
                    'نسبة الإنجاز',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 12,
                      backgroundColor: widget.subject.color.withValues(alpha: 0.15),
                      color: widget.subject.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$pct٪ مكتمل',
                    style: GoogleFonts.tajawal(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 32),
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
                  const SizedBox(height: 24),
                  Text(
                    showPlaceholder
                        ? 'قائمة الدروس (10) لهذه الوحدة:'
                        : 'قائمة الدروس لهذه الوحدة (من المنهج):',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (showPlaceholder)
                    ...List.generate(10, (i) {
                      final lessonNumber = i + 1;
                      final videoId = 'dQw4w9WgXcQ';
                      return _buildLessonCard(
                        context: context,
                        scheme: scheme,
                        lessonNumber: lessonNumber,
                        lessonTitle: 'الدرس $lessonNumber',
                        videoId: videoId,
                        subjectDocId: subjectDocId,
                        unitIndex: widget.unitIndex,
                        lessonGrade: 0.0,
                      );
                    })
                  else
                    ...List.generate(lessonsList.length, (i) {
                      final lesson = lessonsList[i];
                      final lessonNumber = lesson.lessonNumber;
                      final lessonTitle = lesson.title.isNotEmpty ? lesson.title : 'الدرس $lessonNumber';
                      final videoId = lesson.videoUrl;
                      final lessonGrade = lesson.lessonGrade;
                      return _buildLessonCard(
                        context: context,
                        scheme: scheme,
                        lessonNumber: lessonNumber,
                        lessonTitle: lessonTitle,
                        videoId: videoId.isEmpty ? 'dQw4w9WgXcQ' : videoId,
                        subjectDocId: subjectDocId,
                        unitIndex: widget.unitIndex,
                        lessonGrade: lessonGrade,
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            ChatScreen.route(
              subjectTitle: '${widget.subject.title} - ${widget.unit.title}',
            ),
          );
        },
        backgroundColor: widget.subject.color,
        foregroundColor: Colors.white,
        child: const Icon(Icons.auto_awesome_rounded),
      ),
    );
  }
}
