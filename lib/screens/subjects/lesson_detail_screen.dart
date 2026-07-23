import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/subject_curriculum.dart';
import '../../data/models/lesson_model.dart';
import '../../services/firebase_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/lesson_service.dart';
import '../../core/stores/user_profile_store.dart';
import '../../widgets/youtube_lesson_player.dart';
import '../chat/chat_screen.dart';
import 'quick_quiz_screen.dart';

/// صفحة تفاصيل الدرس — المنطق الجديد:
///   • يجلب الأسئلة من subcollection  subjects/{id}/lessons/{id}/questions
///   • يقرأ [lessonGrade] الحالي من مستند الدرس ويمرّره للاختبار
///   • عدد الأسئلة المعروض محدود بـ [_kQuizLimit]
class LessonDetailScreen extends StatefulWidget {
  const LessonDetailScreen({
    super.key,
    required this.subject,
    required this.unit,
    required this.lessonNumber,
    required this.videoId,
    required this.subjectDocId,
    required this.unitIndex,
    this.lessonDocId = '',
  });

  final SchoolSubject subject;
  final CurriculumUnit unit;
  final int lessonNumber;
  final String videoId;
  final String subjectDocId;
  final int unitIndex;

  /// معرّف مستند الدرس في مسار subjects/{subjectId}/lessons/{lessonDocId}.
  /// إذا كان فارغاً سيُحسب تلقائياً كـ "lesson_{lessonNumber}".
  final String lessonDocId;

  static Route<void> route({
    required SchoolSubject subject,
    required CurriculumUnit unit,
    required int lessonNumber,
    required String videoId,
    String subjectDocId = '',
    int unitIndex = 0,
    String lessonDocId = '',
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => LessonDetailScreen(
        subject: subject,
        unit: unit,
        lessonNumber: lessonNumber,
        videoId: videoId,
        subjectDocId: subjectDocId,
        unitIndex: unitIndex,
        lessonDocId: lessonDocId,
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 260),
    );
  }

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

// عدد الأسئلة المعروض بعد الخلط
const int _kQuizLimit = 10;

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final _firebaseService = FirebaseService();
  final _lessonSvc = LessonService();
  final GlobalKey<State<StatefulWidget>> _playerKey = GlobalKey<State<StatefulWidget>>();
  bool _isUpdating = false;
  bool _isVideoFullScreen = false;
  Map<String, dynamic>? _summaryData;
  List<QuizQuestionModel> _cachedQuestions = [];
  double _cachedPrevBest = 0.0;
  bool _localCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _onFullScreenChanged(bool isFull) {
    if (mounted && _isVideoFullScreen != isFull) {
      setState(() => _isVideoFullScreen = isFull);
    }
  }

  Future<void> _loadInitialData() async {
    final summary = await _fetchSummaryFromFirestore();
    List<QuizQuestionModel> questions = [];
    double prevBest = 0.0;

    if (widget.subjectDocId.isNotEmpty) {
      try {
        questions = await _lessonSvc.fetchRandomizedQuestions(
          subjectId: widget.subjectDocId,
          lessonId: _lessonDocId,
          unitIndex: widget.unitIndex,
          limit: _kQuizLimit,
        );
        if (questions.isNotEmpty) {
          prevBest = await _lessonSvc.fetchLessonGrade(
            subjectId: widget.subjectDocId,
            lessonId: _lessonDocId,
            unitIndex: widget.unitIndex,
          );
        }
        if (questions.isEmpty) {
          questions = await _fetchQuestionsLegacy();
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        if (summary != null) _summaryData = summary;
        _cachedQuestions = questions;
        _cachedPrevBest = prevBest;
      });
    }
  }

  /// معرّف الدرس النهائي (يُحسب إذا لم يُمرَّر)
  String get _lessonDocId =>
      widget.lessonDocId.isNotEmpty
          ? widget.lessonDocId
          : 'lesson_${widget.lessonNumber}';

  /// ─── المنطق الرئيسي عند "أكملت الدرس" / "الانتقال لاختبار الدرس" ─────────
  Future<void> _onLessonComplete(bool isLessonCompletedPermanently) async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;

