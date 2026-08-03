import 'package:workmanager/workmanager.dart';
import 'smart_notification_service.dart';
import 'notification_cache_service.dart';

/// نقطة الدخول (Entry Point) لـ WorkManager
/// يجب أن تكون دالة منفصلة خارج أي صنف (Top-level function)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // تهيئة الإشعارات لأننا في بيئة Background منعزلة
      await SmartNotificationService.init();

      switch (task) {
        case 'morning_message_task':
          await _handleMorningMessage();
          break;
        case 'streak_check_task':
          await _handleStreakCheck();
          break;
      }
      return true;
    } catch (e) {
      return false; // إعادة المحاولة إذا فشل
    }
  });
}

Future<void> _handleMorningMessage() async {
  final name = await NotificationCacheService.getStudentName();
  final aiMessage = await NotificationCacheService.getMorningAiMessage();

  if (aiMessage != null && aiMessage.isNotEmpty) {
    // إرسال الإشعار الذكي
    // استخدام flutter_local_notifications مباشرة هنا
    // قمنا بتبسيطها للتركيز على الفكرة
    await NotificationCacheService.clearMorningAiMessage(); // مسحه بعد الاستخدام
  }
}

Future<void> _handleStreakCheck() async {
  // فحص تاريخ آخر دراسة، إذا مر أكثر من يوم، إرسال تحذير.
}

/// خدمة لإدارة وإعداد مهام الخلفية
class NotificationWorker {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  /// تسجيل مهمة رسالة الصباح (تعمل كل يوم الساعة 7 صباحاً)
  static Future<void> registerMorningTask() async {
    // حساب الوقت المتبقي للساعة 7 صباحاً القادمة
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 7, 0);
    if (now.isAfter(scheduled)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final initialDelay = scheduled.difference(now);

    await Workmanager().registerPeriodicTask(
      '1', // unique name
      'morning_message_task',
      initialDelay: initialDelay,
      frequency: const Duration(days: 1), // كل يوم
    );
  }
}
