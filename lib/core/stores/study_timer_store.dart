import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// ──────────────────────────────────────────────────────────────
/// حالة المؤقت العالمي
/// ──────────────────────────────────────────────────────────────
class StudyTimerState {
  const StudyTimerState({
    this.elapsed = Duration.zero,
    this.targetMinutes = 120,
    this.isRunning = false,
    this.isOverlayHidden = true,
  });

  final Duration elapsed;
  final int targetMinutes;
  final bool isRunning;
  final bool isOverlayHidden;

  bool get isDone =>
      targetMinutes > 0 && elapsed.inMinutes >= targetMinutes;

  double get progress {
    final targetSec = targetMinutes * 60;
    if (targetSec <= 0) return 0.0;
    return (elapsed.inSeconds / targetSec).clamp(0.0, 1.0);
  }

  StudyTimerState copyWith({
    Duration? elapsed,
    int? targetMinutes,
    bool? isRunning,
    bool? isOverlayHidden,
  }) {
    return StudyTimerState(
      elapsed: elapsed ?? this.elapsed,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      isRunning: isRunning ?? this.isRunning,
      isOverlayHidden: isOverlayHidden ?? this.isOverlayHidden,
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// مخزن المؤقت العالمي — يمكن الاستماع له من أي شاشة
/// مع دعم المزامنة مع Firestore (حفظ/استعادة)
/// ──────────────────────────────────────────────────────────────
class StudyTimerStore extends ValueNotifier<StudyTimerState> {
  StudyTimerStore() : super(const StudyTimerState());

  Timer? _timer;

  // دالة callback اختيارية لحفظ الحالة في Firestore
  // تُعيَّن من خارج الكلاس عند بدء الجلسة
  void Function(Duration elapsed, int targetMinutes, bool isRunning)?
      onStateChanged;

  /// تعيين المدة المستهدفة (بالدقائق) بحيث لا تقل أبداً عن 2 ساعات (120 دقيقة)
  void setTarget(int minutes) {
    final clamped = math.max(120, minutes);
    value = value.copyWith(targetMinutes: clamped);
    _notifyChange();
  }

  /// إظهار العداد العائم على الشاشة
  void showOverlay() {
    value = value.copyWith(isOverlayHidden: false);
    _notifyChange();
  }

  /// إخفاء العداد العائم من الشاشة
  void hideOverlay() {
    value = value.copyWith(isOverlayHidden: true);
    _notifyChange();
  }

  /// استعادة الوقت المنقضي من Firestore (تُستدعى عند فتح التطبيق)
  void restoreElapsed(Duration elapsed) {
    value = value.copyWith(elapsed: elapsed);
  }

  /// بدء المؤقت (يكمل من نقطة التوقف الأخيرة أو يبدأ ويعرض العداد العائم)
  void start() {
    if (value.isRunning) {
      if (value.isOverlayHidden) {
        showOverlay();
      }
      return;
    }
    value = value.copyWith(isRunning: true, isOverlayHidden: false);
    _notifyChange();
    _tick();
  }

  /// إيقاف المؤقت مؤقتاً
  void stop() {
    _timer?.cancel();
    _timer = null;
    value = value.copyWith(isRunning: false);
    _notifyChange();
  }

  /// تبديل بين التشغيل والإيقاف
  void toggle() {
    if (value.isRunning) {
      stop();
    } else {
      start();
    }
  }

  /// إعادة تعيين المؤقت بالكامل
  void reset() {
    stop();
    value = value.copyWith(elapsed: Duration.zero);
    _notifyChange();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final newElapsed = value.elapsed + const Duration(seconds: 1);
      value = value.copyWith(elapsed: newElapsed);

      // حفظ الحالة كل 30 ثانية تلقائياً
      if (newElapsed.inSeconds % 30 == 0) {
        _notifyChange();
      }

      // إيقاف تلقائي عند الوصول للهدف
      if (value.isDone) {
        _timer?.cancel();
        _timer = null;
        value = value.copyWith(isRunning: false);
        _notifyChange();
      }
    });
  }

  void _notifyChange() {
    onStateChanged?.call(value.elapsed, value.targetMinutes, value.isRunning);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// النسخة العالمية الوحيدة من مخزن المؤقت
final StudyTimerStore studyTimerStore = StudyTimerStore();
