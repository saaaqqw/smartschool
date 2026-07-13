import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/lesson_model.dart';
import '../../data/subject_curriculum.dart';
import '../../services/firebase_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/lesson_service.dart';
import '../../core/stores/user_profile_store.dart';
import '../../services/badges_service.dart';

// ── نُصدِّر QuizQuestion كـ typedef للتوافق مع الكود القديم ──────
typedef QuizQuestion = QuizQuestionModel;

/// شاشة الاختبار السريع — المنطق الجديد:
///   • الأسئلة تأتي من subcollection مخلوطة عشوائياً.
///   • عند الانتهاء تُحفظ الدرجة فقط إذا كانت أعلى من السابقة (Best Score).
///   • يعرض حالة المقارنة بوضوح للطالب.
class QuickQuizScreen extends StatefulWidget {
  const QuickQuizScreen({
    super.key,
    required this.subject,
    required this.unit,
    required this.lessonNumber,
    required this.questions,
    // معاملات الهوية الجديدة لحفظ الدرجة
    this.subjectDocId = '',
    this.lessonDocId = '',
    this.previousBestScore = 0.0,
  });

  final SchoolSubject subject;
  final CurriculumUnit unit;
  final int lessonNumber;
  final List<QuizQuestionModel> questions;

  /// معرّف المادة في Firestore (لحفظ الدرجة)
  final String subjectDocId;

  /// معرّف الدرس في Firestore (لحفظ الدرجة)
  final String lessonDocId;

  /// أعلى درجة سبق للطالب تحقيقها في هذا الدرس
  final double previousBestScore;

