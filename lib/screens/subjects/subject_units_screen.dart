import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firebase_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../core/stores/user_profile_store.dart';
import '../../data/subject_curriculum.dart';
import 'unit_detail_screen.dart';
import '../chat/chat_screen.dart';

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

  void _openChat() {
    Navigator.of(context).push(
      ChatScreen.route(subjectTitle: widget.subject.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = userProfileNotifier.value.uid;
    final grade = userProfileNotifier.value.grade;
    final semester = userProfileNotifier.value.semester;
    final cleanGrade = grade.isEmpty ? 'الصف السابع' : grade;
    final subjectDocId = FirebaseSyncService.getSubjectDocId(
      widget.subject.title,
      cleanGrade,
      semester: semester,
    );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: StreamBuilder<DocumentSnapshot>(
        stream: uid.isEmpty
            ? const Stream.empty()
            : _firebaseService.getProgressStream(uid, widget.subject.title, semester: semester),
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
                  icon: Icon(Icons.arrow_forward_rounded,
                      color: scheme.onSurface),
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
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('subjects')
                    .doc(subjectDocId)
                    .snapshots(),
                builder: (context, subjSnap) {
                  List<CurriculumUnit> displayUnits = widget.subject.units;
                  String bookUrl = '';
                  String bookTitle = '';

                  if (subjSnap.hasData &&
                      subjSnap.data != null &&
                      subjSnap.data!.exists) {
                    final data =
                        subjSnap.data!.data() as Map<String, dynamic>?;
                    if (data != null) {
                      bookUrl = data['bookUrl'] as String? ?? '';
                      bookTitle = data['bookTitle'] as String? ?? '';

                      if (data['units'] is List) {
                        final unitsRaw = data['units'] as List;
                        if (unitsRaw.isNotEmpty) {
                          displayUnits = unitsRaw.asMap().entries.map((e) {
                            final map = e.value as Map? ?? {};
                            final title = map['title'] as String? ??
                                'الوحدة ${e.key + 1}';
                            return CurriculumUnit(
                              title: title,
                              icon: widget.subject.icon,
                              progress: 0.0,
                            );
                          }).toList();
                        }
                      }
                    }
                  }

                  return SliverMainAxisGroup(
                    slivers: [
                      if (bookUrl.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: _BookHeroCard(
                              subject: widget.subject,
                              semester: semester,
                              bookTitle: bookTitle,
                              bookUrl: bookUrl,
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        sliver: SliverList.separated(
                          itemCount: displayUnits.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final unit = displayUnits[index];
                            final firestoreProgress =
                                progressData[unit.title] as double?;
                            final currentProgress =
                                firestoreProgress ?? unit.progress;

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
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openChat,
        backgroundColor: widget.subject.color,
        foregroundColor: Colors.white,
        child: const Icon(Icons.auto_awesome_rounded),
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

class _BookHeroCard extends StatelessWidget {
  const _BookHeroCard({
    required this.subject,
    required this.semester,
    required this.bookTitle,
    required this.bookUrl,
  });

  final SchoolSubject subject;
  final String semester;
  final String bookTitle;
  final String bookUrl;

  String _convertDriveToDownloadUrl(String url) {
    final fileIdRegExp = RegExp(r'/file/d/([a-zA-Z0-9_-]+)');
    final idRegExp = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');

    String? fileId;
    final fileMatch = fileIdRegExp.firstMatch(url);
    if (fileMatch != null && fileMatch.groupCount >= 1) {
      fileId = fileMatch.group(1);
    } else {
      final idMatch = idRegExp.firstMatch(url);
      if (idMatch != null && idMatch.groupCount >= 1) {
        fileId = idMatch.group(1);
      }
    }

    if (fileId != null && fileId.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }
    return url;
  }

  Future<void> _viewBook(BuildContext context) async {
    final uri = Uri.parse(bookUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح رابط تصفح الكتاب.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء فتح الرابط: $e')),
        );
      }
    }
  }

  Future<void> _downloadBook(BuildContext context) async {
    final downloadUrl = _convertDriveToDownloadUrl(bookUrl);
    final uri = Uri.parse(downloadUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر بدء تحميل الكتاب.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء محاولة التحميل: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            subject.color.withValues(alpha: 0.16),
            subject.color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: subject.color.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: subject.color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: subject.color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: subject.color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookTitle.isNotEmpty
                          ? bookTitle
                          : 'الكتاب الدراسي المعتمد — $semester',
                      style: GoogleFonts.tajawal(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'متاح للقراءة السحابية المباشرة أو التحميل للمشاهدة بدون إنترنت عبر Google Drive',
                      style: GoogleFonts.tajawal(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _viewBook(context),
                  icon: const Icon(Icons.visibility_rounded, size: 20),
                  label: Text(
                    'تصفح الكتاب',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: subject.color,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _downloadBook(context),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    'تحميل (PDF)',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: subject.color,
                    side: BorderSide(color: subject.color, width: 1.8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
