import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlanTask {
  const PlanTask({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

/// الخطة الدراسية — قائمة مهام مع اكتمال.
class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const StudyPlanScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
    );
  }

  static const List<PlanTask> _seed = [
    PlanTask(
      title: 'مادة: رياضيات - الوحدة 1',
      subtitle: 'تمارين الجمع والطرح',
    ),
    PlanTask(
      title: 'مادة: علوم - الوحدة 2',
      subtitle: 'قراءة الدرس + أسئلة المراجعة',
    ),
    PlanTask(
      title: 'مادة: لغة عربية - النص الأدبي',
      subtitle: 'حفظ المفردات',
    ),
    PlanTask(
      title: 'مادة: قرآن كريم - سورة الناس',
      subtitle: 'مراجعة التلاوة',
    ),
    PlanTask(
      title: 'مادة: إنجليزي - Unit 3',
      subtitle: 'Grammar worksheet',
    ),
  ];

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  late final List<bool> _done;

  @override
  void initState() {
    super.initState();
    _done = List<bool>.filled(StudyPlanScreen._seed.length, false);
    _done[0] = true;
    _done[2] = true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الخطة الدراسية'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: StudyPlanScreen._seed.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final task = StudyPlanScreen._seed[index];
          final completed = _done[index];
          return _PlanTaskCard(
            task: task,
            completed: completed,
            scheme: scheme,
            onChanged: (v) => setState(() => _done[index] = v ?? false),
          );
        },
      ),
    );
  }
}

class _PlanTaskCard extends StatelessWidget {
  const _PlanTaskCard({
    required this.task,
    required this.completed,
    required this.scheme,
    required this.onChanged,
  });

  final PlanTask task;
  final bool completed;
  final ColorScheme scheme;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final pendingBg = scheme.surfaceContainerHighest;
    final pendingBorder = scheme.outlineVariant;
    final doneBg = scheme.tertiaryContainer;
    final doneFg = scheme.onTertiaryContainer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: completed ? doneBg : pendingBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: completed
                ? doneFg.withValues(alpha: 0.25)
                : pendingBorder.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onChanged(!completed),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: completed ? doneFg : scheme.onSurface,
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: doneFg.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.subtitle,
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: completed
                              ? doneFg.withValues(alpha: 0.85)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: completed,
                  onChanged: onChanged,
                  activeColor: doneFg,
                  checkColor: scheme.surface,
                  side: BorderSide(
                    color: completed ? doneFg : scheme.outline,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