  static Route<void> route({
    required SchoolSubject subject,
    required CurriculumUnit unit,
    required int lessonNumber,
    required List<QuizQuestionModel> questions,
    String subjectDocId = '',
    String lessonDocId = '',
    double previousBestScore = 0.0,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => QuickQuizScreen(
        subject: subject,
        unit: unit,
        lessonNumber: lessonNumber,
        questions: questions,
        subjectDocId: subjectDocId,
        lessonDocId: lessonDocId,
        previousBestScore: previousBestScore,
      ),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  @override
  State<QuickQuizScreen> createState() => _QuickQuizScreenState();
}

class _QuickQuizScreenState extends State<QuickQuizScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _finished = false;
  bool _isSaving = false;
  bool _isNewRecord = false;   // هل النتيجة الجديدة أعلى من السابقة؟
  bool _scoreSaved = false;
  int? _selectedOption;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  final _lessonSvc = LessonService();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── منطق الإجابة ───────────────────────────────────────────
  void _onOptionTap(int i) {
    if (_selectedOption != null) return;
    setState(() => _selectedOption = i);

    final correct = widget.questions[_currentIndex].correctIndex;
    if (i == correct) _correctCount++;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_currentIndex < widget.questions.length - 1) {
        _fadeCtrl.reverse().then((_) {
          if (!mounted) return;
          setState(() {
            _currentIndex++;
            _selectedOption = null;
          });
          _fadeCtrl.forward();
        });
      } else {
        _finishQuiz();
      }
    });
  }

  // ─── إنهاء الاختبار وحفظ أعلى درجة ─────────────────────────
  Future<void> _finishQuiz() async {
    setState(() {
      _finished = true;
      _isSaving = true;
    });

    final total = widget.questions.length;
    final newScore = total > 0 ? _correctCount / total : 0.0;

    try {
      final uid = userProfileNotifier.value.uid;
      if (uid.isNotEmpty) {
        // 1) تحديث تقدم الوحدة (السلوك القديم المحتفظ به)
        await FirebaseService().updateUnitProgress(
          uid,
          widget.subject.title,
          widget.unit.title,
          newScore,
        );

        // 2) حفظ أعلى درجة للدرس (Best Score) — الجديد
        if (widget.subjectDocId.isNotEmpty && widget.lessonDocId.isNotEmpty) {
          final updated = await _lessonSvc.saveBestScore(
            subjectId: widget.subjectDocId,
            lessonId: widget.lessonDocId,
            newScore: newScore,
          );
          if (mounted) setState(() => _isNewRecord = updated);
        }

        // 3) ترقية مؤشر الدرس للطالب إذا اجتاز الاختبار (≥50%)
        if (newScore >= 0.5 &&
            widget.subjectDocId.isNotEmpty &&
            widget.lessonDocId.isNotEmpty) {
          try {
            final unitIndex = widget.subject.units.indexOf(widget.unit);
            // جلب عدد دروس الوحدة الحالية
            int maxLessons = 5;
            final lessons = await _lessonSvc.fetchLessonsForUnit(
              subjectId: widget.subjectDocId,
              unitIndex: unitIndex >= 0 ? unitIndex : 0,
            );
            if (lessons.isNotEmpty) maxLessons = lessons.length;

            await FirebaseService().advanceLessonProgress(
              uid: uid,
              subjectTitle: widget.subject.title,
              currentUnitIndex: unitIndex >= 0 ? unitIndex : 0,
              currentLessonNumber: widget.lessonNumber,
              maxLessonsInUnit: maxLessons,
              maxUnits: widget.subject.units.length,
            );

            // تحديث عداد الدروس المكتملة في Firestore
            FirebaseSyncService.incrementLessonsCompleted(
                uid, widget.subject.title).ignore();

            // فحص واكتساب الشارات الرقمية الجديدة (Gamification)
            try {
              final unlocked = await BadgesService.checkAndAwardBadges(
                uid: uid,
                subjectPercentages: {widget.subject.title: newScore * 100},
                totalCompletedLessons: 1,
              );
              if (unlocked.isNotEmpty && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🎉 مبروك! لقد حصلت على وسام جديد: ${unlocked.first}',
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                );
              }
            } catch (_) {}
          } catch (_) {}
        }
      }
      if (mounted) setState(() => _scoreSaved = true);
    } catch (_) {
      if (mounted) setState(() => _scoreSaved = true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── واجهة الاختبار ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.subject.color;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: scheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _finished
            ? null
            : Text(
                'اختبار — ${widget.subject.title}',
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: scheme.onSurface,
                ),
              ),
        centerTitle: true,
      ),
      body: _finished
          ? _buildResultScreen(scheme, color)
          : _buildQuizBody(scheme, color),
    );
  }

  // ─── جسم الاختبار ────────────────────────────────────────────
  Widget _buildQuizBody(ColorScheme scheme, Color color) {
    final q = widget.questions[_currentIndex];
    final total = widget.questions.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── رأس: رقم السؤال + عداد الصحيح ──────────────────
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'السؤال ${_currentIndex + 1} / $total',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  '$_correctCount صحيح',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── شريط التقدم ──────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / total,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
              ),
            ),
            const SizedBox(height: 28),

            // ── نص السؤال ────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnim,
              child: Card(
                elevation: 0,
                color: color.withValues(alpha: 0.09),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: color.withValues(alpha: 0.25), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Text(
                    q.question,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── خيارات الإجابة ────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ListView.separated(
                  itemCount: q.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _OptionTile(
                    label: q.options[i],
                    optionLetter: _letters[i % _letters.length],
                    color: color,
                    scheme: scheme,
                    state: _optionState(i, q.correctIndex),
                    onTap: () => _onOptionTap(i),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _OptionState _optionState(int i, int correct) {
    if (_selectedOption == null) return _OptionState.idle;
    if (i == correct) return _OptionState.correct;
    if (i == _selectedOption) return _OptionState.wrong;
    return _OptionState.idle;
  }

  // ─── شاشة النتيجة ────────────────────────────────────────────
  Widget _buildResultScreen(ColorScheme scheme, Color color) {
    final total = widget.questions.length;
    final pct = total > 0 ? (_correctCount / total * 100).round() : 0;
    final prevPct = (widget.previousBestScore * 100).round();

    final isPerfect = _correctCount == total;
    final isGood = pct >= 60;
    final resultColor =
        isPerfect ? Colors.amber : isGood ? color : scheme.error;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            // ── أيقونة النتيجة ────────────────────────────────────
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPerfect
                      ? Icons.star_rounded
                      : isGood
                          ? Icons.thumb_up_rounded
                          : Icons.sentiment_dissatisfied_rounded,
                  size: 64,
                  color: resultColor,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── رسالة ─────────────────────────────────────────────
            Text(
              isPerfect
                  ? 'ممتاز! أجبت على جميع الأسئلة صحيحاً! 🎉'
                  : isGood
                      ? 'أحسنت! أداؤك جيد جداً 👍'
                      : 'حاول مرة أخرى لتحسين نتيجتك 💪',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // ── بطاقة الدرجة الحالية ──────────────────────────────
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: resultColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$_correctCount / $total',
                      style: GoogleFonts.tajawal(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: resultColor,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pct٪ إجابات صحيحة',
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── مقارنة Best Score ─────────────────────────────────
            if (widget.subjectDocId.isNotEmpty && !_isSaving) ...[
              _ScoreComparisonCard(
                scheme: scheme,
                color: color,
                currentPct: pct,
                previousPct: prevPct,
                isNewRecord: _isNewRecord,
                isSaved: _scoreSaved,
              ),
            ] else if (_isSaving) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'جاري حفظ الدرجة...',
                    style: GoogleFonts.tajawal(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),

            // ── أزرار ─────────────────────────────────────────────
            FilledButton.icon(
              onPressed: () => Navigator.of(context)
                ..pop()
                ..pop(),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                'العودة للدرس',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// بطاقة مقارنة الدرجات (Best Score)
// ═══════════════════════════════════════════════════════════════
class _ScoreComparisonCard extends StatelessWidget {
  const _ScoreComparisonCard({
    required this.scheme,
    required this.color,
    required this.currentPct,
    required this.previousPct,
    required this.isNewRecord,
    required this.isSaved,
  });

  final ColorScheme scheme;
  final Color color;
  final int currentPct;
  final int previousPct;
  final bool isNewRecord;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    final bgColor = isNewRecord
        ? const Color(0xFF00897B).withValues(alpha: 0.1)
        : scheme.surfaceContainerLow;
    final borderColor = isNewRecord
        ? const Color(0xFF00897B).withValues(alpha: 0.4)
        : scheme.outlineVariant.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          // أيقونة
          Icon(
            isNewRecord
                ? Icons.emoji_events_rounded
                : Icons.history_rounded,
            color: isNewRecord
                ? const Color(0xFF00897B)
                : scheme.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(width: 12),
          // معلومات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNewRecord
                      ? '🏆 رقم قياسي جديد!'
                      : 'أعلى درجة سابقة: $previousPct٪',
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isNewRecord
                        ? const Color(0xFF00897B)
                        : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isNewRecord
                      ? 'تحسّنت من $previousPct٪ إلى $currentPct٪ 🎯'
                      : 'درجتك الحالية ($currentPct٪) لم تتجاوز الرقم السابق',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // حالة الحفظ
          if (isSaved)
            Icon(
              Icons.cloud_done_rounded,
              size: 20,
              color: isNewRecord
                  ? const Color(0xFF00897B)
                  : scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// خيار إجابة
// ═══════════════════════════════════════════════════════════════
const List<String> _letters = ['أ', 'ب', 'ج', 'د', 'هـ'];

enum _OptionState { idle, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.optionLetter,
    required this.color,
    required this.scheme,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String optionLetter;
  final Color color;
  final ColorScheme scheme;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = switch (state) {
      _OptionState.correct => Colors.green.withValues(alpha: 0.15),
      _OptionState.wrong => Colors.red.withValues(alpha: 0.15),
      _OptionState.idle => scheme.surfaceContainerHigh,
    };
    final borderColor = switch (state) {
      _OptionState.correct => Colors.green,
      _OptionState.wrong => Colors.red,
      _OptionState.idle => Colors.transparent,
    };
    final letterColor = switch (state) {
      _OptionState.correct => Colors.green,
      _OptionState.wrong => Colors.red,
      _OptionState.idle => color,
    };
    final icon = switch (state) {
      _OptionState.correct => Icons.check_circle_rounded,
      _OptionState.wrong => Icons.cancel_rounded,
      _OptionState.idle => null,
    };

    return GestureDetector(
      onTap: state == _OptionState.idle ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: state == _OptionState.idle ? 0 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: letterColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                optionLetter,
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: letterColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (icon != null)
              Icon(icon, color: borderColor, size: 22),
          ],
        ),
      ),
    );
  }
}
