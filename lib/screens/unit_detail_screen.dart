import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../user_profile_store.dart';
import '../data/subject_curriculum.dart';
import 'chat_screen.dart';

class UnitDetailScreen extends StatefulWidget {
  const UnitDetailScreen({
    super.key,
    required this.subject,
    required this.unit,
    required this.unitIndex,
  });

  final SchoolSubject subject;
  final CurriculumUnit unit;
  final int unitIndex;

  static Route<void> route({
    required SchoolSubject subject,
    required CurriculumUnit unit,
    required int unitIndex,
  }) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          UnitDetailScreen(
        subject: subject,
        unit: unit,
        unitIndex: unitIndex,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 260),
    );
  }

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  final _firebaseService = FirebaseService();
  bool _isUpdating = false;

  Future<void> _markAsComplete() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;

    setState(() => _isUpdating = true);
    try {
      await _firebaseService.updateUnitProgress(
        uid,
        widget.subject.title,
        widget.unit.title,
        1.0,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إكمال الوحدة بنجاح!',
            style: GoogleFonts.tajawal(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء التحديث: $e',
            style: GoogleFonts.tajawal(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (widget.unit.progress * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.unit.title,
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 0,
            color: widget.subject.color.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: widget.subject.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.unit.icon,
                      color: widget.subject.color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.title,
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.subject.color,
                          ),
                        ),
                        Text(
                          'الوحدة ${widget.unitIndex + 1}',
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'نسبة الإنجاز',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: widget.unit.progress.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: widget.subject.color.withValues(alpha: 0.15),
              color: widget.subject.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$pct٪ مكتمل',
            style: GoogleFonts.tajawal(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _isUpdating ? null : _markAsComplete,
            icon: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              'تحديد كمكتمل',
              style: GoogleFonts.tajawal(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: widget.subject.color,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'سيتم عرض دروس هذا الفصل، والفيديوهات، والاختبارات القصيرة هنا بعد ربط المحتوى.',
            style: GoogleFonts.tajawal(
              fontSize: 15,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            ChatScreen.route(
              subjectTitle: '${widget.subject.title} - ${widget.unit.title}',
            ),
          );
        },
        backgroundColor: widget.subject.color,
        foregroundColor: Colors.white,
        child: const Icon(Icons.auto_awesome_rounded),
      ),
    );
  }
}
