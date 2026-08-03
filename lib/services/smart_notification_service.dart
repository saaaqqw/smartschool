import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'ai_notification_generator.dart';
import '../core/data/motivational_texts.dart';

/// خدمة إدارة الإشعارات المحلية (Smart Notification Service)
class SmartNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  // ── القنوات ────────────────────────────────────────────────
  static const String channelStudyId = 'study_channel';
  static const String channelStudyName = 'تذكيرات الدراسة';

  static const String channelAlertsId = 'alerts_channel';
  static const String channelAlertsName = 'تنبيهات هامة';

  static const String channelAchievementsId = 'achievements_channel';
  static const String channelAchievementsName = 'إنجازات وشارات';

  // ── التهيئة ────────────────────────────────────────────────
  static Future<void> init() async {
    tz.initializeTimeZones();
    // جلب المنطقة الزمنية المحلية تلقائياً إن أمكن، هنا نعين افتراضياً الرياض كمثال
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    // التعامل مع الضغط على الإشعار (Navigation/Deep Linking)
    // يمكن لاحقاً تمرير الـ payload للشاشة المناسبة
  }

  // ── تفاصيل الإشعارات (Notification Details) ───────────────
  
  static NotificationDetails _getDetails(String channelId, String channelName, {bool isAlert = false}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: isAlert ? Importance.max : Importance.defaultImportance,
        priority: isAlert ? Priority.high : Priority.defaultPriority,
      ),
    );
  }

  // ── الإشعارات الآنية (الفورية) ─────────────────────────────

  /// إظهار إشعار فوري عند إنجاز المهام
  static Future<void> showTasksCompleted(String name) async {
    await _plugin.show(
      id: 100,
      title: 'يوم مثالي $name! 🎊',
      body: MotivationalTexts.getRandomText(MotivationalTexts.tasksCompleted),
      notificationDetails: _getDetails(channelAchievementsId, channelAchievementsName),
    );
  }

  /// إشعار نتيجة اختبار منخفضة (AI + Fallback)
  static Future<void> showLowPerformanceAlert(String name, String subject, double score) async {
    String title = '$subject تحتاج جلسة مراجعة 🔍';
    String body = '';

    final aiText = await AiNotificationGenerator.generateLowPerformanceAdvice(subject, score);
    if (aiText != null && aiText.isNotEmpty) {
      body = aiText;
    } else {
      body = MotivationalTexts.getRandomText(MotivationalTexts.lowPerformance);
    }

    await _plugin.show(
      id: 101,
      title: title,
      body: body,
      notificationDetails: _getDetails(channelAlertsId, channelAlertsName, isAlert: true),
      payload: 'quiz_$subject',
    );
  }

  /// إشعار نتيجة اختبار عالية (AI + Fallback)
  static Future<void> showHighPerformanceCongrats(String name, String subject, double score) async {
    String title = '${score.toStringAsFixed(0)}%! يا $name 🌟';
    String body = '';

    final aiText = await AiNotificationGenerator.generateHighPerformanceCongrats(subject, score);
    if (aiText != null && aiText.isNotEmpty) {
      body = aiText;
    } else {
      body = 'أداء استثنائي، حافظ على هذا المستوى!';
    }

    await _plugin.show(
      id: 102,
      title: title,
      body: body,
      notificationDetails: _getDetails(channelAchievementsId, channelAchievementsName),
      payload: 'quiz_$subject',
    );
  }

  // ── الإشعارات المجدولة ─────────────────────────────────────

  /// تذكير قبل الدراسة بـ 15 دقيقة
  static Future<void> scheduleStudyReminder(int id, DateTime scheduledTime, String name, List<String> subjects) async {
    // نجعل الموعد في المستقبل دائماً
    if (scheduledTime.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: id,
      title: 'خذ دقيقة استعداداً يا $name ☕',
      body: 'الدراسة تبدأ في ١٥ دقيقة — ${subjects.join(' و ')} اليوم',
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: _getDetails(channelStudyId, channelStudyName),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'study_reminder',
    );
  }

  /// إلغاء إشعار معين
  static Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  /// إلغاء كل الإشعارات
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
