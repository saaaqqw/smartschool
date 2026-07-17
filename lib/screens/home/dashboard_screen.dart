import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/stores/user_profile_store.dart';
import '../../core/stores/study_timer_store.dart';
import '../../services/weekly_schedule_service.dart';
import '../../services/firebase_sync_service.dart';
import '../grades/grades_screen.dart';
import '../settings/settings_screen.dart';
import '../study/study_plan_screen.dart';
import '../subjects/subjects_screen.dart';
import '../chat/chat_screen.dart';
import '../../widgets/profile_image_picker_sheet.dart';

import '../../data/subject_curriculum.dart';
import '../../core/l10n/app_localizations.dart';
import '../notifications/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _loadScheduleSettings();
    _setupTimerFirebaseSync();
  }

  @override
  void dispose() {
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
    final onPlan = scheme.primaryContainer;
    final onPlanFg = scheme.onPrimaryContainer;
    final uid = userProfileNotifier.value.uid;

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<UserProfile>(
          valueListenable: userProfileNotifier,
          builder: (context, profile, _) {
            return StreamBuilder<QuerySnapshot>(
              stream: uid.isEmpty
                  ? const Stream.empty()
                  : FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('progress')
                      .snapshots(),
              builder: (context, snapshot) {
                double totalProgress = 0;
                int count = 0;

                if (snapshot.hasData) {
                  final isSecondSemester = profile.semester == 'الفصل الدراسي الثاني';
                  for (var doc in snapshot.data!.docs) {
                    final isDocSecondSem = doc.id.endsWith(' - الفصل الدراسي الثاني');
                    if (isSecondSemester != isDocSecondSem) continue;

                    final data = doc.data() as Map<String, dynamic>?;
                    final unitProgress = data?['unitProgress'] as Map<String, dynamic>? ?? {};
                    if (unitProgress.isNotEmpty) {
                      double subTotal = 0;
                      for (final v in unitProgress.values) {
                        subTotal += (v as num).toDouble();
                      }
                      totalProgress += (subTotal / 6); // Assuming 6 units per subject
                      count++;
                    }
                  }
                }

                // Average progress across all subjects, or 0.0 if no data
                final avgProgress = count > 0 ? (totalProgress / kCoreSubjects.length) : 0.0;

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: _Header(
                          scheme: scheme,
                          profile: profile,
                          onSettings: () {
                            _openTab(
                              context,
                              4,
                              () => Navigator.of(context).push(SettingsScreen.route()),
                            );
                          },
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      sliver: SliverToBoxAdapter(
                        child: _TodayPlanCard(
                          backgroundColor: onPlan,
                          foregroundColor: onPlanFg,
                          progress: avgProgress,
                          onOpenPlan: () {
                            _openTab(
                              context,
                              2,
                              () => Navigator.of(context).push(StudyPlanScreen.route()),
                            );
                          },
                        ),
                      ),
                    ),
                    // تمت إزالة قسم المهام اليومية من هنا ونقله إلى صفحة الخطة.
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      sliver: SliverToBoxAdapter(
                        child: _QuickActions(
                          onStartStudy: () {
                            _openTab(
                              context,
                              1,
                              () => Navigator.of(context).push(SubjectsScreen.route()),
                            );
                          },
                          onGrades: () {
                            _openTab(
                              context,
                              3,
                              () => Navigator.of(context).push(GradesScreen.route()),
                            );
                          },
                          onReview: () {
                            _openTab(
                              context,
                              2,
                              () => Navigator.of(context).push(StudyPlanScreen.route()),
                            );
                          },
                          onChat: () {
                            Navigator.of(context).push(ChatScreen.route());
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
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
    required this.onSettings,
  });

  final ColorScheme scheme;
  final UserProfile profile;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final first = firstNameFromFullName(profile.fullName);
    final imageProvider = getProfileImageProvider(profile.profileImageUrl);
    // RTL: first child in Row aligns to the visual right.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => ProfileImagePickerSheet.show(context),
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
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_rounded),
        ),
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

class _TodayPlanCard extends StatelessWidget {
  const _TodayPlanCard({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.progress,
    required this.onOpenPlan,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final double progress;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();

    return Card(
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenPlan,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    color: foregroundColor,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context).translate('today_plan'),
                    style: GoogleFonts.tajawal(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: foregroundColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  SizedBox(
                    height: 88,
                    width: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 88,
                          width: 88,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                            backgroundColor:
                                foregroundColor.withValues(alpha: 0.2),
                            color: foregroundColor,
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: GoogleFonts.tajawal(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: foregroundColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).translate('completed'),
                          style: GoogleFonts.tajawal(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: foregroundColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor:
                                foregroundColor.withValues(alpha: 0.2),
                            color: foregroundColor,
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
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onStartStudy,
    required this.onGrades,
    required this.onReview,
    required this.onChat,
  });

  final VoidCallback onStartStudy;
  final VoidCallback onGrades;
  final VoidCallback onReview;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget action({
      required String label,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FilledButton.tonal(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: color.withValues(alpha: 0.22),
              foregroundColor: scheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).translate('quick_actions'),
          style: GoogleFonts.tajawal(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            action(
              label: AppLocalizations.of(context).translate('start_study'),
              icon: Icons.play_circle_filled_rounded,
              color: const Color(0xFF00897B),
              onTap: onStartStudy,
            ),
            action(
              label: AppLocalizations.of(context).translate('grades'),
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF5E35B1),
              onTap: onGrades,
            ),
            action(
              label: AppLocalizations.of(context).translate('review'),
              icon: Icons.auto_stories_rounded,
              color: const Color(0xFFE65100),
              onTap: onReview,
            ),
            action(
              label: AppLocalizations.of(context).translate('ai_assistant'),
              icon: Icons.auto_awesome_rounded,
              color: scheme.primary,
              onTap: onChat,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// تمت إزالة الكلاسات الخاصة بقسم مهام اليوم ونقلها بالكامل إلى plan_screen.dart.

