import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/stores/user_profile_store.dart';
import '../../services/badges_service.dart';
import '../../services/firebase_sync_service.dart';

/// واجهة لوحة ولي الأمر وتقارير الأداء الشاملة (Parent Performance Report Screen)
/// تعرض الملخص الأكاديمي للطالب، ساعات الدراسة، الشارات المكتسبة، وإمكانية نسخ التقرير أو مشاركته.
class ParentReportScreen extends StatefulWidget {
  const ParentReportScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => const ParentReportScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  State<ParentReportScreen> createState() => _ParentReportScreenState();
}

class _ParentReportScreenState extends State<ParentReportScreen> {
  bool _isLoading = true;
  List<BadgeModel> _badges = [];
  List<Map<String, dynamic>> _studySessions = [];
  Map<String, double> _subjectScores = {};
  int _totalCompletedLessons = 0;
  double _generalAverage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAllReportData();
  }

  Future<void> _loadAllReportData() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. جلب الشارات
      final badges = await BadgesService.fetchStudentBadges(uid);

      // 2. جلب الجلسات الأسبوعية
      final sessions = await FirebaseSyncService.fetchWeeklyStudySessions(uid);

      // 3. جلب الدرجات وحساب المعدل العام
      final db = FirebaseFirestore.instance;
      final gradesSnap = await db.collection('grades').where('userId', isEqualTo: uid).get();

      Map<String, double> scores = {};
      double totalPercentageSum = 0;
      int subjectCount = 0;

      for (final doc in gradesSnap.docs) {
        final data = doc.data();
        final subjectId = data['subjectId'] as String? ?? '';
        final cleanTitle = subjectId.split(' - ').first;

        double scoreVal = (data['score'] as num?)?.toDouble() ?? 0.0;
        double maxScoreVal = (data['maxScore'] as num?)?.toDouble() ?? 0.0;
        final lessonScoresRaw = data['lessonScores'] as Map? ?? {};

        if (lessonScoresRaw.isNotEmpty) {
          double sumLessonScores = 0;
          for (var entry in lessonScoresRaw.entries) {
            double raw = (entry.value as num?)?.toDouble() ?? 0.0;
            if (raw > 1.0 && raw <= 100.0) {
              sumLessonScores += raw / 100.0;
            } else {
              sumLessonScores += raw.clamp(0.0, 1.0);
            }
          }
          scoreVal = sumLessonScores;
          maxScoreVal = lessonScoresRaw.length.toDouble();
        }

        double finalPercentage = 0.0;
        if (maxScoreVal > 0) {
          double ratio = (scoreVal / maxScoreVal).clamp(0.0, 1.0);
          finalPercentage = ratio * 100.0;
        } else if (scoreVal > 0) {
          if (scoreVal <= 1.0) {
            finalPercentage = scoreVal * 100.0;
          } else {
            finalPercentage = scoreVal.clamp(0.0, 100.0);
          }
        }

        scores[cleanTitle] = finalPercentage;
        totalPercentageSum += finalPercentage;
        subjectCount++;
      }

      double avg = subjectCount > 0 ? totalPercentageSum / subjectCount : 0.0;

      // 4. إجمالي الدروس المكتملة
      int completedLessons = 0;
      final progressSnap = await db.collection('users').doc(uid).collection('progress').get();
      for (final doc in progressSnap.docs) {
        completedLessons += (doc.data()['totalLessonsCompleted'] as num?)?.toInt() ?? 0;
      }

      if (mounted) {
        setState(() {
          _badges = badges;
          _studySessions = sessions;
          _subjectScores = scores;
          _generalAverage = avg;
          _totalCompletedLessons = completedLessons;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading parent report: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyReportToClipboard() {
    final profile = userProfileNotifier.value;
    final buffer = StringBuffer();
    buffer.writeln('📋 التقرير الأكاديمي الشامل - المدرسة الذكية');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 الطالب: ${profile.fullName}');
    buffer.writeln('🏫 المدرسة: ${profile.school} | ${profile.grade}');
    buffer.writeln('📊 المعدل العام الأكاديمي: ${_generalAverage.toStringAsFixed(1)}%');
    buffer.writeln('✅ إجمالي الدروس المنجزة: $_totalCompletedLessons درس');
    buffer.writeln('🏆 الشارات المكتسبة: ${_badges.where((b) => b.isUnlocked).length} من ${_badges.length}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📚 معدلات المواد الدرجة الحالية:');
    if (_subjectScores.isEmpty) {
      buffer.writeln('   • لا توجد درجات مسجلة بعد.');
    } else {
      _subjectScores.forEach((subject, score) {
        buffer.writeln('   • $subject: ${score.toStringAsFixed(1)}%');
      });
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('⏰ نشاط الدراسة الأسبوعي:');
    int totalStudyMinutes = _studySessions.fold(0, (accumulated, s) => accumulated + ((s['totalMinutes'] as num?)?.toInt() ?? 0));
    buffer.writeln('   • إجمالي وقت الدراسة: $totalStudyMinutes دقيقة في آخر 7 أيام');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('تاريخ إصدار التقرير: ${DateTime.now().toString().split('.').first}');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ ملخص تقرير الطالب إلى الحافظة بنجاح 📋✅',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF1B6B93),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = userProfileNotifier.value;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          'تقارير ولي الأمر والأداء الأكاديمي 📊',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _copyReportToClipboard,
            icon: const Icon(Icons.share_rounded),
            tooltip: 'نسخ ومشاركة التقرير',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllReportData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. بطاقة ملخص الطالب والمعدل العام
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    color: const Color(0xFF1B6B93),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white24,
                                child: Text(
                                  profile.fullName.isNotEmpty ? profile.fullName[0] : 'S',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.fullName.isNotEmpty ? profile.fullName : 'طالب المدرسة الذكية',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${profile.school} • ${profile.grade}',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 13.5,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryStat(
                                label: 'المعدل الأكاديمي العام',
                                value: '${_generalAverage.toStringAsFixed(1)}%',
                                icon: Icons.insights_rounded,
                              ),
                              Container(width: 1, height: 40, color: Colors.white24),
                              _buildSummaryStat(
                                label: 'الدروس المكتملة',
                                value: '$_totalCompletedLessons درس',
                                icon: Icons.task_alt_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. زر المشاركة والنسخ
                  ElevatedButton.icon(
                    onPressed: _copyReportToClipboard,
                    icon: const Icon(Icons.copy_all_rounded, size: 22),
                    label: Text(
                      'نسخ ومشاركة التقرير مع الأسرة والمدرسة 📋',
                      style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 3. أداء المواد الدراسية
                  Text(
                    'أداء المواد الدراسية (معدل الدروس المختبرة):',
                    style: GoogleFonts.tajawal(fontSize: 16.5, fontWeight: FontWeight.w800, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  if (_subjectScores.isEmpty)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'لم يقدم الطالب أي اختبارات للدروس حتى الآن.',
                            style: GoogleFonts.tajawal(fontSize: 14.5, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._subjectScores.entries.map((e) {
                      final title = e.key;
                      final score = e.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1B6B93).withValues(alpha: 0.15),
                            child: const Icon(Icons.menu_book_rounded, color: Color(0xFF1B6B93)),
                          ),
                          title: Text(
                            title,
                            style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 15.5),
                          ),
                          subtitle: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (score / 100.0).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: scheme.surfaceContainerHighest,
                              color: score >= 85 ? Colors.green : (score >= 70 ? Colors.orange : Colors.red),
                            ),
                          ),
                          trailing: Text(
                            '${score.toStringAsFixed(1)}%',
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: score >= 85 ? Colors.green : (score >= 70 ? Colors.orange : Colors.red),
                            ),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 28),

                  // 4. الأوسمة والشارات المكتسبة (Gamification)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الأوسمة والشارات التقديرية (${_badges.where((b) => b.isUnlocked).length} من ${_badges.length}):',
                        style: GoogleFonts.tajawal(fontSize: 16.5, fontWeight: FontWeight.w800, color: scheme.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: _badges.length,
                    itemBuilder: (context, index) {
                      final b = _badges[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: b.isUnlocked ? b.color.withValues(alpha: 0.12) : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: b.isUnlocked ? b.color : scheme.outline.withValues(alpha: 0.2),
                            width: b.isUnlocked ? 1.8 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(b.icon, size: 32, color: b.isUnlocked ? b.color : Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              b.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.tajawal(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: b.isUnlocked ? scheme.onSurface : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              b.isUnlocked ? 'مكتسب ✨' : 'مقفل 🔒',
                              style: GoogleFonts.tajawal(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: b.isUnlocked ? b.color : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryStat({required String label, required String value, required IconData icon}) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.tajawal(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
