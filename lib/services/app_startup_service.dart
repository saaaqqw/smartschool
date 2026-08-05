import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/stores/study_timer_store.dart';
import 'firebase_sync_service.dart';
import 'fcm_service.dart';
import 'connectivity_service.dart';

/// ──────────────────────────────────────────────────────────────
/// خدمة تهيئة التطبيق عند الإطلاق (App Startup Service)
///
/// تجمع كل منطق الإعداد الأولي في مكان واحد بدلاً من تشتيته
/// في main.dart، مما يُسهّل الصيانة والاختبار مستقبلاً.
/// ──────────────────────────────────────────────────────────────
class AppStartupService {
  AppStartupService._(); // singleton — لا تُنشئ نسخاً منه

  /// تهيئة Firestore Persistence (Cache محلي بدون اتصال)
  static void configureFirestore() {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {}
  }

  /// تهيئة خدمة مراقبة الاتصال
  static Future<void> initializeConnectivity() async {
    await ConnectivityService.initialize();
    debugPrint('[AppStartup] ✅ Connectivity Service جاهز');
  }

  /// تشغيل كل خدمات التهيئة للمستخدم المسجّل
  static Future<void> initializeForUser(String uid) async {
    if (uid.isEmpty) return;

    // تم الانتهاء من الترحيل.

    // تهيئة المواد في Firestore (تنشئ المستندات إن لم تكن موجودة)
    FirebaseSyncService.initializeAllSubjects().ignore();

    // تهيئة تقدم الطالب في كل المواد
    FirebaseSyncService.initializeUserProgress(uid).ignore();

    // حفظ FCM Token في Firestore لاستقبال الإشعارات
    FcmService.saveToken(uid).ignore();

    // استعادة حالة مؤقت الدراسة من آخر جلسة
    await _restoreTimerState(uid);

    debugPrint('[AppStartup] ✅ تهيئة المستخدم $uid مكتملة');
  }

  /// استعادة حالة مؤقت الدراسة من Firestore
  static Future<void> _restoreTimerState(String uid) async {
    try {
      final saved = await FirebaseSyncService.loadTimerState(uid);
      if (saved.isNotEmpty) {
        final seconds = (saved['elapsedSeconds'] as num?)?.toInt() ?? 0;
        final rawTarget = (saved['targetMinutes'] as num?)?.toInt() ?? 120;
        final target = math.max(120, rawTarget);
        studyTimerStore.setTarget(target);
        if (seconds > 0) {
          studyTimerStore.restoreElapsed(Duration(seconds: seconds));
        }
      }
    } catch (e) {
      debugPrint('[AppStartup] ⚠️ تعذّر استعادة المؤقت: $e');
    }
  }
}
