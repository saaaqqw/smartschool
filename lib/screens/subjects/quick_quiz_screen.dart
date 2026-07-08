import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/subject_curriculum.dart';
import '../../services/firebase_service.dart';
import '../../core/stores/user_profile_store.dart';

/// موديل سؤال الاختبار السريع.
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    final options = (map['options'] as List? ?? [])
        .map((o) => o.toString())
        .toList();
    return QuizQuestion(
      question: map['question'] as String? ?? '',
      options: options,
      correctIndex: (map['correctIndex'] as int?) ?? 0,
    );
  }
}

/// شاشة الاختبار السريع.
class QuickQuizScreen extends StatefulWidget {
  const QuickQuizScreen({
    super.key,
    required this.subject,
    required this.unit,
    required this.lessonNumber,
    required this.questions,
  });

  final SchoolSubject subject;
  final CurriculumUnit unit;
  final int lessonNumber;
  final List<QuizQuestion> questions;

  static Route<void> route({
    required SchoolSubject subject,
    required CurriculumUnit unit,
    required int lessonNumber,
    required List<QuizQuestion> questions,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => QuickQuizScreen(
        subject: subject,
        unit: unit,
        lessonNumber: lessonNumber,
        questions: questions,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
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
  int? _selectedOption;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onOptionTap(int optionIndex) {
    if (_selectedOption != null) return;
    setState(() => _selectedOption = optionIndex);
    if (optionIndex == widget.questions[_currentIndex].correctIndex) _correctCount++;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_currentIndex < widget.questions.length - 1) {
        _fadeController.reverse().then((_) {
          if (!mounted) return;
          setState(() {
            _currentIndex++;
            _selectedOption = null;
          });
          _fadeController.forward();
        });
      } else {
        _finishQuiz();
      }
    });
  }

  Future<void> _finishQuiz() async {
    setState(() { _finished = true; _isSaving = true; });
    try {
      final uid = userProfileNotifier.value.uid;
      if (uid.isNotEmpty) {
        await FirebaseService().updateUnitProgress(
          uid, widget.subject.title, widget.unit.title, 1.0,
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _isSaving = false);
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
                'اختبار سريع — ${widget.subject.title}',
                style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 16, color: scheme.onSurface),
              ),
        centerTitle: true,
      ),
      body: _finished ? _buildResultScreen(scheme, color) : _buildQuizBody(scheme, color),
    );
  }

  Widget _buildQuizBody(ColorScheme scheme, Color color) {
    final question = widget.questions[_currentIndex];
    final total = widget.questions.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'السؤال ${_currentIndex + 1} من $total',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 14, color: color),
                ),
                const Spacer(),
                Text(
                  '$_correctCount/$total صحيح',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
            FadeTransition(
              opacity: _fadeAnimation,
              child: Card(
                elevation: 0,
                color: color.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Text(
                    question.question,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface, height: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.separated(
                  itemCount: question.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _OptionTile(
                    label: question.options[i],
                    optionLetter: _letters[i],
                    color: color,
                    scheme: scheme,
                    state: _getOptionState(i, question.correctIndex),
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

  _OptionState _getOptionState(int optionIndex, int correctIndex) {
    if (_selectedOption == null) return _OptionState.idle;
    if (optionIndex == correctIndex) return _OptionState.correct;
    if (optionIndex == _selectedOption) return _OptionState.wrong;
    return _OptionState.idle;
  }

  Widget _buildResultScreen(ColorScheme scheme, Color color) {
    final total = widget.questions.length;
    final pct = (_correctCount / total * 100).round();
    final isPerfect = _correctCount == total;
    final isGood = _correctCount >= (total * 0.6).ceil();
    final resultColor = isPerfect ? Colors.amber : isGood ? color : scheme.error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPerfect ? Icons.star_rounded : isGood ? Icons.thumb_up_rounded : Icons.sentiment_dissatisfied_rounded,
                  size: 64,
                  color: resultColor,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              isPerfect ? 'ممتاز! أجبت على جميع الأسئلة بشكل صحيح! 🎉'
                  : isGood ? 'أحسنت! أداؤك جيد جداً 👍'
                  : 'حاول مرة أخرى لتحسين نتيجتك 💪',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface, height: 1.5),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '$_correctCount / $total',
                      style: GoogleFonts.tajawal(fontSize: 48, fontWeight: FontWeight.w900, color: resultColor),
                    ),
                    Text(
                      '$pct٪ إجابات صحيحة',
                      style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: _isSaving
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
                        const SizedBox(width: 8),
                        Text('جاري حفظ التقدم...', style: GoogleFonts.tajawal(color: scheme.onSurfaceVariant, fontSize: 13)),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done_rounded, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text('تم حفظ التقدم بنجاح ✅', style: GoogleFonts.tajawal(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
            ),
            const SizedBox(height: 36),
            FilledButton.icon(
              onPressed: () => Navigator.of(context)..pop()..pop(),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text('العودة للوحدة', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<String> _letters = ['أ', 'ب', 'ج', 'د'];

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
      _OptionState.wrong   => Colors.red.withValues(alpha: 0.15),
      _OptionState.idle    => scheme.surfaceContainerHigh,
    };
    final borderColor = switch (state) {
      _OptionState.correct => Colors.green,
      _OptionState.wrong   => Colors.red,
      _OptionState.idle    => Colors.transparent,
    };
    final letterColor = switch (state) {
      _OptionState.correct => Colors.green,
      _OptionState.wrong   => Colors.red,
      _OptionState.idle    => color,
    };
    final icon = switch (state) {
      _OptionState.correct => Icons.check_circle_rounded,
      _OptionState.wrong   => Icons.cancel_rounded,
      _OptionState.idle    => null,
    };
    return GestureDetector(
      onTap: state == _OptionState.idle ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: state == _OptionState.idle ? 0 : 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: letterColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(optionLetter, style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 16, color: letterColor)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface)),
            ),
            if (icon != null) Icon(icon, color: borderColor, size: 22),
          ],
        ),
      ),
    );
  }
}
