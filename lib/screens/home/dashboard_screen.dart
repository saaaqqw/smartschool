import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/stores/user_profile_store.dart';
import '../grades/grades_screen.dart';
import '../settings/settings_screen.dart';
import '../study/study_plan_screen.dart';
import '../subjects/subjects_screen.dart';
import '../chat/chat_screen.dart';

import '../../data/subject_curriculum.dart';
import '../../core/l10n/app_localizations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onNavigateToPage});

  final ValueChanged<int>? onNavigateToPage;

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const DashboardScreen());
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
                  for (var doc in snapshot.data!.docs) {
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
    // RTL: first child in Row aligns to the visual right.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: scheme.primaryContainer,
          backgroundImage: profile.profileImageUrl.isNotEmpty
              ? CachedNetworkImageProvider(profile.profileImageUrl)
              : null,
          child: profile.profileImageUrl.isEmpty
              ? Icon(
                  Icons.person_rounded,
                  size: 36,
                  color: scheme.onPrimaryContainer,
                )
              : null,
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
        IconButton.filledTonal(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
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
