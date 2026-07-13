import 'dart:async';
import 'package:flutter/foundation.dart';

/// ──────────────────────────────────────────────────────────────
/// حالة المؤقت العالمي
/// ──────────────────────────────────────────────────────────────
class StudyTimerState {
  const StudyTimerState({
    this.elapsed = Duration.zero,
    this.targetMinutes = 120,
    this.isRunning = false,
  });

  final Duration elapsed;
  final int targetMinutes;
  final bool isRunning;

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
  }) {
    return StudyTimerState(
      elapsed: elapsed ?? this.elapsed,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      isRunning: isRunning ?? this.isRunning,
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

  /// تعيين المدة المستهدفة (بالدقائق) دون إعادة تعيين المؤقت
  void setTarget(int minutes) {
    value = value.copyWith(targetMinutes: minutes);
    _notifyChange();
  }

  /// استعادة الوقت المنقضي من Firestore (تُستدعى عند فتح التطبيق)
  void restoreElapsed(Duration elapsed) {
    value = value.copyWith(elapsed: elapsed);
  }

  /// بدء المؤقت (يكمل من نقطة التوقف الأخيرة)
  void start() {
    if (value.isRunning) return;
    value = value.copyWith(isRunning: true);
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
