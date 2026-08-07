import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/stores/user_profile_store.dart';
import '../../core/stores/study_timer_store.dart';
import '../../services/weekly_schedule_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../services/connectivity_service.dart';
import '../grades/grades_screen.dart';
import '../study/study_plan_screen.dart';
import '../../widgets/profile_image_picker_sheet.dart';
import '../auth/profile_editor_screen.dart';
import '../../core/l10n/app_localizations.dart';
import '../notifications/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/grade_entry.dart';
import 'widgets/dashboard_stats_widgets.dart';
import 'widgets/radar_plan_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onNavigateToPage});

  final ValueChanged<int>? onNavigateToPage;

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const DashboardScreen());
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _scheduleService = WeeklyScheduleService();
  late final AnimationController _animCtrl;

  List<double> _weeklyAverages = List.filled(7, 0.0);
  List<String> _weeklyLabels = List.filled(7, '');
  bool _isLoadingWeekly = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _loadScheduleSettings();
    _setupTimerFirebaseSync();
    _fetchWeeklyData();
  }

  Future<void> _fetchWeeklyData() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      
      final Map<int, List<double>> dailyScores = {};
      final List<String> labels = List.filled(7, '');
      const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

      for (int i = 0; i < 7; i++) {
        final targetDate = todayMidnight.subtract(Duration(days: 6 - i));
        labels[i] = dayKeys[targetDate.weekday - 1];
      }

      for (final doc in query.docs) {
        final d = doc.data();
        final type = d['type'] as String? ?? '';
        if (type == 'quiz_result' || type == 'unit_exam_result') {
          final timestamp = d['createdAt'] as Timestamp?;
          if (timestamp != null) {
            final date = timestamp.toDate();
            final dateMidnight = DateTime(date.year, date.month, date.day);
            final diffDays = todayMidnight.difference(dateMidnight).inDays;
            
            if (diffDays >= 0 && diffDays < 7) {
              final index = 6 - diffDays;
              final score = (d['score'] as num?)?.toDouble() ?? 0.0;
              dailyScores.putIfAbsent(index, () => []).add(score);
            }
          }
        }
      }

      final List<double> averages = List.filled(7, 0.0);
      for (int i = 0; i < 7; i++) {
        if (dailyScores.containsKey(i) && dailyScores[i]!.isNotEmpty) {
          final sum = dailyScores[i]!.reduce((a, b) => a + b);
          averages[i] = sum / dailyScores[i]!.length;
        }
      }

      if (mounted) {
        setState(() {
          _weeklyAverages = averages;
          _weeklyLabels = labels;
          _isLoadingWeekly = false;
        });
      }
    } catch (e) {
       debugPrint('Error loading weekly data: $e');
       if (mounted) setState(() => _isLoadingWeekly = false);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    // حفظ حالة المؤقت عند مغادرة الشاشة
    _saveTimerToFirebase();
    super.dispose();
  }

  /// ربط callback المؤقت بـ Firestore لحفظ الحالة تلقائياً
  void _setupTimerFirebaseSync() {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;
    studyTimerStore.onStateChanged = (elapsed, targetMinutes, isRunning) {
      FirebaseSyncService.saveTimerState(
        uid: uid,
        elapsed: elapsed,
        targetMinutes: targetMinutes,
        isRunning: isRunning,
      ).ignore();

      // حفظ جلسة الدراسة اليومية أيضاً
      FirebaseSyncService.saveStudySession(
        uid: uid,
        elapsedMinutes: elapsed.inMinutes,
        targetMinutes: targetMinutes,
      ).ignore();
    };
  }

  void _saveTimerToFirebase() {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;
    FirebaseSyncService.saveTimerState(
      uid: uid,
      elapsed: studyTimerStore.value.elapsed,
      targetMinutes: studyTimerStore.value.targetMinutes,
      isRunning: false, // نوقف المؤقت عند الخروج
    ).ignore();
  }

  Future<void> _loadScheduleSettings() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;
    try {
      final ws = await _scheduleService.fetchSchedule(uid);
      if (mounted) {
        studyTimerStore.setTarget(ws.durationMinutes);
      }
    } catch (_) {}
  }

  void _openTab(BuildContext context, int index, VoidCallback pushRoute) {
    if (widget.onNavigateToPage != null) {
      widget.onNavigateToPage!(index);
    } else {
      pushRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = userProfileNotifier.value.uid;

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<UserProfile>(
          valueListenable: userProfileNotifier,
          builder: (context, profile, _) {
            return CustomScrollView(
              slivers: [
                // ── مؤشر حالة الاتصال ─────────────────────────────────
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: ConnectivityService.isOnlineNotifier,
                    builder: (ctx, isOnline, _) {
                      if (isOnline) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: scheme.error, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded,
                                size: 16, color: scheme.onErrorContainer),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context).translate('offline_mode'),
                              style: GoogleFonts.tajawal(
                                fontSize: 12,
                                color: scheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: _Header(
                      scheme: scheme,
                      profile: profile,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  sliver: SliverToBoxAdapter(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: uid.isEmpty
                          ? const Stream.empty()
                          : FirebaseFirestore.instance
                              .collection('grades')
                              .where('userId', isEqualTo: uid)
                              .where('semester', isEqualTo: profile.semester)
                              .snapshots(),
                      builder: (context, snapshot) {
                        final entries = snapshot.hasData
                            ? GradeEntry.parseList(snapshot.data!.docs)
                            : <GradeEntry>[];
                        
                        final needsImprovement = entries.where((e) => e.needsImprovement).toList();

                        return Column(
                          children: [
                            // ── خطة اليوم (Radar Chart) ──
                            RadarPlanCard(
                              entries: entries,
                              scheme: scheme,
                              onOpenPlan: () {
                                _openTab(
                                  context,
                                  2,
                                  () => Navigator.of(context).push(StudyPlanScreen.route()),
                                );
                              },
                              onOpenGrades: () {
                                _openTab(
                                  context,
                                  3,
                                  () => Navigator.of(context).push(GradesScreen.route()),
                                );
                              },
                            ),

                            // ── أداء آخر 7 أيام ──
                            Padding(
                              padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                              child: WeeklyGradesChart(
                                scheme: scheme,
                                averages: _weeklyAverages,
                                labels: _weeklyLabels,
                                isLoading: _isLoadingWeekly,
                                animCtrl: _animCtrl,
                              ),
                            ),

                            // ── المواد التي تحتاج تحسين ──
                            Padding(
                              padding: const EdgeInsets.only(top: 24.0, bottom: 10.0),
                              child: SectionTitle(
                                icon: Icons.trending_up_rounded,
                                title: AppLocalizations.of(context).translate('subjects_need_improvement'),
                                scheme: scheme,
                                badgeCount: needsImprovement.length,
                              ),
                            ),
                            
                            if (needsImprovement.isEmpty)
                              AllGoodCard(scheme: scheme)
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: needsImprovement.length,
                                itemBuilder: (ctx, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: ImprovementCard(
                                    entry: needsImprovement[i],
                                    scheme: scheme,
                                    rank: i + 1,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.scheme,
    required this.profile,
  });

  final ColorScheme scheme;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final first = firstNameFromFullName(profile.fullName);
    final imageProvider = getProfileImageProvider(profile.profileImageUrl);
    // RTL: first child in Row aligns to the visual right.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(ProfileEditorScreen.route()),
          child: CircleAvatar(
            radius: 32,
            backgroundColor: scheme.primaryContainer,
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: scheme.onPrimaryContainer,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppLocalizations.of(context).translate('welcome_back')} $first',
                style: GoogleFonts.tajawal(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${AppLocalizations.of(context).translate('grade')} ${profile.grade}',
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const _NotificationBellButton(),
      ],
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = userProfileNotifier.value;
    final studentGrade = profile.grade.trim();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notifications').snapshots(),
      builder: (context, snapshot) {
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, prefsSnap) {
            int unreadCount = 0;
            bool notificationsEnabled = true;
            if (snapshot.hasData && prefsSnap.hasData) {
              notificationsEnabled = prefsSnap.data!.getBool('notifications_enabled') ?? true;
              if (notificationsEnabled) {
                final readIds = (prefsSnap.data!.getStringList('read_notification_ids') ?? []).toSet();
                final docs = snapshot.data!.docs.where((d) {
                  final data = d.data() as Map<String, dynamic>? ?? {};
                  final target = (data['targetGrade'] ?? 'الكل').toString().trim();
                  if (target == 'الكل' || target == 'جميع الطلاب') return true;
                  if (studentGrade.isNotEmpty && target == studentGrade) return true;
                  return false;
                });
                unreadCount = docs.where((d) => !readIds.contains(d.id)).length;
              }
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton.filledTonal(
                  onPressed: () {
                    Navigator.push(context, NotificationsScreen.route());
                  },
                  icon: Icon(
                    notificationsEnabled ? Icons.notifications_rounded : Icons.notifications_off_rounded,
                    color: notificationsEnabled ? null : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: scheme.surface, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
