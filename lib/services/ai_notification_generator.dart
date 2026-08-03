import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/ai_config_service.dart';
import 'connectivity_service.dart';

/// مساعِد الذكاء الاصطناعي الخاص بتوليد الإشعارات.
class AiNotificationGenerator {
  
  /// توليد نص تحفيزي صباحي
  static Future<String?> generateMorningMotivation(String studentName, List<String> subjects) async {
    final prompt = '''
أنت مساعد تعليمي ذكي في تطبيق مدرسي.
الطالب اسمه "$studentName"، ولديه اليوم المواد التالية: ${subjects.join('، ')}.
اكتب رسالة تحفيزية قصيرة جداً (أقل من 80 حرف) لتبدأ بها صباحه وتشجعه على دراسة هذه المواد.
الرسالة يجب أن تكون ودية، غير رسمية، ولا تحتوي على أي مقدمات.
''';
    return await _callGroqApi(prompt);
  }

  /// توليد نصيحة لأداء منخفض
  static Future<String?> generateLowPerformanceAdvice(String subject, double score) async {
    final prompt = '''
الطالب حصل للتو على درجة ${score.toStringAsFixed(0)}% في اختبار مادة $subject.
اكتب إشعاراً قصيراً جداً (أقل من 80 حرف) يواسيه ويشجعه ويعطيه نصيحة سريعة للتعويض.
لا تستخدم لغة قاسية أبداً ولا مقدمات.
''';
    return await _callGroqApi(prompt);
  }

  /// توليد تهنئة لأداء عالي
  static Future<String?> generateHighPerformanceCongrats(String subject, double score) async {
    final prompt = '''
الطالب حصل للتو على درجة ممتازة ${score.toStringAsFixed(0)}% في اختبار مادة $subject.
اكتب إشعار تهنئة قصير جداً (أقل من 80 حرف) يشاركه الفرحة ويشجعه على الاستمرار.
لا مقدمات، فقط رسالة التهنئة مباشرة.
''';
    return await _callGroqApi(prompt);
  }

  /// دالة الاتصال الموحدة بـ Groq Llama-3
  static Future<String?> _callGroqApi(String prompt) async {
    if (!await ConnectivityService.isConnected()) return null; // Fallback
    
    try {
      final apiKey = await AiConfigService.getApiKey();
      if (apiKey.isEmpty) return null;
      
      final modelName = await AiConfigService.getModelName();
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

      final body = {
        'model': modelName,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.8, // نسبة إبداع أعلى للإشعارات حتى لا تتكرر
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final content = decoded['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        return null;
      }
    } catch (e) {
      return null; // فشل لأي سبب (مثلاً تعليق السيرفر)، نرجع null لنستخدم Fallback
    }
  }
}
