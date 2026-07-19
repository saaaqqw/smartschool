import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// البريد الإلكتروني للمشرف الرئيسي السوبر (الذي يحق له إضافة مشرفين آخرين أو تغيير الإعدادات الحساسة)
  static const String superAdminEmail = 'sqralqady63@gmail.com';

  /// التحقق المباشر من أن المستخدم الحالي هو المشرف الرئيسي (Super Admin)
  static bool isSuperAdmin(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return email.trim().toLowerCase() == superAdminEmail.toLowerCase();
  }

  /// التحقق من أن المستخدم مشرف مصرح له بالدخول (إما عبر البريد الرئيسي للمشرف أو وجوده في جدول admins)
  static Future<bool> isUserAuthorizedAdmin(String uid, String email) async {
    // 1. البريد الرئيسي للمشرف الأعلى له صلاحية دائمة
    if (isSuperAdmin(email)) {
      return true;
    }
    // 2. إذا لم يمتلك uid (حساب غير مسجل أو زائر)، يتم رفضه فوراً
    if (uid.isEmpty) return false;

    // 3. التحقق مما إذا كان حسابه مضافاً في مجموعة المشرفين (admins collection) في Firestore
    try {
      final doc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
      return doc.exists && doc.data() != null;
    } catch (_) {
      return false;
    }
  }

  /// يغيّر الرمز السري للمطور إلى رمز جديد
  static Future<void> changePin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, newPin.trim());
  }
}
