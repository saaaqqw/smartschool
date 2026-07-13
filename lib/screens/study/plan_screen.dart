import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/stores/user_profile_store.dart';
import '../../core/stores/study_timer_store.dart';
import '../../data/subject_curriculum.dart';
import '../../data/models/lesson_model.dart';
import '../../services/weekly_schedule_service.dart';
import '../subjects/lesson_detail_screen.dart';

/// واجهة الخطة (Plan Screen)
/// تعرض مهام اليوم مع دعم:
///   - إلغاء مادة مؤقتاً من خطة اليوم
///   - إعادة تعيين الخطة
///   - التنقل التتابعي للدروس (يفتح الدرس الحالي للطالب)
///   - تشغيل المؤقت العالمي تلقائياً عند دخول الدرس
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uid = userProfileNotifier.value.uid;
    final todayKey = WeeklyScheduleService.todayArabicDay();
    final scheduleService = WeeklyScheduleService();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: scheme.surfaceContainerLowest,
        title: Text(
          'الخطة والمهام اليومية',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: scheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: uid.isEmpty
          ? const Center(child: Text('يرجى تسجيل الدخول أولاً.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DayTasksSection(
                    uid: uid,
                    todayKey: todayKey,
                    scheme: scheme,
                    scheduleService: scheduleService,
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// قسم مهام اليوم
// ─────────────────────────────────────────────────────────────
class _DayTasksSection extends StatelessWidget {
  const _DayTasksSection({
    required this.uid,
    required this.todayKey,
    required this.scheme,
    required this.scheduleService,
  });

  final String uid;
  final String todayKey;
  final ColorScheme scheme;
  final WeeklyScheduleService scheduleService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WeeklySchedule>(
      stream: scheduleService.scheduleStream(uid),
      builder: (context, wsSnap) {
        final allSubjects = wsSnap.data?.schedule[todayKey] ?? [];

        return StreamBuilder<Map<String, bool>>(
          stream: scheduleService.todayTasksStream(uid),
          builder: (context, taskSnap) {
            final completedMap = taskSnap.data ?? {};

            return StreamBuilder<Set<String>>(
              stream: scheduleService.todayCancelledStream(uid),
              builder: (context, cancelSnap) {
                final cancelledSet = cancelSnap.data ?? {};
                // فلترة المواد الملغاة
                final todaySubjects = allSubjects
                    .where((s) => !cancelledSet.contains(s))
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── رأس القسم ──────────────────────────────────
                    Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          color: scheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'مهام اليوم — $todayKey',
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        if (todaySubjects.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${completedMap.values.where((v) => v).length}/${todaySubjects.length}',
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── حالة التحميل أو الفراغ أو القائمة ──────────
                    if (wsSnap.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (allSubjects.isEmpty)
                      _EmptyDayCard(scheme: scheme)
                    else if (todaySubjects.isEmpty && cancelledSet.isNotEmpty)
                      _AllCancelledCard(
                        scheme: scheme,
                        onReset: () =>
                            scheduleService.resetCancelledTasks(uid),
                      )
                    else ...[
                      ...todaySubjects.map((subject) {
                        final done = completedMap[subject] ?? false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SubjectTaskTile(
                            subject: subject,
                            done: done,
                            scheme: scheme,
                            uid: uid,
                            todayKey: todayKey,
                            scheduleService: scheduleService,
                            onCancel: () => scheduleService.cancelTodayTask(
                              uid: uid,
                              subject: subject,
                              dayKey: todayKey,
                            ),
                          ),
                        );
                      }),

                      // ── زر إعادة التعيين إن كان هناك ملغى ────────
                      if (cancelledSet.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: TextButton.icon(
                            onPressed: () =>
                                scheduleService.resetCancelledTasks(uid),
                            icon: Icon(
                              Icons.refresh_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                            label: Text(
                              'إعادة تعيين خطة اليوم (${cancelledSet.length} ملغاة)',
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة المادة الدراسية مع زر الإلغاء والتنقل للدرس
// ─────────────────────────────────────────────────────────────
class _SubjectTaskTile extends StatelessWidget {
  const _SubjectTaskTile({
    required this.subject,
    required this.done,
    required this.scheme,
    required this.uid,
    required this.todayKey,
    required this.scheduleService,
    required this.onCancel,
  });

  final String subject;
  final bool done;
  final ColorScheme scheme;
  final String uid;
  final String todayKey;
  final WeeklyScheduleService scheduleService;
  final VoidCallback onCancel;

  /// جلب مادة المنهج المحلي المطابقة لاسم المادة
  SchoolSubject? _findSubject() {
    try {
      return kCoreSubjects.firstWhere(
        (s) => s.title == subject,
      );
    } catch (_) {
      return null;
    }
  }

  /// جلب تقدم الطالب الحالي ثم فتح شاشة الدرس
  Future<void> _navigateToCurrentLesson(BuildContext context) async {
    final schoolSubject = _findSubject();
    if (schoolSubject == null) {
      // إن لم يُوجد المادة، نُشغّل المؤقت فقط وننبّه
      studyTimerStore.start();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا توجد دروس مرتبطة بـ $subject في التطبيق حالياً.',
            style: GoogleFonts.tajawal(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ── جلب تقدم الطالب من Firestore ────────────────────────────
    int currentUnitIndex = 0;
    int currentLessonNumber = 1;

    try {
      final progressDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc(schoolSubject.title)
          .get();

      if (progressDoc.exists) {
        final data = progressDoc.data() ?? {};
        currentUnitIndex =
            (data['currentUnitIndex'] as num?)?.toInt() ?? 0;
        currentLessonNumber =
            (data['currentLessonNumber'] as num?)?.toInt() ?? 1;
      }
    } catch (_) {}

    final grade = userProfileNotifier.value.grade;
    final cleanGrade = grade.isEmpty ? 'الصف السابع' : grade;
    final subjectDocId = '${schoolSubject.title} - $cleanGrade';

    // ── الحصول على الوحدة المطابقة ───────────────────────────────
    final unitIndex =
        currentUnitIndex.clamp(0, schoolSubject.units.length - 1);
    final currentUnit = schoolSubject.units[unitIndex];

    // ── جلب تفاصيل الدرس من Firestore (من خريطة units النظيفة) ────────
    LessonModel? lesson;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('subjects')
          .doc(subjectDocId)
          .get();

      if (snap.exists && snap.data() != null) {
        final unitsRaw = snap.data()!['units'] as List? ?? [];
        if (unitIndex < unitsRaw.length && unitsRaw[unitIndex] is Map) {
          final uMap = unitsRaw[unitIndex] as Map;
          final lList = uMap['lessons'] as List? ?? [];
          if (currentLessonNumber - 1 < lList.length &&
              lList[currentLessonNumber - 1] is Map) {
            final lMap = Map<String, dynamic>.from(
                lList[currentLessonNumber - 1] as Map);
            lesson = LessonModel.fromMap(
              'lesson_$currentLessonNumber',
              lMap,
              unitIndex: unitIndex,
              lessonNumber: currentLessonNumber,
            );
          }
        }
      }
    } catch (_) {}

    if (!context.mounted) return;

    // ── تشغيل المؤقت العالمي تلقائياً ───────────────────────────
    studyTimerStore.start();

    // ── الانتقال لشاشة الدرس بالمسار العربي والماب النظيف ─────────────
    await Navigator.of(context).push(
      LessonDetailScreen.route(
        subject: schoolSubject,
        unit: currentUnit,
        lessonNumber: lesson?.lessonNumber ?? currentLessonNumber,
        videoId: lesson?.videoUrl ?? '',
        subjectDocId: subjectDocId,
        unitIndex: unitIndex,
        lessonDocId: lesson?.id ?? 'lesson_$currentLessonNumber',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolSubject = _findSubject();
    final subjectColor = schoolSubject?.color ?? scheme.primary;
    final bg = done ? scheme.tertiaryContainer : scheme.surfaceContainerLow;
    final fg = done ? scheme.onTertiaryContainer : scheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToCurrentLesson(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                // أيقونة الدائرة
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: done
                        ? scheme.tertiary
                        : subjectColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    done
                        ? Icons.check_rounded
                        : (schoolSubject?.icon ?? Icons.book_rounded),
                    size: 20,
                    color:
                        done ? scheme.onTertiary : subjectColor,
                  ),
                ),
                const SizedBox(width: 14),

                // اسم المادة + تلميح "الدرس الحالي"
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: fg,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: fg.withValues(alpha: 0.5),
                        ),
                      ),
                      if (!done)
                        Text(
                          'اضغط للبدء بالدرس الحالي ◀',
                          style: GoogleFonts.tajawal(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: subjectColor.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),

                // زر إلغاء المادة من اليوم
                if (!done)
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline_rounded,
                      color: scheme.error.withValues(alpha: 0.7),
                      size: 22,
                    ),
                    tooltip: 'إلغاء من خطة اليوم',
                    onPressed: () => _confirmCancel(context),
                  )
                else
                  Icon(
                    Icons.check_circle_rounded,
                    color: scheme.tertiary,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// حوار التأكيد قبل الإلغاء
  void _confirmCancel(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'إلغاء المادة من اليوم',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'هل تريد إلغاء "$subject" من خطة اليوم؟\n(يمكن استعادتها لاحقاً)',
          style: GoogleFonts.tajawal(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'لا',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onCancel();
            },
            child: Text(
              'نعم، إلغاء',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة "لا توجد مواد"
// ─────────────────────────────────────────────────────────────
class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 48,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد مواد دراسية مجدولة لهذا اليوم',
            style: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'يمكنك إضافة وتعديل جدولك الدراسي الأسبوعي من صفحة الإعدادات أو زر الخطة الدراسية.',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// بطاقة "تم إلغاء جميع المواد"
// ─────────────────────────────────────────────────────────────
class _AllCancelledCard extends StatelessWidget {
  const _AllCancelledCard({
    required this.scheme,
    required this.onReset,
  });

  final ColorScheme scheme;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block_rounded,
            size: 44,
            color: scheme.error.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'تم إلغاء جميع مواد اليوم',
            style: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'إعادة تعيين خطة اليوم',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
