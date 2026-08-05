import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة التخزين المحلي المؤقت (Cache) لبيانات الإشعارات الذكية.
/// تحتفظ بالبيانات اللازمة للعمل Offline-First.
class NotificationCacheService {
  static const _storage = FlutterSecureStorage();

  // ── مفاتيح التخزين ──────────────────────────────────────────
  static const _kStudentName = 'notif_student_name';
  static const _kCurrentStreak = 'notif_current_streak';
  static const _kLastStudyDate = 'notif_last_study_date';
  static const _kMorningAiMsg = 'notif_morning_ai_msg';
  
  // لـ SharedPreferences (غير حساسة)
  static const _kStudyHour = 'notif_study_hour';
  static const _kStudyMinute = 'notif_study_minute';
  static const _kTargetMinutes = 'notif_target_minutes';

  // ── حفظ وقراءة البيانات الحساسة (Secure Storage) ────────────

  static Future<void> saveStudentName(String name) async {
    await _storage.write(key: _kStudentName, value: name);
  }

  static Future<String> getStudentName() async {
    return await _storage.read(key: _kStudentName) ?? 'يا بطل';
  }

  static Future<void> saveCurrentStreak(int streak) async {
    await _storage.write(key: _kCurrentStreak, value: streak.toString());
  }

  static Future<int> getCurrentStreak() async {
    final s = await _storage.read(key: _kCurrentStreak);
    return int.tryParse(s ?? '0') ?? 0;
  }

  static Future<void> saveLastStudyDate(String dateStr) async {
    await _storage.write(key: _kLastStudyDate, value: dateStr);
  }

  static Future<String?> getLastStudyDate() async {
    return await _storage.read(key: _kLastStudyDate);
  }

  static Future<void> saveMorningAiMessage(String message) async {
    await _storage.write(key: _kMorningAiMsg, value: message);
  }

  static Future<String?> getMorningAiMessage() async {
    return await _storage.read(key: _kMorningAiMsg);
  }

  static Future<void> clearMorningAiMessage() async {
    await _storage.delete(key: _kMorningAiMsg);
  }

  // ── حفظ وقراءة البيانات العادية (SharedPreferences) ──────────

  static Future<void> saveStudyTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStudyHour, hour);
    await prefs.setInt(_kStudyMinute, minute);
  }

  static Future<Map<String, int>> getStudyTime() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hour': prefs.getInt(_kStudyHour) ?? 16,
      'minute': prefs.getInt(_kStudyMinute) ?? 0,
    };
  }

  static Future<void> saveTargetMinutes(int target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTargetMinutes, target);
  }

  static Future<int> getTargetMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kTargetMinutes) ?? 120;
  }
}
