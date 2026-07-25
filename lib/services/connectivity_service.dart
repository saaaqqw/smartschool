import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// ──────────────────────────────────────────────────────────────
/// خدمة مراقبة حالة الاتصال بالإنترنت
///
/// الاستخدام:
///   • [isOnlineNotifier] — ValueNotifier تتغير تلقائياً
///   • [isConnected()]    — فحص فوري
///   • [onConnectivityChanged] — Stream للاشتراك
/// ──────────────────────────────────────────────────────────────
class ConnectivityService {
  ConnectivityService._();

  static final _connectivity = Connectivity();

  /// حالة الاتصال الحالية — يمكن الاستماع إليها من أي مكان
  static final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);

  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// تهيئة الخدمة — تُستدعى مرة واحدة عند بدء التطبيق
  static Future<void> initialize() async {
    // فحص الحالة الأولية
    final results = await _connectivity.checkConnectivity();
    isOnlineNotifier.value = _isOnline(results);

    // الاستماع للتغييرات
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _isOnline(results);
      if (isOnlineNotifier.value != online) {
        isOnlineNotifier.value = online;
        debugPrint('[Connectivity] ${online ? "✅ متصل" : "❌ غير متصل"}');
      }
    });
  }

  /// فحص فوري هل الجهاز متصل؟
  static Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  /// Stream يُرسل true/false عند كل تغيير
  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .map((results) => _isOnline(results));
  }

  /// تحرير الموارد عند إغلاق التطبيق
  static void dispose() {
    _subscription?.cancel();
    isOnlineNotifier.dispose();
  }

  /// هل القائمة تحتوي على اتصال فعلي؟
  static bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }
}
