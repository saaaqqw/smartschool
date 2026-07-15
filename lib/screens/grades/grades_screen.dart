import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firebase_service.dart';
import '../../core/stores/user_profile_store.dart';
import '../../data/subject_curriculum.dart';

// ═══════════════════════════════════════════════════════════════
// نموذج البيانات
// ═══════════════════════════════════════════════════════════════
class GradeEntry {
  const GradeEntry({
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.color,
    required this.icon,
  });

  final String subject;
  final double score;
  final double maxScore;
  final Color color;
  final IconData icon;

  double get ratio => maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0;
  int get percent => (ratio * 100).round();

  /// التقييم النصي بناءً على النسبة المئوية
  String get rating {
    if (percent >= 95) return 'ممتاز+';
    if (percent >= 90) return 'ممتاز';
    if (percent >= 80) return 'جيد جداً';
    if (percent >= 70) return 'جيد';
    if (percent >= 60) return 'مقبول';
    return 'ضعيف';
  }

  /// هل تحتاج هذه المادة إلى تحسين (جيد أو أقل)
  bool get needsImprovement => percent < 80;

  Color get ratingColor {
    if (percent >= 90) return const Color(0xFF00897B);
    if (percent >= 80) return const Color(0xFF1E88E5);
    if (percent >= 70) return const Color(0xFFFB8C00);
    if (percent >= 60) return const Color(0xFFE53935);
    return const Color(0xFFB71C1C);
  }

  static Color colorForSubject(String subject) {
    const map = {
      'الرياضيات': Color(0xFF5C6BC0),
      'العلوم': Color(0xFF26A69A),
      'التربية الإسلامية': Color(0xFF7E57C2),
      'القرآن الكريم': Color(0xFF43A047),
      'اللغة العربية': Color(0xFFE53935),
      'اللغة الإنجليزية': Color(0xFF1E88E5),
      'الإنجليزية': Color(0xFF1E88E5),
      'الاجتماعيات': Color(0xFF6D4C41),
      'الفيزياء': Color(0xFF00838F),
      'الكيمياء': Color(0xFFAD1457),
      'الأحياء': Color(0xFF558B2F),
      'الحاسوب': Color(0xFF37474F),
    };
    return map[subject] ?? Colors.blueGrey;
  }

  static IconData iconForSubject(String subject) {
    const map = {
      'الرياضيات': Icons.calculate_rounded,
      'العلوم': Icons.science_rounded,
      'التربية الإسلامية': Icons.mosque_rounded,
      'القرآن الكريم': Icons.menu_book_rounded,
      'اللغة العربية': Icons.translate_rounded,
      'اللغة الإنجليزية': Icons.abc_rounded,
      'الإنجليزية': Icons.abc_rounded,
      'الاجتماعيات': Icons.public_rounded,
      'الفيزياء': Icons.bolt_rounded,
      'الكيمياء': Icons.biotech_rounded,
      'الأحياء': Icons.eco_rounded,
      'الحاسوب': Icons.computer_rounded,
    };
    return map[subject] ?? Icons.school_rounded;
  }
}

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
      duration: const Duration(milliseconds: 900),
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

    for (final s in kCoreSubjects) {
      final docRef = FirebaseFirestore.instance
          .collection('grades')
          .doc('${uid}_${s.title}');
      final snap = await docRef.get();

      if (!snap.exists) {
        double calculatedScore = 0.0;
        Map<String, dynamic> lessonScores = {};
        try {
          final subjDoc = await FirebaseFirestore.instance
              .collection('subjects')
              .doc('${s.title} - $cleanGrade')
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
            .doc('${uid}_${s.title}')
            .set({
          'userId': uid,
          'subjectId': s.title,
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
        body: const Center(child: Text('يرجى تسجيل الدخول أولاً.')),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: _buildAppBar(scheme, context),
      body: StreamBuilder<QuerySnapshot>(
        stream: _svc.getGradesStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                  child: _SectionTitle(
                    icon: Icons.grid_view_rounded,
                    title: 'أداء المواد الدراسية',
                    scheme: scheme,
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

              // ── الجزء السفلي: المواد التي تحتاج إلى تحسين ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle(
                    icon: Icons.trending_up_rounded,
                    title: 'مواد تحتاج إلى تحسين',
                    scheme: scheme,
                    badgeCount: needsImprovement.length,
                  ),
                ),
              ),

              if (needsImprovement.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _AllGoodCard(scheme: scheme),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ImprovementCard(
                          entry: needsImprovement[i],
                          scheme: scheme,
                          rank: i + 1,
                        ),
                      ),
                      childCount: needsImprovement.length,
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
      String cleanSubj = rawSubj.split(' - ').first.trim();
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
        'الدرجات',
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
                    entry.rating,
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
    if (p >= 95) return 'ممتاز+';
    if (p >= 90) return 'ممتاز';
    if (p >= 80) return 'جيد جداً';
    if (p >= 70) return 'جيد';
    if (p >= 60) return 'مقبول';
    return 'ضعيف';
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.8),
            scheme.tertiary.withValues(alpha: 0.7),
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                            'معدلك',
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
                      _overallRating(),
                      style: GoogleFonts.tajawal(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${entries.length} مادة — $passed ناجحة',
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
                              'الأفضل: ${best.subject} (${best.percent}%)',
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
                    'التقدم العام',
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
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: entry.needsImprovement
                ? entry.ratingColor.withValues(alpha: 0.35)
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: entry.needsImprovement ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: entry.color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
                    entry.rating,
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
class _ImprovementCard extends StatelessWidget {
  const _ImprovementCard({
    required this.entry,
    required this.scheme,
    required this.rank,
  });

  final GradeEntry entry;
  final ColorScheme scheme;
  final int rank;

  String _advice() {
    if (entry.percent >= 70) {
      return 'قريب من المستوى الجيد جداً — ركّز على حل التمارين وراجع الدروس الأضعف.';
    }
    if (entry.percent >= 60) {
      return 'تحتاج إلى مراجعة منتظمة وتخصيص وقت يومي إضافي لهذه المادة.';
    }
    return 'هذه المادة تحتاج إلى اهتمام عاجل — ابدأ من الأساسيات واطلب المساعدة من معلمك.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: entry.ratingColor.withValues(alpha: 0.35),
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
              color: entry.ratingColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: entry.ratingColor,
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
                  value: entry.ratio,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: entry.color.withValues(alpha: 0.12),
                  color: entry.color,
                ),
                Text(
                  '${entry.percent}%',
                  style: GoogleFonts.tajawal(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: entry.color,
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
                        entry.subject,
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: entry.ratingColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.rating,
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: entry.ratingColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _advice(),
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                // شريط التقدم
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: entry.ratio,
                    minHeight: 5,
                    backgroundColor: entry.color.withValues(alpha: 0.12),
                    color: entry.color,
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

// ═══════════════════════════════════════════════════════════════
// ويدجت مساعدة
// ═══════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
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

class _AllGoodCard extends StatelessWidget {
  const _AllGoodCard({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF00897B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_rounded,
            color: Color(0xFF00897B),
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رائع! كل المواد بمستوى جيد جداً ✨',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF00897B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'استمر في هذا المستوى المتميز وحافظ على جهودك.',
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد درجات مسجّلة حالياً',
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
