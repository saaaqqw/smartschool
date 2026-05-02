import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../user_profile_store.dart';
import '../data/subject_curriculum.dart';
import 'unit_detail_screen.dart';

class SubjectUnitsScreen extends StatefulWidget {
  const SubjectUnitsScreen({
    super.key,
    required this.subject,
  });

  final SchoolSubject subject;

  static Route<void> route(SchoolSubject subject) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          SubjectUnitsScreen(subject: subject),
      // ... (transitions stay the same)
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  State<SubjectUnitsScreen> createState() => _SubjectUnitsScreenState();
}

class _SubjectUnitsScreenState extends State<SubjectUnitsScreen> {
  final _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = userProfileNotifier.value.uid;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: StreamBuilder<DocumentSnapshot>(
        stream: uid.isEmpty
            ? Stream.empty()
            : _firebaseService.getProgressStream(uid, widget.subject.title),
        builder: (context, snapshot) {
          Map<String, dynamic> progressData = {};
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            progressData = data?['unitProgress'] as Map<String, dynamic>? ?? {};
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                pinned: true,
                backgroundColor: widget.subject.color.withValues(alpha: 0.12),
                surfaceTintColor: widget.subject.color.withValues(alpha: 0.3),
                leading: IconButton(
                  icon: Icon(Icons.arrow_forward_rounded, color: scheme.onSurface),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(
                  widget.subject.title,
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: scheme.onSurface,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Align(
                    alignment: const Alignment(-0.85, 0.25),
                    child: Hero(
                      tag: 'subject_icon_${widget.subject.title}',
                      child: Material(
                        color: widget.subject.color.withValues(alpha: 0.22),
                        shape: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            widget.subject.icon,
                            size: 36,
                            color: widget.subject.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: widget.subject.units.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final unit = widget.subject.units[index];
                    // Use Firestore progress if available, otherwise fallback to local/demo
                    final firestoreProgress = progressData[unit.title] as double?;
                    final currentProgress = firestoreProgress ?? unit.progress;

                    return _UnitCard(
                      subject: widget.subject,
                      unit: unit,
                      index: index,
                      actualProgress: currentProgress,
                      onTap: () {
                        Navigator.of(context).push(
                          UnitDetailScreen.route(
                            subject: widget.subject,
                            unit: unit,
                            unitIndex: index,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.subject,
    required this.unit,
    required this.index,
    required this.actualProgress,
    required this.onTap,
  });

  final SchoolSubject subject;
  final CurriculumUnit unit;
  final int index;
  final double actualProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (actualProgress * 100).round();

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      surfaceTintColor: subject.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: subject.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  unit.icon,
                  color: subject.color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الوحدة ${index + 1}',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subject.color,
                      ),
                    ),
                    Text(
                      unit.title,
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: actualProgress.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor:
                                  subject.color.withValues(alpha: 0.15),
                              color: subject.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$pct٪',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'التقدم في هذه الوحدة',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
