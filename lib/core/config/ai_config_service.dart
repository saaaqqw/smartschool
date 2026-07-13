import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// ──────────────────────────────────────────────────────────────
/// خدمة إعدادات الذكاء الاصطناعي وإدارة مفاتيح API بأمان (AI Config Service)
/// تسحب الإعدادات ديناميكياً من مستند Firestore: settings/ai_config
/// وتوفر قيم احتياطية موثوقة عند عدم الاتصال أو عدم إعداد المستند بعد.
/// ──────────────────────────────────────────────────────────────
class AiConfigService {
  static final _db = FirebaseFirestore.instance;
  static const String _defaultModel = 'llama-3.3-70b-versatile';

  static String? _cachedApiKey;
  static String? _cachedModel;

  /// جلب مفتاح Groq API المفعل حالياً ديناميكياً من Firestore فقط
  static Future<String> getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }
    try {
      final doc = await _db.collection('settings').doc('ai_config').get();
      if (doc.exists && doc.data() != null) {
        final key = doc.data()!['apiKey'] as String?;
        if (key != null && key.trim().isNotEmpty) {
          _cachedApiKey = key.trim();
          return _cachedApiKey!;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AiConfigService] تنبيه: تعذر سحب إعدادات الذكاء الاصطناعي من السحابة: $e');
    }
    return '';
  }

  /// جلب اسم نموذج الذكاء الاصطناعي المفعل حالياً
  static Future<String> getModelName() async {
    if (_cachedModel != null && _cachedModel!.isNotEmpty) {
      return _cachedModel!;
    }
    try {
      final doc = await _db.collection('settings').doc('ai_config').get();
      if (doc.exists && doc.data() != null) {
        final model = doc.data()!['modelName'] as String?;
        if (model != null && model.trim().isNotEmpty) {
          _cachedModel = model.trim();
          return _cachedModel!;
        }
      }
    } catch (_) {}
    _cachedModel = _defaultModel;
    return _cachedModel!;
  }

  /// تحديث إعدادات الذكاء الاصطناعي ومفتاح الـ API في السحابة (من لوحة تحكم المطور)
  static Future<void> updateAiConfig({
    required String apiKey,
    required String modelName,
  }) async {
    _cachedApiKey = apiKey.trim();
    _cachedModel = modelName.trim();
    await _db.collection('settings').doc('ai_config').set({
      'apiKey': _cachedApiKey,
      'modelName': _cachedModel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// مسح الذاكرة المؤقتة للإعدادات (عند إعادة التعيين)
  static void clearCache() {
    _cachedApiKey = null;
    _cachedModel = null;
  }
}
