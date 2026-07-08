import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../core/stores/user_profile_store.dart';

class PlanTask {
  const PlanTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.completed,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool completed;

  factory PlanTask.fromMap(String id, Map<String, dynamic> map) {
    return PlanTask(
      id: id,
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      completed: map['completed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'completed': completed,
    };
  }
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

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  final _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _initializePlanIfNeeded();
  }

  Future<void> _initializePlanIfNeeded() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('study_plan')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      final seeds = [
        {'title': 'مادة: رياضيات - الوحدة 1', 'subtitle': 'تمارين الجمع والطرح', 'completed': true},
        {'title': 'مادة: علوم - الوحدة 2', 'subtitle': 'قراءة الدرس + أسئلة المراجعة', 'completed': false},
        {'title': 'مادة: لغة عربية - النص الأدبي', 'subtitle': 'حفظ المفردات', 'completed': true},
        {'title': 'مادة: قرآن كريم - سورة الناس', 'subtitle': 'مراجعة التلاوة', 'completed': false},
        {'title': 'مادة: إنجليزي - Unit 3', 'subtitle': 'Grammar worksheet', 'completed': false},
      ];

      for (int i = 0; i < seeds.length; i++) {
        await _firebaseService.saveStudyPlanTask(uid, 'task_$i', seeds[i]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = userProfileNotifier.value.uid;

    if (uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('الخطة الدراسية')),
        body: const Center(child: Text('يرجى تسجيل الدخول أولاً.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الخطة الدراسية'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firebaseService.getStudyPlanStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد مهام في خطتك الدراسية حالياً.'));
          }

          final tasks = snapshot.data!.docs.map((doc) {
            return PlanTask.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _PlanTaskCard(
                task: task,
                completed: task.completed,
                scheme: scheme,
                onChanged: (v) async {
                  await _firebaseService.saveStudyPlanTask(uid, task.id, {
                    'title': task.title,
                    'subtitle': task.subtitle,
                    'completed': v ?? false,
                  });
                },
              );
            },
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
