import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../services/firebase_service.dart';
import '../../core/stores/user_profile_store.dart';
import '../../services/ai_recommendation_service.dart';
import '../../data/subject_curriculum.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/skeleton_loader.dart';
import '../../data/models/grade_entry.dart';
import '../../services/db_keys.dart';
import '../../core/l10n/app_localizations.dart';

// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// الشاشة الرئيسية
// ═══════════════════════════════════════════════════════════════
class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const GradesScreen(),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
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
      ),
      transitionDuration: const Duration(milliseconds: 320),
    );
  }

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen>
    with SingleTickerProviderStateMixin {
  final _svc = FirebaseService();
  late final AnimationController _animCtrl;


  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _initGradesIfNeeded();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _initGradesIfNeeded() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;

    final grade = userProfileNotifier.value.grade;
    final cleanGrade = grade.isEmpty ? 'الصف السابع' : grade;

    final currentSemester = userProfileNotifier.value.semester;

    for (final s in kCoreSubjects) {
      final gradeDocId = DbKeys.gradesDoc(
        uid: uid,
        subjectTitle: s.title,
        grade: cleanGrade,
        semester: currentSemester,
      );
      final docRef = FirebaseFirestore.instance
          .collection('grades')
          .doc(gradeDocId);
      final snap = await docRef.get();

      if (!snap.exists) {
        double calculatedScore = 0.0;
        Map<String, dynamic> lessonScores = {};
        try {
          final subjectDocId = DbKeys.subjectDoc(
            subjectTitle: s.title,
            grade: cleanGrade,
            semester: currentSemester,
          );
          final subjDoc = await FirebaseFirestore.instance
              .collection('subjects')
              .doc(subjectDocId)
              .get();
          if (subjDoc.exists && subjDoc.data() != null) {
            final unitsRaw = subjDoc.data()!['units'] as List? ?? [];
            double sumRatio = 0.0;
            int testedLessons = 0;
            int totalLessons = 0;
            for (final u in unitsRaw) {
              if (u is Map) {
                final lList = u['lessons'] as List? ?? [];
                for (final l in lList) {
                  if (l is Map) {
                    totalLessons++;
                    final g = (l['lessonGrade'] as num?)?.toDouble() ?? 0.0;
                    if (g > 0) {
                      final ratioVal = (g > 1.0 ? g / 100.0 : g).clamp(0.0, 1.0);
                      sumRatio += ratioVal;
                      testedLessons++;
                      lessonScores['$totalLessons'] = ratioVal;
                    }
                  }
                }
              }
            }
            if (testedLessons > 0) {
              calculatedScore = (sumRatio / testedLessons) * 100.0;
            }
          }
        } catch (_) {}

        await FirebaseFirestore.instance
            .collection('grades')
            .doc(gradeDocId)
            .set({
          'userId': uid,
          'subjectId': s.title,
          'grade': cleanGrade,
          'semester': currentSemester,
          'score': calculatedScore.clamp(0.0, 100.0),
          'maxScore': 100.0,
          if (lessonScores.isNotEmpty) 'lessonScores': lessonScores,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = userProfileNotifier.value.uid;

    if (uid.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(scheme, context),
        body: Center(child: Text(AppLocalizations.of(context).translate('please_login_first'))),
      );
    }

    final grade = userProfileNotifier.value.grade;
    final cleanGrade = grade.isEmpty ? 'الصف السابع' : grade;
    final semester = userProfileNotifier.value.semester;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: _buildAppBar(scheme, context),
      body: StreamBuilder<QuerySnapshot>(
        stream: _svc.getGradesStream(uid, semester: semester, grade: cleanGrade),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _GradesShimmerLoading();
          }

          final entries = _parseEntries(snap);

          if (entries.isEmpty) {
            return _EmptyState(scheme: scheme);
          }

          final avg = entries.isEmpty
              ? 0.0
              : entries.map((e) => e.ratio).reduce((a, b) => a + b) /
                  entries.length;
          final needsImprovement =
              entries.where((e) => e.needsImprovement).toList();

          return CustomScrollView(
            slivers: [
              // ── الجزء العلوي: ملخص المعدل ──
              SliverToBoxAdapter(
                child: _GpaSummaryHeader(
                  scheme: scheme,
                  entries: entries,
                  avgRatio: avg,
                  animCtrl: _animCtrl,
                ),
              ),

              // ── عنوان الشبكة ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    AppLocalizations.of(context).translate('subject_performance'),
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),

              // ── الجزء الأوسط: GridView دوائر المواد ──
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final e = entries[i];
                      final delay = i * 0.08;
                      return AnimatedBuilder(
                        animation: _animCtrl,
                        builder: (_, __) {
                          final t = (((_animCtrl.value - delay) / (1 - delay))
                                  .clamp(0.0, 1.0))
                              .toDouble();
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - t)),
                              child: _SubjectCircleCard(
                                entry: e,
                                scheme: scheme,
                                onTap: () =>
                                    _showRatingDialog(context, e, scheme),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: entries.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.65,
                  ),
                ),
              ),

            ],
          );
        },
      ),
    );
  }

  List<GradeEntry> _parseEntries(AsyncSnapshot<QuerySnapshot> snap) {
    if (!snap.hasData || snap.data!.docs.isEmpty) return [];
    
    final Map<String, GradeEntry> uniqueEntries = {};
    for (final doc in snap.data!.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final rawSubj = (d['subjectId'] ?? '') as String;
      if (rawSubj.isEmpty) continue;

      // تنظيف الاسم من الصف أو المسميات الإنجليزية لتوحيد المفتاح ومنع الازدواجية
      String cleanSubj = rawSubj.split('__').first.trim();
      const engMap = {
        'math': 'الرياضيات',
        'science': 'العلوم',
        'arabic': 'اللغة العربية',
        'english': 'اللغة الإنجليزية',
        'social': 'التربية الاجتماعية',
        'islamic': 'التربية الإسلامية',
        'quran': 'القرآن الكريم',
      };
      if (engMap.containsKey(cleanSubj.toLowerCase())) {
        cleanSubj = engMap[cleanSubj.toLowerCase()]!;
      }

      double score = (d['score'] as num?)?.toDouble() ?? 0.0;
      double maxScore = (d['maxScore'] as num?)?.toDouble() ?? 100.0;
      final lessonScores = d['lessonScores'] as Map? ?? {};

      if (lessonScores.isNotEmpty) {
        // إذا كان هناك سجل لدرجات الدروس، نحسب المتوسط الفعلي للدروس التي أنجزها واختبرها الطالب
        double sumRatio = 0.0;
        for (final val in lessonScores.values) {
          final numVal = (val as num?)?.toDouble() ?? 0.0;
          sumRatio += (numVal > 1.0 ? numVal / 100.0 : numVal).clamp(0.0, 1.0);
        }
        final ratio = (sumRatio / lessonScores.length).clamp(0.0, 1.0);
        score = ratio * 100.0;
        maxScore = 100.0;
      } else if (score <= 1.0 && score > 0.0 && maxScore == 100.0) {
        // إذا تم تخزين الدرجة كنسبة كسرية من 0 إلى 1 بدلاً من نسبة مئوية
        score = (score * 100.0).clamp(0.0, 100.0);
      }

      final entry = GradeEntry(
        subject: cleanSubj,
        score: score,
        maxScore: maxScore <= 0 ? 100.0 : maxScore,
        color: GradeEntry.colorForSubject(cleanSubj),
        icon: GradeEntry.iconForSubject(cleanSubj),
      );

      // الاحتفاظ بالدرجة الأعلى في حال وجود مستندين (قديم وجديد) لنفس المادة
      if (!uniqueEntries.containsKey(cleanSubj) ||
          entry.ratio > uniqueEntries[cleanSubj]!.ratio) {
        uniqueEntries[cleanSubj] = entry;
      }
    }

    return uniqueEntries.values.toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
  }

  PreferredSizeWidget _buildAppBar(ColorScheme scheme, BuildContext context) {
    return AppBar(
      surfaceTintColor: Colors.transparent,
      backgroundColor: scheme.surfaceContainerLowest,
      title: Text(
        AppLocalizations.of(context).translate('grades_title'),
        style: GoogleFonts.tajawal(
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }

  void _showRatingDialog(
      BuildContext context, GradeEntry entry, ColorScheme scheme) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // دائرة الأيقونة
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(entry.icon, color: entry.color, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  entry.subject,
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                // الدرجة الكبيرة
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: entry.ratio,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        backgroundColor: entry.color.withValues(alpha: 0.12),
                        color: entry.color,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${entry.percent}%',
                          style: GoogleFonts.tajawal(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: entry.color,
                          ),
                        ),
                        Text(
                          '${entry.score.toInt()}/${entry.maxScore.toInt()}',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // شارة التقييم
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: entry.ratingColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: entry.ratingColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate(entry.ratingKey),
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: entry.ratingColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _ratingMessage(entry),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: entry.color,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'إغلاق',
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ratingMessage(GradeEntry e) {
    if (e.percent >= 95) {
      return 'أداء استثنائي! أنت في القمة 🌟 استمر في هذا التفوق.';
    }
    if (e.percent >= 90) {
      return 'ممتاز! مستوى رائع يدل على جهد حقيقي 🎯';
    }
    if (e.percent >= 80) {
      return 'جيد جداً! مستوى قوي، مع قليل من الجهد ستصل للقمة 💪';
    }
    if (e.percent >= 70) {
      return 'جيد، لكن هناك مجال للتحسين. خصص وقتاً إضافياً لهذه المادة 📚';
    }
    if (e.percent >= 60) {
      return 'النتيجة مقبولة، لكن تحتاج إلى مراجعة منهجية ومتواصلة 🔁';
    }
    return 'تحتاج إلى اهتمام عاجل بهذه المادة. لا تتردد في طلب المساعدة 🆘';
  }
}

// ═══════════════════════════════════════════════════════════════
// رأس الصفحة — ملخص المعدل الإجمالي
// ═══════════════════════════════════════════════════════════════
class _GpaSummaryHeader extends StatelessWidget {
  const _GpaSummaryHeader({
    required this.scheme,
    required this.entries,
    required this.avgRatio,
    required this.animCtrl,
  });

  final ColorScheme scheme;
  final List<GradeEntry> entries;
  final double avgRatio;
  final AnimationController animCtrl;

  String _overallRating() {
    final p = (avgRatio * 100).round();
    if (p >= 95) return 'rating_exc_plus';
    if (p >= 90) return 'rating_exc';
    if (p >= 80) return 'rating_vg';
    if (p >= 70) return 'rating_good';
    if (p >= 60) return 'rating_acc';
    return 'rating_poor';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (avgRatio * 100).round();
    final best = entries.isNotEmpty
        ? entries.reduce((a, b) => a.ratio > b.ratio ? a : b)
        : null;
    final passed = entries.where((e) => e.percent >= 60).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.8),
            scheme.tertiary,
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: scheme.tertiary.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // دائرة المعدل
              AnimatedBuilder(
                animation: animCtrl,
                builder: (_, __) => SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: avgRatio * animCtrl.value,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          color: Colors.white,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$pct%',
                            style: GoogleFonts.tajawal(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context).translate('your_gpa'),
                            style: GoogleFonts.tajawal(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate(_overallRating()),
                      style: GoogleFonts.tajawal(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${entries.length} ${AppLocalizations.of(context).translate('subjects_count_label')} — $passed ${AppLocalizations.of(context).translate('passed_count_label')}',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (best != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 15, color: Colors.amber.shade300),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${AppLocalizations.of(context).translate('the_best')}: ${best.subject} (${best.percent}%)',
                              style: GoogleFonts.tajawal(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // شريط التقدم العام
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('general_progress'),
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$pct / 100',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: animCtrl,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: avgRatio * animCtrl.value,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// بطاقة مادة دراسية — دائرة تقدم مخصصة
// ═══════════════════════════════════════════════════════════════
class _SubjectCircleCard extends StatelessWidget {
  const _SubjectCircleCard({
    required this.entry,
    required this.scheme,
    required this.onTap,
  });

  final GradeEntry entry;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              entry.color.withValues(alpha: 0.1),
              scheme.surfaceContainerLowest,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: entry.needsImprovement
                ? entry.ratingColor.withValues(alpha: 0.4)
                : entry.color.withValues(alpha: 0.15),
            width: entry.needsImprovement ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: entry.color.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // الدائرة المخصصة
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CustomPaint(
                    painter: _CircleProgressPainter(
                      progress: entry.ratio,
                      color: entry.color,
                      bgColor: entry.color.withValues(alpha: 0.1),
                      strokeWidth: 7,
                    ),
                    child: Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: entry.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          entry.icon,
                          color: entry.color,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  entry.subject,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.tajawal(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.percent}%',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: entry.color,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.ratingColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate(entry.ratingKey),
                    style: GoogleFonts.tajawal(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: entry.ratingColor,
                    ),
                  ),
                ),
                if (entry.needsImprovement)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: entry.ratingColor.withValues(alpha: 0.7),
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

// ═══════════════════════════════════════════════════════════════
// رسام الدائرة المخصصة
// ═══════════════════════════════════════════════════════════════
class _CircleProgressPainter extends CustomPainter {
  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // خلفية
    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // التقدم
    if (progress > 0) {
      final fgPaint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // نبدأ من الأعلى (-π/2)
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircleProgressPainter old) =>
      old.progress != progress || old.color != color;
}

// ═══════════════════════════════════════════════════════════════
// بطاقة مادة تحتاج إلى تحسين
// ═══════════════════════════════════════════════════════════════
// Removed widgets: ImprovementCard, WeeklyGradesChart, SectionTitle, AllGoodCard

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 80,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد درجات حالياً',
              style: GoogleFonts.tajawal(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'قم بإنهاء بعض الدروس والاختبارات لتظهر نتائجك وتقييمك هنا.',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 15,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradesShimmerLoading extends StatelessWidget {
  const _GradesShimmerLoading();

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerPlaceholder(height: 160, borderRadius: 28),
            const SizedBox(height: 32),
            const ShimmerPlaceholder(width: 150, height: 24),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                itemCount: 6,
                itemBuilder: (ctx, i) => const ShimmerPlaceholder(borderRadius: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
