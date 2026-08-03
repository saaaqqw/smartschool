import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'smart_notification_service.dart';
import 'notification_cache_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// خدمة إشعارات نتائج الاختبارات الذكية
///
/// تحفظ إشعاراً شخصياً في users/{uid}/notifications بعد كل اختبار.
/// المنطق: يقارن الدرجة الجديدة بالسابقة ويحدد النص واللون المناسبَين.
///
/// trend:
///   improved  → الدرجة ارتفعت
///   stable    → الدرجة لم تتغير
///   declined  → الدرجة نزلت (لا يُذكر "رقم قياسي" أبداً)
/// ═══════════════════════════════════════════════════════════════
class QuizNotificationService {
  static final _db = FirebaseFirestore.instance;

  // ─── ثوابت نطاقات الدرجات ────────────────────────────────────
  static const double _excellent = 0.90;
  static const double _good = 0.70;
  static const double _pass = 0.50;
  static const double _unitPass = 0.60;

  // ══════════════════════════════════════════════════════════════
  // إشعار اختبار الدرس
  // ══════════════════════════════════════════════════════════════

  /// يُرسل إشعار نتيجة اختبار الدرس ويحفظه في Firestore.
  /// [previousScore] = null إذا كانت أول محاولة.
  static Future<void> sendQuizResultNotification({
    required String uid,
    required double score,
    double? previousScore,
    required String subjectTitle,
    required String lessonTitle,
    String? semester,
    String? grade,
  }) async {
    if (uid.isEmpty) return;

    final trend = _calcTrend(score, previousScore);
    final content = _buildLessonContent(
      score: score,
      previousScore: previousScore,
      trend: trend,
      subjectTitle: subjectTitle,
      lessonTitle: lessonTitle,
    );

    await _saveNotification(
      uid: uid,
      type: 'quiz_result',
      title: content.title,
      body: content.body,
      score: score,
      previousScore: previousScore,
      trend: trend,
      subjectTitle: subjectTitle,
      lessonOrUnitTitle: lessonTitle,
      iconName: content.iconName,
      colorHex: content.colorHex,
      semester: semester,
      grade: grade,
    );

    // إرسال إشعار محلي ذكي (AI + Fallback) عبر نظام التشغيل
    try {
      final studentName = await NotificationCacheService.getStudentName();
      final scorePercent = score * 100.0;
      if (score >= _good) {
        await SmartNotificationService.showHighPerformanceCongrats(studentName, subjectTitle, scorePercent);
      } else if (score < _pass) {
        await SmartNotificationService.showLowPerformanceAlert(studentName, subjectTitle, scorePercent);
      }
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // إشعار اختبار الوحدة
  // ══════════════════════════════════════════════════════════════

  /// يُرسل إشعار نتيجة اختبار الوحدة الشامل ويحفظه في Firestore.
  static Future<void> sendUnitExamResultNotification({
    required String uid,
    required double score,
    double? previousScore,
    required String subjectTitle,
    required String unitTitle,
    String? semester,
    String? grade,
  }) async {
    if (uid.isEmpty) return;

    final trend = _calcTrend(score, previousScore);
    final content = _buildUnitContent(
      score: score,
      previousScore: previousScore,
      trend: trend,
      subjectTitle: subjectTitle,
      unitTitle: unitTitle,
    );

    await _saveNotification(
      uid: uid,
      type: 'unit_exam_result',
      title: content.title,
      body: content.body,
      score: score,
      previousScore: previousScore,
      trend: trend,
      subjectTitle: subjectTitle,
      lessonOrUnitTitle: unitTitle,
      iconName: content.iconName,
      colorHex: content.colorHex,
      semester: semester,
      grade: grade,
    );

    // إرسال إشعار محلي ذكي (AI + Fallback) عبر نظام التشغيل
    try {
      final studentName = await NotificationCacheService.getStudentName();
      final scorePercent = score * 100.0;
      if (score >= _good) {
        await SmartNotificationService.showHighPerformanceCongrats(studentName, subjectTitle, scorePercent);
      } else if (score < _pass) {
        await SmartNotificationService.showLowPerformanceAlert(studentName, subjectTitle, scorePercent);
      }
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // بناء محتوى إشعار الدرس
  // ══════════════════════════════════════════════════════════════

  static _NotifContent _buildLessonContent({
    required double score,
    required double? previousScore,
    required _Trend trend,
    required String subjectTitle,
    required String lessonTitle,
  }) {
    final scorePct = _pct(score);
    final prevPct = previousScore != null ? _pct(previousScore) : null;

    switch (trend) {
      // ─── حالة التحسّن ──────────────────────────────────────
      case _Trend.improved:
        if (score >= _excellent) {
          return _NotifContent(
            title: '🌟 إنجاز رائع في $subjectTitle!',
            body: 'حصلت على $scorePct% في $lessonTitle — أنت من أفضل الطلاب! استمر على هذا المستوى 🚀',
            iconName: 'star',
            colorHex: '#FFB300',
          );
        } else if (score >= _good) {
          return _NotifContent(
            title: '🎯 أحسنت، تحسّنت!',
            body: prevPct != null
                ? 'ارتفعت من $prevPct% إلى $scorePct% في $lessonTitle، أداء ممتاز! واصل التقدم 💪'
                : 'حصلت على $scorePct% في $lessonTitle، أداء ممتاز! واصل التقدم 💪',
            iconName: 'target',
            colorHex: '#10B981',
          );
        } else {
          return _NotifContent(
            title: '💪 خطوة للأمام في $subjectTitle!',
            body: prevPct != null
                ? 'تحسّنت من $prevPct% إلى $scorePct% في $lessonTitle، على الطريق الصحيح!'
                : 'حصلت على $scorePct% في $lessonTitle، على الطريق الصحيح!',
            iconName: 'trending_up',
            colorHex: '#3949AB',
          );
        }

      // ─── حالة الثبات ──────────────────────────────────────
      case _Trend.stable:
        return _NotifContent(
          title: '📊 حافظت على مستواك',
          body: 'حصلت على $scorePct% مرة أخرى في $lessonTitle — حاول تتجاوز هذا الحد في المرة القادمة!',
          iconName: 'bar_chart',
          colorHex: '#6D4C41',
        );

      // ─── حالة التراجع ─────────────────────────────────────
      case _Trend.declined:
        return _NotifContent(
          title: '🔄 لا بأس، حاول مجدداً!',
          body: 'حصلت على $scorePct% في $lessonTitle. أحياناً نتراجع لنعود أقوى — راجع الدرس وحاول مرة أخرى 🌈',
          iconName: 'refresh',
          colorHex: '#E91E63',
        );

      // ─── أول محاولة ────────────────────────────────────────
      case _Trend.firstAttempt:
        if (score >= _excellent) {
          return _NotifContent(
            title: '🌟 بداية رائعة في $subjectTitle!',
            body: 'حصلت على $scorePct% في أول محاولة في $lessonTitle — أداء مميز جداً! 🎉',
            iconName: 'star',
            colorHex: '#FFB300',
          );
        } else if (score >= _pass) {
          return _NotifContent(
            title: '✅ اجتزت اختبار $lessonTitle!',
            body: 'حصلت على $scorePct%، نجاح يستحق التقدير. واصل تحسين درجاتك 💪',
            iconName: 'check_circle',
            colorHex: '#10B981',
          );
        } else {
          return _NotifContent(
            title: '🔄 البداية صعبة دائماً!',
            body: 'حصلت على $scorePct% في $lessonTitle — لا تيأس، راجع الدرس وحاول مجدداً 🌈',
            iconName: 'refresh',
            colorHex: '#E91E63',
          );
        }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // بناء محتوى إشعار الوحدة
  // ══════════════════════════════════════════════════════════════

  static _NotifContent _buildUnitContent({
    required double score,
    required double? previousScore,
    required _Trend trend,
    required String subjectTitle,
    required String unitTitle,
  }) {
    final scorePct = _pct(score);
    final prevPct = previousScore != null ? _pct(previousScore) : null;
    final passed = score >= _unitPass;

    switch (trend) {
      // ─── حالة التحسّن ──────────────────────────────────────
      case _Trend.improved:
        if (score >= _excellent) {
          return _NotifContent(
            title: '🏆 بطل وحدة $unitTitle!',
            body: 'أتممت وحدة $unitTitle في $subjectTitle بدرجة $scorePct% — إنجاز يستحق الاحتفال! 🎉',
            iconName: 'trophy',
            colorHex: '#FFB300',
          );
        } else if (passed) {
          return _NotifContent(
            title: '🎯 تجاوزت نفسك!',
            body: prevPct != null
                ? 'تحسّنت من $prevPct% إلى $scorePct% في وحدة $unitTitle — أحسنت! 🌟'
                : 'اجتزت وحدة $unitTitle بـ$scorePct% — أحسنت! 🌟',
            iconName: 'target',
            colorHex: '#10B981',
          );
        } else {
          return _NotifContent(
            title: '💪 تحسّن ملحوظ!',
            body: prevPct != null
                ? 'ارتفعت من $prevPct% إلى $scorePct% في وحدة $unitTitle، استمر وستجتاز الحد قريباً!'
                : 'حصلت على $scorePct% في وحدة $unitTitle، استمر وستجتاز الحد قريباً!',
            iconName: 'trending_up',
            colorHex: '#3949AB',
          );
        }

      // ─── حالة الثبات ──────────────────────────────────────
      case _Trend.stable:
        return _NotifContent(
          title: '📊 مستواك ثابت في وحدة $unitTitle',
          body: passed
              ? 'حصلت على $scorePct% مجدداً، اجتزت الوحدة! لكن بإمكانك تحقيق أكثر 🎯'
              : 'حصلت على $scorePct% مجدداً في وحدة $unitTitle. غيّر أسلوب مراجعتك وحاول مجدداً!',
          iconName: 'bar_chart',
          colorHex: '#6D4C41',
        );

      // ─── حالة التراجع ─────────────────────────────────────
      case _Trend.declined:
        return _NotifContent(
          title: '💪 لا تستسلم!',
          body: passed
              ? 'اجتزت وحدة $unitTitle بـ$scorePct% رغم الضغط — أنت مثابر، واصل المحاولة!'
              : 'حصلت على $scorePct% في وحدة $unitTitle. راجع الدروس بتركيز وستعود أقوى 🌟',
          iconName: 'refresh',
          colorHex: '#E91E63',
        );

      // ─── أول محاولة ────────────────────────────────────────
      case _Trend.firstAttempt:
        if (score >= _excellent) {
          return _NotifContent(
            title: '🏆 أداء استثنائي!',
            body: 'اجتزت وحدة $unitTitle بدرجة $scorePct% من أول محاولة — أنت نجم حقيقي! 🌟',
            iconName: 'trophy',
            colorHex: '#FFB300',
          );
        } else if (passed) {
          return _NotifContent(
            title: '✅ اجتزت وحدة $unitTitle!',
            body: 'حصلت على $scorePct%، نجاح في اختبار الوحدة يستحق التقدير. واصل التحسين 💪',
            iconName: 'check_circle',
            colorHex: '#10B981',
          );
        } else {
          return _NotifContent(
            title: '🔄 المحاولة الأولى من كثير!',
            body: 'حصلت على $scorePct% في وحدة $unitTitle. راجع جميع الدروس وحاول مجدداً — أنت أقوى مما تظن! 💪',
            iconName: 'refresh',
            colorHex: '#E91E63',
          );
        }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // حفظ الإشعار في Firestore
  // ══════════════════════════════════════════════════════════════

  static Future<void> _saveNotification({
    required String uid,
    required String type,
    required String title,
    required String body,
    required double score,
    required double? previousScore,
    required _Trend trend,
    required String subjectTitle,
    required String lessonOrUnitTitle,
    required String iconName,
    required String colorHex,
    String? semester,
    String? grade,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'type': type,
        'title': title,
        'body': body,
        'score': score,
        'previousScore': previousScore,
        'trend': trend.name,         // "improved" | "stable" | "declined" | "firstAttempt"
        'subjectTitle': subjectTitle,
        'lessonOrUnitTitle': lessonOrUnitTitle,
        if (semester != null) 'semester': semester,
        if (grade != null) 'grade': grade,
        'iconName': iconName,
        'colorHex': colorHex,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[QuizNotificationService] فشل حفظ الإشعار: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // مساعدات
  // ══════════════════════════════════════════════════════════════

  static int _pct(double v) => (v * 100).round();

  static _Trend _calcTrend(double newScore, double? prev) {
    if (prev == null) return _Trend.firstAttempt;
    final diff = newScore - prev;
    if (diff > 0.005) return _Trend.improved;
    if (diff < -0.005) return _Trend.declined;
    return _Trend.stable;
  }
}

// ──────────────────────────────────────────────────────────────
// أنواع مساعدة
// ──────────────────────────────────────────────────────────────

enum _Trend { improved, stable, declined, firstAttempt }

class _NotifContent {
  final String title;
  final String body;
  final String iconName;
  final String colorHex;

  const _NotifContent({
    required this.title,
    required this.body,
    required this.iconName,
    required this.colorHex,
  });
}
