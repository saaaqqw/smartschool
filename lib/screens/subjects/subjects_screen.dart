import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/stores/user_profile_store.dart';
import '../../data/subject_curriculum.dart';
import '../../services/firebase_sync_service.dart';
import 'subject_units_screen.dart';
import '../chat/chat_screen.dart';

/// المواد الدراسية — شبكة من 6 مواد؛ الضغط يفتح شاشة الوحدات الست.
class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const SubjectsScreen(),
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: scheme.surfaceContainerLowest,
            title: Text(
              'المواد الدراسية',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: scheme.onSurface,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: ValueListenableBuilder<UserProfile>(
              valueListenable: userProfileNotifier,
              builder: (context, profile, _) {
                final currentSemester = profile.semester;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        _SemesterTabButton(
                          title: 'الفصل الدراسي الأول',
                          isSelected: currentSemester == 'الفصل الدراسي الأول',
                          onTap: () => updateSelectedSemester('الفصل الدراسي الأول'),
                        ),
                        _SemesterTabButton(
                          title: 'الفصل الدراسي الثاني',
                          isSelected: currentSemester == 'الفصل الدراسي الثاني',
                          onTap: () => updateSelectedSemester('الفصل الدراسي الثاني'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.86,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final subject = kCoreSubjects[index];
                  return _SubjectCard(
                    subject: subject,
                    onTap: () {
                      Navigator.of(context).push(
                        SubjectUnitsScreen.route(subject),
                      );
                    },
                  );
                },
                childCount: kCoreSubjects.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(ChatScreen.route()),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: const Icon(Icons.auto_awesome_rounded),
      ),
    );
  }
}

class _SubjectCard extends StatefulWidget {
  const _SubjectCard({
    required this.subject,
    required this.onTap,
  });

  final SchoolSubject subject;
  final VoidCallback onTap;

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _pressed = false;

  void _openUnits() {
    Navigator.of(context).push(SubjectUnitsScreen.route(widget.subject));
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final scheme = Theme.of(context).colorScheme;
    final uid = userProfileNotifier.value.uid;
    final semester = userProfileNotifier.value.semester;
    final progressDocId = FirebaseSyncService.getProgressDocId(subject.title, semester: semester);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openUnits,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Card(
            elevation: _pressed ? 0 : 2,
            shadowColor: subject.color.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    subject.color.withValues(alpha: 0.24),
                    subject.color.withValues(alpha: 0.07),
                  ],
                ),
              ),
              child: StreamBuilder<DocumentSnapshot>(
                stream: uid.isEmpty
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('progress')
                        .doc(progressDocId)
                        .snapshots(),
                builder: (context, snapshot) {
                  double progress = 0.0;
                  int completedLessons = 0;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null) {
                      completedLessons = (data['totalLessonsCompleted'] as num?)?.toInt() ?? 0;
                      final unitProgressMap = data['unitProgress'] as Map<String, dynamic>? ?? {};
                      if (unitProgressMap.isNotEmpty) {
                        double total = 0;
                        for (final v in unitProgressMap.values) {
                          total += (v as num).toDouble();
                        }
                        progress = (total / 6).clamp(0.0, 1.0);
                      }
                    }
                  }

                  final pct = (progress * 100).toInt();

                  return Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'subject_icon_${subject.title}',
                          child: Material(
                            color: subject.color.withValues(alpha: 0.25),
                            shape: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Icon(
                                subject.icon,
                                size: 36,
                                color: subject.color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          subject.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // ── شريط التقدم الحقيقي ──────────────────────
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: subject.color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(subject.color),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$completedLessons درس مكتمل',
                              style: GoogleFonts.tajawal(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: GoogleFonts.tajawal(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: pct > 0 ? subject.color : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SemesterTabButton extends StatelessWidget {
  const _SemesterTabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.tajawal(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13.5,
              color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
