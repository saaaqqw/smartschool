import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// ──────────────────────────────────────────────────────────────
/// خدمة Firebase Cloud Messaging (FCM) لاستقبال الإشعارات
/// في الخلفية (Background) وعند إغلاق التطبيق (Terminated).
/// ──────────────────────────────────────────────────────────────

/// معالج الإشعارات في الخلفية — يجب أن يكون دالة مستقلة (Top-Level).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] إشعار في الخلفية: ${message.notification?.title}');
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  /// تهيئة FCM وطلب إذن الإشعارات من المستخدم.
  static Future<void> initialize() async {
    // تسجيل معالج الخلفية
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // طلب إذن الإشعارات (iOS & Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('[FCM] حالة الإذن: ${settings.authorizationStatus}');

    // الاستماع للإشعارات عند فتح التطبيق (Foreground)
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] إشعار في المقدمة: ${message.notification?.title}');
      // يمكن عرض SnackBar أو Dialog هنا عند الحاجة
    });

    // الاستماع لفتح التطبيق عبر الضغط على إشعار من الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] تم فتح التطبيق عبر إشعار: ${message.notification?.title}');
    });
  }

  /// حفظ FCM Token في Firestore تحت users/{uid}/fcmToken
  /// يُستدعى عند نجاح تسجيل الدخول.
  static Future<void> saveToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _db.collection('users').doc(uid).set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[FCM] تم حفظ Token بنجاح: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      debugPrint('[FCM] تعذّر حفظ Token: $e');
    }

    // تحديث التوكن تلقائياً عند التجديد
    _messaging.onTokenRefresh.listen((newToken) async {
      if (uid.isNotEmpty) {
        await _db.collection('users').doc(uid).set({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[FCM] تم تحديث Token تلقائياً.');
      }
    });
  }

  /// حذف FCM Token من Firestore عند تسجيل الخروج.
  static Future<void> deleteToken(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _messaging.deleteToken();
      await _db.collection('users').doc(uid).update({'fcmToken': FieldValue.delete()});
      debugPrint('[FCM] تم حذف Token عند تسجيل الخروج.');
    } catch (_) {}
  }
}
