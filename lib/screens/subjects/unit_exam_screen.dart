import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/lesson_model.dart';
import '../../data/subject_curriculum.dart';
import '../../core/stores/user_profile_store.dart';
import '../../services/unit_exam_service.dart';
import '../../services/quiz_notification_service.dart';

/// شاشة اختبار الوحدة الشامل
///
/// تسحب 5 أسئلة عشوائية من كل درس في الوحدة وتعرضها كاختبار متواصل.
/// عند الاجتياز (≥60%) تُحدَّث الوحدة كمكتملة تلقائياً.
class UnitExamScreen extends StatefulWidget {
  const UnitExamScreen({
    super.key,
    required this.subject,
    required this.unit,
    required this.unitIndex,
    required this.questions,
    required this.subjectDocId,
    this.previousScore,
  });

  final SchoolSubject subject;
  final CurriculumUnit unit;
  final int unitIndex;
  final List<QuizQuestionModel> questions;
  final String subjectDocId;
  final double? previousScore;

  static Route<void> route({
    required SchoolSubject subject,
    required CurriculumUnit unit,
    required int unitIndex,
    required List<QuizQuestionModel> questions,
    required String subjectDocId,
    double? previousScore,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => UnitExamScreen(
        subject: subject,
        unit: unit,
        unitIndex: unitIndex,
        questions: questions,
        subjectDocId: subjectDocId,
        previousScore: previousScore,
      ),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  @override
  State<UnitExamScreen> createState() => _UnitExamScreenState();
}

class _UnitExamScreenState extends State<UnitExamScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _finished = false;
  bool _isSaving = false;
  bool _passed = false;
  int? _selectedOption;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  final _examSvc = UnitExamService();

  static const double _kPassMark = 0.6;

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

  // ─── منطق الإجابة ────────────────────────────────────────────
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
        _finishExam();
      }
    });
  }

  // ─── إنهاء الاختبار وحفظ النتيجة ─────────────────────────────
  Future<void> _finishExam() async {
    setState(() {
      _finished = true;
      _isSaving = true;
    });

    final total = widget.questions.length;
    final score = total > 0 ? _correctCount / total : 0.0;

    try {
      final uid = userProfileNotifier.value.uid;
      final semester = userProfileNotifier.value.semester;
      final grade = userProfileNotifier.value.grade;

      if (uid.isNotEmpty) {
        // 1) حفظ نتيجة اختبار الوحدة في Firestore
        final passed = await _examSvc.saveUnitExamScore(
          uid: uid,
          subjectTitle: widget.subject.title,
          unitTitle: widget.unit.title,
          score: score,
          semester: semester,
          grade: grade,
          passMark: _kPassMark,
        );
        if (mounted) setState(() => _passed = passed);

        // 2) إرسال إشعار ذكي بنتيجة اختبار الوحدة مقارنةً بالمحاولة السابقة
        QuizNotificationService.sendUnitExamResultNotification(
          uid: uid,
          score: score,
          previousScore: widget.previousScore,
          subjectTitle: widget.subject.title,
          unitTitle: widget.unit.title,
        ).ignore();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
                'اختبار الوحدة — ${widget.unit.title}',
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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

  // ─── جسم الاختبار ─────────────────────────────────────────────
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            const SizedBox(height: 6),

            // ── شارة "اختبار الوحدة" ─────────────────────────────
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_rounded, size: 14, color: color),
                    const SizedBox(width: 5),
                    Text(
                      'اختبار الوحدة الشامل',
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
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
            const SizedBox(height: 24),

            // ── نص السؤال ────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnim,
              child: Card(
                elevation: 0,
                color: color.withValues(alpha: 0.09),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: color.withValues(alpha: 0.25), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Text(
                    q.question,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

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
                    scheme: Theme.of(context).colorScheme,
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

  // ─── شاشة النتيجة ─────────────────────────────────────────────
  Widget _buildResultScreen(ColorScheme scheme, Color color) {
    final total = widget.questions.length;
    final pct = total > 0 ? (_correctCount / total * 100).round() : 0;
    final prevPct = widget.previousScore != null
        ? (widget.previousScore! * 100).round()
        : null;

    final isPerfect = _correctCount == total;
    final resultColor = isPerfect
        ? Colors.amber
        : _passed
            ? const Color(0xFF10B981)
            : scheme.error;

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
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPerfect
                      ? Icons.star_rounded
                      : _passed
                          ? Icons.emoji_events_rounded
                          : Icons.sentiment_dissatisfied_rounded,
                  size: 68,
                  color: resultColor,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── رسالة النتيجة ─────────────────────────────────────
            Text(
              isPerfect
                  ? '🌟 ممتاز! إجابات مثالية!'
                  : _passed
                      ? '🎉 أحسنت! لقد أكملت الوحدة!'
                      : '💪 لم تتجاوز الحد الأدنى، حاول مرة أخرى',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),

            if (_passed)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 5),
                      Text(
                        'تم إكمال الوحدة ✓',
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ── بطاقة الدرجة ──────────────────────────────────────
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: resultColor.withValues(alpha: 0.3)),
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
                    if (!_isSaving) ...[
                      const SizedBox(height: 8),
                      Text(
                        _passed
                            ? 'الحد الأدنى للنجاح: ${(_kPassMark * 100).round()}٪ ✓'
                            : 'الحد الأدنى للنجاح: ${(_kPassMark * 100).round()}٪',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          color: _passed ? const Color(0xFF10B981) : scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── حالة الحفظ ────────────────────────────────────────
            if (_isSaving)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'جاري حفظ النتيجة...',
                    style: GoogleFonts.tajawal(
                        color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_done_rounded,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'تم حفظ النتيجة',
                    style: GoogleFonts.tajawal(
                        color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),

            // ── المقارنة مع الاختبار السابق ──────────────────────
            if (prevPct != null && !_isSaving) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded,
                        color: scheme.onSurfaceVariant, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'محاولتك السابقة: $prevPct٪',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      pct >= prevPct ? '↑ تحسّن!' : '↓',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: pct >= prevPct
                            ? const Color(0xFF10B981)
                            : scheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── أزرار ─────────────────────────────────────────────
            if (!_passed) ...[
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'أعد المحاولة',
                  style: GoogleFonts.tajawal(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(
                'العودة للوحدة',
                style: GoogleFonts.tajawal(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// خيار الإجابة
// ══════════════════════════════════════════════════════════════════
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            if (icon != null) Icon(icon, color: borderColor, size: 22),
          ],
        ),
      ),
    );
  }
}
