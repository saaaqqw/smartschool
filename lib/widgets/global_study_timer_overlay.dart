import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/stores/study_timer_store.dart';

/// ──────────────────────────────────────────────────────────────
/// العداد العائم العالمي المطور ومؤقت الدراسة (Draggable Global Overlay Pill)
/// يغلف كافة شاشات التطبيق ويتيح للطالب تحريك المؤقت وإخفائه وضبطه
/// ──────────────────────────────────────────────────────────────
class GlobalStudyTimerOverlay extends StatefulWidget {
  const GlobalStudyTimerOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<GlobalStudyTimerOverlay> createState() => _GlobalStudyTimerOverlayState();
}

class _GlobalStudyTimerOverlayState extends State<GlobalStudyTimerOverlay> {
  // إحداثيات مبدئية لكبسولة العداد في يسار أو يمين الشاشة
  double _left = 16.0;
  double _top = 100.0;
  bool _initializedPosition = false;

  // حالة السحب وتداخل العداد مع منطقة الإخفاء بالسفل
  bool _isDragging = false;
  bool _isOverDismissZone = false;

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    if (totalSeconds < 60) {
      // أقل من دقيقة: عرض الثواني فقط بصيغة مدمجة صغيرة
      return '$totalSecondsث';
    } else if (totalSeconds < 3600) {
      // من دقيقة إلى 59 دقيقة: عرض الدقائق والثواني
      final m = d.inMinutes.toString().padLeft(2, '0');
      final s = (totalSeconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    } else {
      // ساعة فأكثر: عرض الساعات والدقائق حتى يبقى العداد صغيراً
      final h = d.inHours;
      final m = (d.inMinutes % 60).toString().padLeft(2, '0');
      return '$h:$mس';
    }
  }

  String _formatTarget(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$hس';
    return '$hس و$mد';
  }