    // إذا كان الدرس مكتملاً بالفعل أو تم الضغط على زر الانتقال المباشر للأسئلة
    if (isLessonCompletedPermanently) {
      if (_cachedQuestions.isNotEmpty) {
        Navigator.of(context).push(
          QuickQuizScreen.route(
            subject: widget.subject,
            unit: widget.unit,
            lessonNumber: widget.lessonNumber,
            questions: _cachedQuestions,
            subjectDocId: widget.subjectDocId,
            lessonDocId: _lessonDocId,
            unitIndex: widget.unitIndex,
            previousBestScore: _cachedPrevBest,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إتمام هذا الدرس بنجاح، ولا توجد أسئلة اختبار مسجلة عليه حالياً. ✅',
              style: GoogleFonts.tajawal(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // أول مرة يكمل فيها الطالب الدرس:
    setState(() => _isUpdating = true);

    try {
      if (_cachedQuestions.isEmpty && widget.subjectDocId.isNotEmpty) {
        _cachedQuestions = await _lessonSvc.fetchRandomizedQuestions(
          subjectId: widget.subjectDocId,
          lessonId: _lessonDocId,
          unitIndex: widget.unitIndex,
          limit: _kQuizLimit,
        );
        if (_cachedQuestions.isEmpty) {
          _cachedQuestions = await _fetchQuestionsLegacy();
        }
      }
      _summaryData ??= await _fetchSummaryFromFirestore();

      await _firebaseService.updateUnitProgress(
        uid,
        widget.subject.title,
        widget.unit.title,
        1.0,
      );

      int maxLessons = 5;
      try {
        final snap = await _lessonSvc.fetchLessonsForUnit(
          subjectId: widget.subjectDocId,
          unitIndex: widget.unitIndex,
        );
        if (snap.isNotEmpty) maxLessons = snap.length;
      } catch (_) {}

      final currentSemester = userProfileNotifier.value.semester;
      await _firebaseService.advanceLessonProgress(
        uid: uid,
        subjectTitle: widget.subject.title,
        currentUnitIndex: widget.unitIndex,
        currentLessonNumber: widget.lessonNumber,
        maxLessonsInUnit: maxLessons,
        maxUnits: widget.subject.units.length,
        semester: currentSemester,
      );

      FirebaseSyncService.incrementLessonsCompleted(
          uid, widget.subject.title, semester: currentSemester).ignore();

      if (!mounted) return;
      setState(() {
        _isUpdating = false;
        _localCompleted = true;
      });

      // إذا كان هناك أسئلة ننتقل إليها مباشرة دون فتح نافذة منبثقة للملخص
      if (_cachedQuestions.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حفظ تقدمك بنجاح! جاري الانتقال لاختبار الدرس... ✅',
              style: GoogleFonts.tajawal(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).push(
          QuickQuizScreen.route(
            subject: widget.subject,
            unit: widget.unit,
            lessonNumber: widget.lessonNumber,
            questions: _cachedQuestions,
            subjectDocId: widget.subjectDocId,
            lessonDocId: _lessonDocId,
            unitIndex: widget.unitIndex,
            previousBestScore: _cachedPrevBest,
          ),
        );
      } else if (_summaryData != null) {
        // في حالة عدم وجود أسئلة ولكن يوجد ملخص، نعرضه للمرة الأولى فقط
        _showLessonSummaryDialog(_summaryData, _cachedQuestions, _cachedPrevBest, uid);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديد الدرس ${widget.lessonNumber} كمكتمل! ✅',
              style: GoogleFonts.tajawal(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  Future<List<QuizQuestionModel>> _fetchQuestionsLegacy() async {
    try {
      final db = FirebaseFirestore.instance;
      var subjDoc = await db.collection('subjects').doc(widget.subjectDocId).get();
      if (!subjDoc.exists || subjDoc.data() == null) {
        subjDoc = await db.collection('subjects').doc(widget.subject.subjectId).get();
      }

      if (subjDoc.exists && subjDoc.data() != null) {
        final unitsRaw = subjDoc.data()!['units'] as List? ?? [];
        if (widget.unitIndex >= 0 && widget.unitIndex < unitsRaw.length) {
          if (unitsRaw[widget.unitIndex] is Map) {
            final uMap = unitsRaw[widget.unitIndex] as Map;
            final lList = uMap['lessons'] as List? ?? [];
            if (widget.lessonNumber - 1 < lList.length && lList[widget.lessonNumber - 1] is Map) {
              final lMap = lList[widget.lessonNumber - 1] as Map;
              final qList = lMap['questions'] as List? ?? [];
              if (qList.isNotEmpty) {
                final List<QuizQuestionModel> result = [];
                for (int qIdx = 0; qIdx < qList.length; qIdx++) {
                  if (qList[qIdx] is Map) {
                    final qMap = Map<String, dynamic>.from(qList[qIdx] as Map);
                    result.add(QuizQuestionModel.fromMap('q_$qIdx', qMap));
                  }
                }
                result.shuffle();
                return result.length > _kQuizLimit ? result.sublist(0, _kQuizLimit) : result;
              }
            }
          }
        } else {
          for (int uIdx = 0; uIdx < unitsRaw.length; uIdx++) {
            if (unitsRaw[uIdx] is Map) {
              final uMap = unitsRaw[uIdx] as Map;
              final lList = uMap['lessons'] as List? ?? [];
              if (widget.lessonNumber - 1 < lList.length &&
                  lList[widget.lessonNumber - 1] is Map) {
                final lMap = lList[widget.lessonNumber - 1] as Map;
                final qList = lMap['questions'] as List? ?? [];
                if (qList.isNotEmpty) {
                  final List<QuizQuestionModel> result = [];
                  for (int qIdx = 0; qIdx < qList.length; qIdx++) {
                    if (qList[qIdx] is Map) {
                      final qMap = Map<String, dynamic>.from(qList[qIdx] as Map);
                      result.add(QuizQuestionModel.fromMap('q_$qIdx', qMap));
                    }
                  }
                  result.shuffle();
                  return result.length > _kQuizLimit ? result.sublist(0, _kQuizLimit) : result;
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return [];
  }

  /// جلب ملخص الدرس من خريطة الدرس داخل units في مستند المادة
  Future<Map<String, dynamic>?> _fetchSummaryFromFirestore() async {
    try {
      final db = FirebaseFirestore.instance;

      // 1) البحث في خريطة الدروس داخل حقل units في مسار المادة الكامل
      var subjDoc = await db
          .collection('subjects')
          .doc(widget.subjectDocId)
          .get();
      if (!subjDoc.exists || subjDoc.data() == null) {
        subjDoc = await db
            .collection('subjects')
            .doc(widget.subject.subjectId)
            .get();
      }

      if (subjDoc.exists && subjDoc.data() != null) {
        final unitsRaw = subjDoc.data()!['units'] as List? ?? [];
        if (widget.unitIndex >= 0 && widget.unitIndex < unitsRaw.length) {
          if (unitsRaw[widget.unitIndex] is Map) {
            final uMap = unitsRaw[widget.unitIndex] as Map;
            final lList = uMap['lessons'] as List? ?? [];
            if (widget.lessonNumber - 1 < lList.length && lList[widget.lessonNumber - 1] is Map) {
              final lMap = lList[widget.lessonNumber - 1] as Map;
              final summaryText = lMap['summaryContent'] as String? ?? '';
              if (summaryText.isNotEmpty) {
                return {
                  'summaryTitle': lMap['title'] ?? 'ملخص الدرس ${widget.lessonNumber}',
                  'summaryContent': summaryText,
                  'title': lMap['title'] ?? 'ملخص الدرس ${widget.lessonNumber}',
                  'content': summaryText,
                };
              }
            }
          }
        } else {
          for (int uIdx = 0; uIdx < unitsRaw.length; uIdx++) {
            if (unitsRaw[uIdx] is Map) {
              final uMap = unitsRaw[uIdx] as Map;
              final lList = uMap['lessons'] as List? ?? [];
              if (widget.lessonNumber - 1 < lList.length &&
                  lList[widget.lessonNumber - 1] is Map) {
                final lMap = lList[widget.lessonNumber - 1] as Map;
                final summaryText = lMap['summaryContent'] as String? ?? '';
                if (summaryText.isNotEmpty) {
                  return {
                    'summaryTitle': lMap['title'] ?? 'ملخص الدرس ${widget.lessonNumber}',
                    'summaryContent': summaryText,
                    'title': lMap['title'] ?? 'ملخص الدرس ${widget.lessonNumber}',
                    'content': summaryText,
                  };
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// عرض نافذة منبثقة (Dialog) منسقة بشكل جميل ومناسب لجميع المواد تعرض ملخص الدرس
  void _showLessonSummaryDialog(
    Map<String, dynamic>? summaryData,
    List<QuizQuestionModel> questions,
    double prevBest,
    String uid,
  ) {
    final title = summaryData?['summaryTitle'] ?? summaryData?['title'] ?? 'أهم نقاط الدرس والملخص الشامل';
    final content = summaryData?['summaryContent'] ?? summaryData?['content'] ??
        'لقد أتممت مشاهدة الدرس ${widget.lessonNumber} بنجاح!\n\n• تأكد من فهم جميع القوانين والمفاهيم الرئيسية المشروحة في الفيديو.\n• راجع الملاحظات التي دونتها أثناء الشرح.\n• يمكنك الآن المتابعة لاختبار معلوماتك أو حفظ تقدمك.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.subject.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(widget.subject.icon, color: widget.subject.color, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملخص الدرس ${widget.lessonNumber}',
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: widget.subject.color,
                          ),
                        ),
                        Text(
                          widget.unit.title,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                title.toString(),
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.subject.color.withValues(alpha: 0.2)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    content.toString(),
                    style: GoogleFonts.tajawal(
                      fontSize: 14.5,
                      height: 1.7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (questions.isNotEmpty) {
                    Navigator.of(context).push(
                      QuickQuizScreen.route(
                        subject: widget.subject,
                        unit: widget.unit,
                        lessonNumber: widget.lessonNumber,
                        questions: questions,
                        subjectDocId: widget.subjectDocId,
                        lessonDocId: _lessonDocId,
                        unitIndex: widget.unitIndex,
                        previousBestScore: prevBest,
                      ),
                    );
                  } else {
                    _finishLessonProgressWithoutQuiz(uid);
                  }
                },
                icon: Icon(questions.isNotEmpty ? Icons.quiz_rounded : Icons.check_circle_rounded),
                label: Text(
                  questions.isNotEmpty ? 'الانتقال لاختبار الدرس 📝' : 'إتمام وحفظ التقدم ✅',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.subject.color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// حفظ التقدم وترقية الدرس في حالة عدم وجود أسئلة في الاختبار
  Future<void> _finishLessonProgressWithoutQuiz(String uid) async {
    setState(() => _isUpdating = true);
    try {
      await _firebaseService.updateUnitProgress(
        uid,
        widget.subject.title,
        widget.unit.title,
        1.0,
      );

      int maxLessons = 5;
      try {
        final snap = await _lessonSvc.fetchLessonsForUnit(
          subjectId: widget.subjectDocId,
          unitIndex: widget.unitIndex,
        );
        if (snap.isNotEmpty) maxLessons = snap.length;
      } catch (_) {}

      final currentSemester = userProfileNotifier.value.semester;
      await _firebaseService.advanceLessonProgress(
        uid: uid,
        subjectTitle: widget.subject.title,
        currentUnitIndex: widget.unitIndex,
        currentLessonNumber: widget.lessonNumber,
        maxLessonsInUnit: maxLessons,
        maxUnits: widget.subject.units.length,
        semester: currentSemester,
      );

      FirebaseSyncService.incrementLessonsCompleted(
        uid, widget.subject.title, semester: currentSemester).ignore();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديد الدرس ${widget.lessonNumber} كمكتمل! ✅',
            style: GoogleFonts.tajawal(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e', style: GoogleFonts.tajawal()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }



  // ─── واجهة الصفحة ────────────────────────────────────────────
  // ─── واجهة الصفحة ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = userProfileNotifier.value.uid;
    final currentSemester = userProfileNotifier.value.semester;

    if (_isVideoFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: YoutubeLessonPlayer(
            key: _playerKey,
            videoId: widget.videoId,
            autoPlay: false,
            subjectColor: widget.subject.color,
            lessonTitle: 'الدرس ${widget.lessonNumber} — ${widget.unit.title}',
            onFullScreenChange: _onFullScreenChanged,
          ),
        ),
      );
    }

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
      body: StreamBuilder<DocumentSnapshot>(
        stream: uid.isNotEmpty
            ? _firebaseService.getProgressStream(
                uid,
                widget.subject.title,
                semester: currentSemester,
              )
            : const Stream.empty(),
        builder: (context, snapshot) {
          bool isCompletedInFirestore = false;
          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final currentUnitIdx = data['currentUnitIndex'] as int? ?? 0;
            final currentLessonNum = data['currentLessonNumber'] as int? ?? 1;
            final completedSet = data['completed_lessons_set'] as List? ?? [];

            if (completedSet
                .contains('u${widget.unitIndex}_l${widget.lessonNumber}')) {
              isCompletedInFirestore = true;
            } else if (currentUnitIdx > widget.unitIndex ||
                (currentUnitIdx == widget.unitIndex &&
                    currentLessonNum > widget.lessonNumber)) {
              isCompletedInFirestore = true;
            }
          }

          final bool isLessonCompletedPermanently =
              isCompletedInFirestore || _localCompleted;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── بطاقة المعلومات ──────────────────────────────────────
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
                        'شاهد الدرس ثم أكمل الاختبار.',
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

              // ── عرض أعلى درجة سابقة ──────────────────────────────────
              if (widget.subjectDocId.isNotEmpty)
                _BestScoreBanner(
                  subjectDocId: widget.subjectDocId,
                  lessonDocId: _lessonDocId,
                  color: widget.subject.color,
                  scheme: scheme,
                  lessonSvc: _lessonSvc,
                  unitIndex: widget.unitIndex,
                ),

              const SizedBox(height: 18),

              // ── الفيديو بالـ Smart Cinema Container ──────────────────
              YoutubeLessonPlayer(
                key: _playerKey,
                videoId: widget.videoId,
                autoPlay: false,
                subjectColor: widget.subject.color,
                lessonTitle: 'الدرس ${widget.lessonNumber} — ${widget.unit.title}',
                onFullScreenChange: _onFullScreenChanged,
              ),

              const SizedBox(height: 18),

              // ── بطاقة الملخص الدائمة تحت الفيديو عند اكتمال الدرس ──────────
              if (isLessonCompletedPermanently && _summaryData != null) ...[
                _LessonSummaryCard(
                  summaryData: _summaryData!,
                  subjectColor: widget.subject.color,
                ),
                const SizedBox(height: 18),
              ],

              // ── زر "أكملت الدرس" / "الانتقال لاختبار الدرس" ─────────────
              FilledButton.icon(
                onPressed: _isUpdating
                    ? null
                    : () => _onLessonComplete(isLessonCompletedPermanently),
                icon: _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isLessonCompletedPermanently
                            ? (_cachedQuestions.isNotEmpty
                                ? Icons.quiz_rounded
                                : Icons.check_circle_rounded)
                            : Icons.check_circle_outline_rounded,
                      ),
                label: Text(
                  isLessonCompletedPermanently
                      ? (_cachedQuestions.isNotEmpty
                          ? 'الانتقال لاختبار الدرس (الأسئلة) 📝'
                          : 'الدرس مكتمل (لا توجد أسئلة) ✅')
                      : 'أكملت الدرس',
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
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// شريط أعلى درجة سابقة
// ═══════════════════════════════════════════════════════════════
class _BestScoreBanner extends StatelessWidget {
  const _BestScoreBanner({
    required this.subjectDocId,
    required this.lessonDocId,
    required this.color,
    required this.scheme,
    required this.lessonSvc,
    required this.unitIndex,
  });

  final String subjectDocId;
  final String lessonDocId;
  final Color color;
  final ColorScheme scheme;
  final LessonService lessonSvc;
  final int? unitIndex;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: lessonSvc.fetchLessonGrade(
        subjectId: subjectDocId,
        lessonId: lessonDocId,
        unitIndex: unitIndex,
      ),
      builder: (_, snap) {
        final grade = snap.data ?? 0.0;
        if (!snap.hasData || grade == 0.0) return const SizedBox(height: 12);

        final pct = (grade * 100).round();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'أعلى درجة سابقة في هذا الدرس: $pct٪',
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// بطاقة ملخص الدرس الدائم تحت الفيديو
// ═══════════════════════════════════════════════════════════════
class _LessonSummaryCard extends StatelessWidget {
  const _LessonSummaryCard({
    required this.summaryData,
    required this.subjectColor,
  });

  final Map<String, dynamic> summaryData;
  final Color subjectColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = summaryData['summaryTitle'] ??
        summaryData['title'] ??
        'ملخص وأهم نقاط الدرس';
    final content = summaryData['summaryContent'] ??
        summaryData['content'] ??
        'تم إكمال مشاهدة الفيديو بنجاح.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            subjectColor.withValues(alpha: 0.16),
            subjectColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: subjectColor.withValues(alpha: 0.45),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: subjectColor.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: subjectColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toString(),
                      style: GoogleFonts.tajawal(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.green.shade600,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'درس منجز — الملخص معروض بصفة دائمة',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: subjectColor.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              content.toString(),
              style: GoogleFonts.tajawal(
                fontSize: 14.5,
                height: 1.75,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
