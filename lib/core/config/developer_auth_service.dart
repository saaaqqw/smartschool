import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة رمز أمان المطورين (PIN Code) لحماية اللوحة الخاصة بهم
class DeveloperAuthService {
  static const String _pinKey = 'developer_secret_pin';
  
  /// الرمز الافتراضي للدخول لأول مرة
  static const String defaultPin = '2026';

  /// يجلب الرمز الحالي المحفوظ أو الافتراضي إن لم يُحفظ من قبل
  static Future<String> getSavedPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) ?? defaultPin;
  }

  /// يتحقق مما إذا كان الرمز المدخل يطابق الرمز السري الحالي
  static Future<bool> verifyPin(String inputPin) async {
    final currentPin = await getSavedPin();
    return inputPin.trim() == currentPin.trim();
  }

  /// يغيّر الرمز السري للمطور إلى رمز جديد
  static Future<void> changePin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, newPin.trim());
  }
}
