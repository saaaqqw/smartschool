import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/models/grade_entry.dart';

class RadarPlanCard extends StatelessWidget {
  const RadarPlanCard({
    super.key,
    required this.entries,
    required this.onOpenPlan,
    required this.onOpenGrades,
    required this.scheme,
  });

  final List<GradeEntry> entries;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenGrades;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    // حساب النسبة الكلية إذا أردنا عرض شريط تقدم
    final progress = entries.isEmpty
        ? 0.0
        : entries.map((e) => e.ratio).reduce((a, b) => a + b) / entries.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenPlan, // الضغط على البطاقة يفتح الخطة
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        color: scheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'خطة اليوم ومستواك',
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_left_rounded, color: scheme.onPrimaryContainer),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // الرادار التفاعلي (بديل الدائرة)
                    GestureDetector(
                      onTap: onOpenGrades, // الضغط على الرادار يفتح الدرجات
                      child: Container(
                        height: 110,
                        width: 110,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: entries.isEmpty
                            ? Center(
                                child: Icon(Icons.bar_chart_rounded, color: scheme.primary.withValues(alpha: 0.5)),
                              )
                            : RadarChart(
                                RadarChartData(
                                  radarShape: RadarShape.polygon,
                                  dataSets: [
                                    RadarDataSet(
                                      fillColor: scheme.primary.withValues(alpha: 0.3),
                                      borderColor: scheme.primary,
                                      entryRadius: 2,
                                      dataEntries: entries.map((e) => RadarEntry(value: e.ratio * 100)).toList(),
                                      borderWidth: 2,
                                    ),
                                  ],
                                  radarBackgroundColor: Colors.transparent,
                                  borderData: FlBorderData(show: false),
                                  radarBorderData: const BorderSide(color: Colors.transparent),
                                  titlePositionPercentageOffset: 0.1,
                                  titleTextStyle: GoogleFonts.tajawal(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  getTitle: (index, angle) {
                                    if (index < entries.length) {
                                      final entry = entries[index];
                                      return RadarChartTitle(
                                        text: entry.subject.split(' ').first,
                                        angle: angle,
                                      );
                                    }
                                    return const RadarChartTitle(text: '');
                                  },
                                  tickCount: 2, // تقليل الخطوط الداخلية ليكون أوضح في الحجم الصغير
                                  ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
                                  tickBorderData: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
                                  gridBorderData: BorderSide(color: scheme.outline.withValues(alpha: 0.2), width: 1),
                                ),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeInOutBack,
                              ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // النصوص وشريط التقدم
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المستوى العام',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    backgroundColor:
                                        scheme.onPrimaryContainer.withValues(alpha: 0.15),
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'اضغط هنا لمتابعة خطتك الدراسية، أو اضغط على الدائرة لعرض تفاصيل الدرجات.',
                            style: GoogleFonts.tajawal(
                              fontSize: 11,
                              color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
