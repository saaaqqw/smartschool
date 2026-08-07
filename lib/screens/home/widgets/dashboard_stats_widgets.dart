import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/models/grade_entry.dart';
import '../../../services/ai_recommendation_service.dart';
import '../../../core/stores/user_profile_store.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../widgets/skeleton_loader.dart';

class ImprovementCard extends StatefulWidget {
  const ImprovementCard({
    super.key,
    required this.entry,
    required this.scheme,
    required this.rank,
  });

  final GradeEntry entry;
  final ColorScheme scheme;
  final int rank;

  @override
  State<ImprovementCard> createState() => _ImprovementCardState();
}

class _ImprovementCardState extends State<ImprovementCard> {
  String _aiAdvice = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdvice();
  }

  Future<void> _fetchAdvice() async {
    final grade = userProfileNotifier.value.grade.isNotEmpty ? userProfileNotifier.value.grade : 'الصف السابع';
    final advice = await AiRecommendationService.getSubjectAdvice(
      subject: widget.entry.subject,
      score: widget.entry.score,
      grade: grade,
    );
    if (mounted) {
      setState(() {
        _aiAdvice = advice;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.entry.ratingColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // ترتيب الأولوية
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: widget.entry.ratingColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${widget.rank}',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: widget.entry.ratingColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // دائرة صغيرة للتقدم
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: widget.entry.ratio,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: widget.entry.color.withValues(alpha: 0.12),
                  color: widget.entry.color,
                ),
                Text(
                  '${widget.entry.percent}%',
                  style: GoogleFonts.tajawal(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: widget.entry.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.entry.subject,
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: widget.scheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.entry.ratingColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AppLocalizations.of(context).translate(widget.entry.ratingKey),
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.entry.ratingColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _isLoading
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'جاري تحليل الأداء...',
                            style: GoogleFonts.tajawal(
                              fontSize: 11,
                              color: widget.scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _aiAdvice,
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          color: widget.scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                const SizedBox(height: 6),
                // شريط التقدم
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: widget.entry.ratio,
                    minHeight: 5,
                    backgroundColor: widget.entry.color.withValues(alpha: 0.12),
                    color: widget.entry.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyGradesChart extends StatelessWidget {
  const WeeklyGradesChart({
    super.key,
    required this.scheme,
    required this.averages,
    required this.labels,
    required this.isLoading,
    required this.animCtrl,
  });

  final ColorScheme scheme;
  final List<double> averages;
  final List<String> labels;
  final bool isLoading;
  final AnimationController animCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bar_chart_rounded, color: scheme.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'أداء آخر 7 أيام',
                style: GoogleFonts.tajawal(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isLoading)
            const SkeletonWidget(
              width: double.infinity,
              height: 150,
              borderRadius: 16,
            )
          else if (averages.every((a) => a == 0))
            SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'لا توجد اختبارات في آخر 7 أيام',
                  style: GoogleFonts.tajawal(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final score = averages[i]; // 0.0 to 100.0
                  final ratio = (score / 100).clamp(0.0, 1.0);
                  
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (score > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${score.round()}',
                              style: GoogleFonts.tajawal(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        AnimatedBuilder(
                          animation: animCtrl,
                          builder: (context, child) {
                            final delay = i * 0.1;
                            final t = ((animCtrl.value - delay) / (1 - delay)).clamp(0.0, 1.0);
                            final height = ratio * 100 * t;
                            
                            return Container(
                              height: height > 0 ? height.clamp(4.0, 100.0) : 4.0,
                              width: 16,
                              decoration: BoxDecoration(
                                color: score > 0 ? scheme.primary : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          labels[i],
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.scheme,
    this.badgeCount,
  });

  final IconData icon;
  final String title;
  final ColorScheme scheme;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.tajawal(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        if (badgeCount != null && badgeCount! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$badgeCount',
              style: GoogleFonts.tajawal(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AllGoodCard extends StatelessWidget {
  const AllGoodCard({super.key, required this.scheme});
  
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.stars_rounded, color: scheme.primary, size: 48),
          const SizedBox(height: 12),
          Text(
            'عمل رائع! 🌟',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'جميع موادك في مستوى ممتاز ولا توجد أولوية حرجة للتحسين.',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 13,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