  void _showTimerControlsModal(BuildContext context, StudyTimerState state) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.timer_rounded, color: scheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدارة مؤقت الدراسة العائم',
                            style: GoogleFonts.tajawal(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            'الحد الأدنى للهدف هو ساعتان (120 دقيقة)',
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
                const SizedBox(height: 24),
                // خيارات اختيار الهدف (2، 3، 4، 6 ساعات)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'اختر الهدف الدراسي التراكمي:',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [120, 180, 240, 360].map((mins) {
                    final isSelected = state.targetMinutes == mins;
                    return ChoiceChip(
                      label: Text(
                        _formatTarget(mins),
                        style: GoogleFonts.tajawal(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? scheme.onPrimary : scheme.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: scheme.primary,
                      backgroundColor: scheme.surfaceContainerHighest,
                      onSelected: (_) {
                        studyTimerStore.setTarget(mins);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          studyTimerStore.reset();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: Text('إعادة تعيين للصفر', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          studyTimerStore.hideOverlay();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.visibility_off_rounded, size: 20),
                        label: Text('إخفاء العداد', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.secondary,
                          foregroundColor: scheme.onSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    if (!_initializedPosition && screenSize.width > 0) {
      // ضبط الإحداثيات المبدئية عند أسفل اليمين (أو أعلى اليسار) برفق
      _left = 20.0;
      _top = screenSize.height - 180.0;
      _initializedPosition = true;
    }

    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<StudyTimerState>(
          valueListenable: studyTimerStore,
          builder: (context, state, _) {
            if (state.isOverlayHidden) {
              return const SizedBox.shrink();
            }

            final scheme = Theme.of(context).colorScheme;
            final elapsedText = _formatDuration(state.elapsed);

            return Stack(
              children: [
                // ── منطقة الإخفاء بالسفل (تظهر فقط عند سحب العداد) ─────────
                if (_isDragging)
                  Positioned(
                    bottom: 44,
                    left: 20,
                    right: 20,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: _isOverDismissZone
                            ? Colors.red.shade600
                            : scheme.surfaceContainerHighest.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isOverDismissZone
                              ? Colors.white
                              : scheme.outline.withValues(alpha: 0.4),
                          width: _isOverDismissZone ? 2.2 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isOverDismissZone
                                ? Colors.red.withValues(alpha: 0.45)
                                : Colors.black.withValues(alpha: 0.16),
                            blurRadius: _isOverDismissZone ? 20 : 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isOverDismissZone
                                ? Icons.delete_forever_rounded
                                : Icons.delete_outline_rounded,
                            color: _isOverDismissZone ? Colors.white : scheme.onSurface,
                            size: _isOverDismissZone ? 26 : 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isOverDismissZone
                                ? 'إفلات الآن لإخفاء العداد'
                                : 'اسحب إلى هنا لإخفاء العداد',
                            style: GoogleFonts.tajawal(
                              fontSize: _isOverDismissZone ? 16 : 14.5,
                              fontWeight: _isOverDismissZone ? FontWeight.w900 : FontWeight.w700,
                              color: _isOverDismissZone ? Colors.white : scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── كبسولة العداد العائم القابلة للسحب ─────────────────────
                Positioned(
                  left: _left,
                  top: _top,
                  child: GestureDetector(
                    onPanStart: (_) {
                      setState(() {
                        _isDragging = true;
                        _isOverDismissZone = false;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _left = (_left + details.delta.dx)
                            .clamp(8.0, screenSize.width - 150.0);
                        _top = (_top + details.delta.dy)
                            .clamp(36.0, screenSize.height - 90.0);

                        // التحقق من تداخل العداد مع منطقة الإخفاء بالسفل
                        final distanceFromBottom = screenSize.height - _top;
                        _isOverDismissZone = (distanceFromBottom < 135.0) &&
                            (_left > 10 && _left < screenSize.width - 10);
                      });
                    },
                    onPanEnd: (_) {
                      if (_isOverDismissZone) {
                        studyTimerStore.hideOverlay();
                      }
                      setState(() {
                        _isDragging = false;
                        _isOverDismissZone = false;
                      });
                    },
                    onPanCancel: () {
                      setState(() {
                        _isDragging = false;
                        _isOverDismissZone = false;
                      });
                    },
                    onTap: () => _showTimerControlsModal(context, state),
                    child: Material(
                      color: Colors.transparent,
                      elevation: _isOverDismissZone ? 12 : 6,
                      shadowColor: _isOverDismissZone
                          ? Colors.red.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isOverDismissZone
                                  ? Colors.red.shade600
                                  : (state.isRunning
                                      ? scheme.primaryContainer.withValues(alpha: 0.95)
                                      : scheme.surfaceContainerHigh.withValues(alpha: 0.95)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isOverDismissZone
                                    ? Colors.white
                                    : (state.isRunning
                                        ? scheme.primary.withValues(alpha: 0.45)
                                        : scheme.outline.withValues(alpha: 0.2)),
                                width: _isOverDismissZone ? 1.8 : 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // أيقونة الدائرة (نسق مؤقت الخطة الدراسية)
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _isOverDismissZone
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : (state.isRunning
                                            ? scheme.primary
                                            : scheme.primary.withValues(alpha: 0.15)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.timer_rounded,
                                    size: 15,
                                    color: _isOverDismissZone
                                        ? Colors.white
                                        : (state.isRunning ? scheme.onPrimary : scheme.primary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // الوقت المنقضي بخط واضح وحجم مدمج
                                Text(
                                  elapsedText,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _isOverDismissZone ? Colors.white : scheme.onSurface,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // زر التشغيل / الإيقاف المؤقت (مدمج)
                                GestureDetector(
                                  onTap: () => studyTimerStore.toggle(),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: _isOverDismissZone
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : (state.isRunning
                                              ? scheme.tertiaryContainer
                                              : scheme.primary.withValues(alpha: 0.15)),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      state.isRunning
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 15,
                                      color: _isOverDismissZone
                                          ? Colors.white
                                          : (state.isRunning ? scheme.onTertiaryContainer : scheme.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                // زر الإخفاء السريع (مدمج)
                                GestureDetector(
                                  onTap: () => studyTimerStore.hideOverlay(),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _isOverDismissZone
                                          ? Colors.white.withValues(alpha: 0.3)
                                          : scheme.errorContainer.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 13,
                                      color: _isOverDismissZone ? Colors.white : scheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
