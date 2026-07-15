import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/weekly_schedule_service.dart';
import '../../core/stores/user_profile_store.dart';
import '../../data/subject_curriculum.dart';

const double _kCardRadius = 20;

/// واجهة الخطة الدراسية (StudyPlanScreen)
/// شاشة مستقلة تُمكن الطالب من إدارة:
/// 1. الجدول الدراسي الأسبوعي (تحديد المواد لكل يوم)
/// 2. الدراسة اليومية (وقت البدء ومدة الدراسة المطلوبة)
class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const StudyPlanScreen(),
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
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  final _scheduleService = WeeklyScheduleService();
  WeeklySchedule _weeklySchedule = WeeklySchedule.empty();
  bool _scheduleLoading = true;

  // المواد المتاحة للاختيار متزامنة مع قائمة مناهج وتسميات قاعدة البيانات
  List<String> get _availableSubjects =>
      kCoreSubjects.map((s) => s.title).toList();

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) {
      setState(() => _scheduleLoading = false);
      return;
    }
    try {
      final ws = await _scheduleService.fetchSchedule(uid);
      setState(() {
        _weeklySchedule = ws;
        _scheduleLoading = false;
      });
    } catch (_) {
      setState(() => _scheduleLoading = false);
    }
  }

  Future<void> _saveSchedule() async {
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return;
    await _scheduleService.saveSchedule(uid, _weeklySchedule);
    if (mounted) _toast(context, 'تم حفظ التعديلات بنجاح ✓');
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _weeklySchedule.startHour,
        minute: _weeklySchedule.startMinute,
      ),
      helpText: 'وقت بدء الدراسة',
      builder: (ctx, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _weeklySchedule = _weeklySchedule.copyWith(
          startHour: picked.hour,
          startMinute: picked.minute,
        );
      });
    }
  }

  Future<void> _pickDuration() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(context).colorScheme;
        final options = [
          (30, '٣٠ دقيقة'),
          (45, '٤٥ دقيقة'),
          (60, 'ساعة واحدة'),
          (90, 'ساعة ونصف'),
          (120, 'ساعتان'),
          (150, 'ساعتان ونصف'),
          (180, 'ثلاث ساعات'),
          (240, 'أربع ساعات'),
        ];
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'مدة الدراسة اليومية',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                ...options.map((opt) {
                  final isSelected = _weeklySchedule.durationMinutes == opt.$1;
                  return ListTile(
                    title: Text(
                      opt.$2,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isSelected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_rounded, color: scheme.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _weeklySchedule = _weeklySchedule.copyWith(
                          durationMinutes: opt.$1,
                        );
                      });
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDaySubjectsSheet(String day) async {
    final scheme = Theme.of(context).colorScheme;
    final selected = List<String>.from(_weeklySchedule.schedule[day] ?? []);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'مواد يوم $day',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollCtrl,
                          children: _availableSubjects.map((subj) {
                            final isChosen = selected.contains(subj);
                            return CheckboxListTile(
                              value: isChosen,
                              onChanged: (v) {
                                setSheetState(() {
                                  if (v == true) {
                                    selected.add(subj);
                                  } else {
                                    selected.remove(subj);
                                  }
                                });
                              },
                              title: Text(
                                subj,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isChosen
                                      ? scheme.primary
                                      : scheme.onSurface,
                                ),
                              ),
                              activeColor: scheme.primary,
                              checkColor: scheme.onPrimary,
                              controlAffinity: ListTileControlAffinity.leading,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            final newSchedule = Map<String, List<String>>.from(
                              _weeklySchedule.schedule,
                            );
                            newSchedule[day] = selected;
                            _weeklySchedule = _weeklySchedule.copyWith(
                              schedule: newSchedule,
                            );
                          });
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'حفظ مواد اليوم',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.tajawal()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes دقيقة';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) {
      if (h == 1) return 'ساعة واحدة';
      if (h == 2) return 'ساعتان';
      return '$h ساعات';
    }
    final hStr = h == 1 ? 'ساعة' : (h == 2 ? 'ساعتان' : '$h ساعات');
    return '$hStr و$m دقيقة';
  }

  Widget _buildCategoryLabel(String text, ColorScheme scheme) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          style: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }

  static Widget _divider(ColorScheme scheme) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 56,
      color: scheme.outlineVariant.withValues(alpha: 0.45),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_scheduleLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'الخطة الدراسية',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final startTime = TimeOfDay(
      hour: _weeklySchedule.startHour,
      minute: _weeklySchedule.startMinute,
    );
    final durMins = _weeklySchedule.durationMinutes;
    final durLabel = _formatDuration(durMins);
    final timeLabel = startTime.format(context);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: scheme.surfaceContainerLowest,
        title: Text(
          'الخطة الدراسية',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── قسم الجدول الدراسي الأسبوعي ──
          _buildCategoryLabel('الجدول الدراسي الأسبوعي', scheme),
          const SizedBox(height: 10),
          _PlanSettingsCard(
            scheme: scheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...WeeklySchedule.dayKeys.asMap().entries.map((entry) {
                  final day = entry.value;
                  final subjects = _weeklySchedule.schedule[day] ?? [];
                  final isLast = entry.key == WeeklySchedule.dayKeys.length - 1;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            color: scheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          day,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        subtitle: subjects.isEmpty
                            ? Text(
                                'لم يتم تحديد مواد',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.tajawal(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            : Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 4,
                                runSpacing: 2,
                                children: subjects
                                    .map(
                                      (s) => Chip(
                                        label: Text(
                                          s,
                                          style: GoogleFonts.tajawal(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        backgroundColor:
                                            scheme.secondaryContainer,
                                        labelStyle: TextStyle(
                                            color: scheme.onSecondaryContainer),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    )
                                    .toList(),
                              ),
                        trailing: Icon(
                          Icons.edit_rounded,
                          color: scheme.outline,
                          size: 22,
                        ),
                        onTap: () => _showDaySubjectsSheet(day),
                      ),
                      if (!isLast) _divider(scheme),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── قسم إعدادات وقت الدراسة اليومية ──
          _buildCategoryLabel('الدراسة اليومية', scheme),
          const SizedBox(height: 10),
          _PlanSettingsCard(
            scheme: scheme,
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.alarm_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'وقت بدء الدراسة',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    timeLabel,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_left_rounded,
                    color: scheme.outline,
                    size: 28,
                  ),
                  onTap: _pickStartTime,
                ),
                _divider(scheme),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.timelapse_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'مدة الدراسة اليومية',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    durLabel,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_left_rounded,
                    color: scheme.outline,
                    size: 28,
                  ),
                  onTap: _pickDuration,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── زر حفظ الكل ──
          FilledButton.icon(
            onPressed: _saveSchedule,
            icon: const Icon(Icons.save_rounded, size: 20),
            label: Text(
              'حفظ التغييرات بالكامل',
              style: GoogleFonts.tajawal(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSettingsCard extends StatelessWidget {
  const _PlanSettingsCard({
    required this.scheme,
    required this.child,
  });

  final ColorScheme scheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: isDark ? 2 : 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      surfaceTintColor: scheme.surfaceTint.withValues(alpha: isDark ? 0.18 : 0.08),
      borderRadius: BorderRadius.circular(_kCardRadius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: child,
      ),
    );
  }
}
