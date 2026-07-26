import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/ai_config_service.dart';

class AiRecommendationService {
  /// جلب نصيحة مخصصة لمادة معينة حسب درجة الطالب
  static Future<String> getSubjectAdvice({
    required String subject,
    required double score,
    required String grade,
  }) async {
    final rawKey = 'ai_advice_${subject}_${score.toInt()}_$grade';
    final cacheKey = base64UrlEncode(utf8.encode(rawKey));

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    } catch (e) {
      debugPrint('Cache read error: $e');
    }

    try {
      final apiKey = await AiConfigService.getGeminiApiKey();
      if (apiKey.isEmpty) {
        return 'عذراً، لم يتم إعداد مفتاح Gemini بعد. يرجى مراجعة إدارة المدرسة.';
      }

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final prompt = '''
أنت مستشار أكاديمي خبير. 
الطالب في $grade وحصل على النسبة ${score.toInt()}% في مادة $subject.
اكتب رسالة تحفيزية قصيرة جداً (لا تتجاوز 15-20 كلمة) تشجعه وتوجهه لخطوة عملية لرفع مستواه في هذه المادة.
الرسالة يجب أن تكون ودية ومباشرة وتساعده على التفوق.
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      final reply = response.text?.trim() ?? 'استمر في المحاولة، أنت قادر على التحسن!';

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, reply);
      } catch (e) {
        debugPrint('Cache save error: $e');
      }

      return reply;
    } catch (e) {
      debugPrint('Gemini Error (getSubjectAdvice): $e');
      return 'لا تفقد الأمل! خصص وقتاً إضافياً لهذه المادة وستلاحظ التحسن.';
    }
  }

  /// تحليل الدرجات واقتراح مواد لإضافتها للخطة اليومية
  /// تُرجع خريطة تحتوي على:
  /// motivation: رسالة تشجيعية عامة
  /// recommended_subjects: قائمة بأسماء المواد المقترح إضافتها اليوم
  static Future<Map<String, dynamic>> getScheduleImprovements({
    required Map<String, double> subjectScores,
    required List<String> currentTodaySubjects,
    required String grade,
  }) async {
    final scoresStr = subjectScores.entries.map((e) => '\${e.key}: \${e.value.toInt()}%').join(', ');
    final todayStr = currentTodaySubjects.join(', ');
    
    // للسرعة وتقليل التكلفة، نستخدم كاش بناءً على الدرجات ومواد اليوم
    final rawKey = 'ai_schedule_\${scoresStr}_\$todayStr';
    final cacheKey = base64UrlEncode(utf8.encode(rawKey));

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Cache read error: $e');
    }

    try {
      final apiKey = await AiConfigService.getGeminiApiKey();
      if (apiKey.isEmpty) {
        return {
          'motivation': 'قم بإضافة موادك الضعيفة لجدولك اليومي لتحسين مستواك.',
          'recommended_subjects': [],
        };
      }

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final prompt = '''
أنت مستشار أكاديمي. يقوم الطالب في $grade بطلب تحسين لجدوله اليومي بناءً على درجاته.
الدرجات الحالية للطالب هي: $scoresStr
المواد المجدولة لليوم هي: \${todayStr.isEmpty ? "لا يوجد" : todayStr}

يرجى تحليل الدرجات (التركيز على المواد الأقل من 80%).
اقترح مادة واحدة أو مادتين كحد أقصى من المواد الضعيفة التي غير موجودة في جدول اليوم لتتم إضافتها.
إذا لم يكن هناك مواد ضعيفة، اقترح المادة ذات الأولوية للمراجعة.

أعد الرد حصراً بصيغة JSON بالتنسيق التالي:
{
  "motivation": "رسالة تحفيزية قصيرة جدا (15 كلمة كحد أقصى) تخبره لماذا اخترت هذه المواد له",
  "recommended_subjects": ["اسم المادة 1", "اسم المادة 2"]
}
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      final replyText = response.text ?? '{}';
      final Map<String, dynamic> result = jsonDecode(replyText);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(result));
      } catch (e) {
        debugPrint('Cache save error: $e');
      }

      return result;
    } catch (e) {
      debugPrint('Gemini Error (getScheduleImprovements): $e');
      return {
        'motivation': 'حاول التركيز على موادك ذات التقييم الأقل لتتطور بشكل أسرع.',
        'recommended_subjects': [],
      };
    }
  }
}
