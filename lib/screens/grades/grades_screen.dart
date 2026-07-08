import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GradeRow {
  const GradeRow({
    required this.subject,
    required this.score,
    required this.max,
    required this.color,
  });

  final String subject;
  final int score;
  final int max;
  final Color color;
}

/// الدرجات — أشرطة تقدم + توصيات.
class GradesScreen extends StatelessWidget {
  const GradesScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const GradesScreen(),
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

  static const List<GradeRow> _grades = [
    GradeRow(subject: 'الرياضيات', score: 92, max: 100, color: Color(0xFF5C6BC0)),
    GradeRow(subject: 'العلوم', score: 88, max: 100, color: Color(0xFF26A69A)),
    GradeRow(subject: 'التربية الإسلامية', score: 95, max: 100, color: Color(0xFF7E57C2)),
    GradeRow(subject: 'القرآن الكريم', score: 90, max: 100, color: Color(0xFF43A047)),
    GradeRow(subject: 'اللغة العربية', score: 85, max: 100, color: Color(0xFFE53935)),
    GradeRow(subject: 'اللغة الإنجليزية', score: 78, max: 100, color: Color(0xFF1E88E5)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الدرجات'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            'أداء المواد',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          ..._grades.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GradeCard(row: g, scheme: scheme),
              )),
          const Divider(height: 32),
          Text(
            'توصيات الذكاء الاصطناعي',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: scheme.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: scheme.onSecondaryContainer,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ملاحظات ذكية',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• ركز هذا الأسبوع على مهارات القراءة في اللغة الإنجليزية؛ '
                    'الدرجة أقل قليلاً من المتوسط المستهدف.\n\n'
                    '• أداؤك ممتاز في التربية الإسلامية والرياضيات؛ حافظ على '
                    'نفس وتيرة المراجعة اليومية.\n\n'
                    '• اقتراح: خصص 15 دقيقة يومياً لمراجعة قواعد الرياضيات '
                    'قبل الواجبات.',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSecondaryContainer.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.row,
    required this.scheme,
  });

  final GradeRow row;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final ratio = row.score / row.max;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: row.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.subject,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${row.score}/${row.max}',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: row.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: row.color.withValues(alpha: 0.15),
                color: row.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
