import 'dart:convert';
import 'dart:io';

void main() async {
  final docId = Uri.encodeComponent('القرآن الكريم - الصف السابع');
  final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/saqer1-448ea/databases/(default)/documents/subjects/$docId?key=AIzaSyBWJPKtuVV9Sz0slgjQmmvtcIz3Uxmd9uc');

  final client = HttpClient();
  print('=== مزامنة وتنسيق مادة القرآن الكريم مع قاعدة البيانات ===\n');

  final unitTitles = [
    'مقدمة المادة',
    'الوحدة الأولى',
    'الوحدة الثانية',
    'الوحدة الثالثة',
    'مراجعة نصف العام',
    'الاختبارات النهائية',
  ];

  final lessonsList = [
    {'title': 'الدرس 1: سورة الفاتحة وأحكام الاستعاذة والبسملة', 'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
    {'title': 'الدرس 2: مخارج الحروف العربية وألقابها', 'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
    {'title': 'الدرس 3: صفات الحروف الذاتية والعرضية', 'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
    {'title': 'الدرس 4: أحكام النون الساكنة والتنوين (الإظهار والإدغام)', 'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
    {'title': 'الدرس 5: أحكام النون الساكنة والتنوين (الإقلاب والإخفاء)', 'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
    {'title': 'الدرس 6: أحكام الميم الساكنة والمشددة', 'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
    {'title': 'الدرس 7: المدود وأقسامها (المد الطبيعي والفرعي)', 'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
    {'title': 'الدرس 8: أحكام الوقف والابتداء وسكتات القرآن', 'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
    {'title': 'الدرس 9: تلاوة وتطبيق عملي لسور المقرر الحفظي', 'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
    {'title': 'الدرس 10: تقويم الوحدة ومراجعة التلاوة والتجويد', 'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'},
  ];

  final formattedUnits = unitTitles.map((unitTitle) {
    return {
      'mapValue': {
        'fields': {
          'title': {'stringValue': unitTitle},
          'lessons': {
            'arrayValue': {
              'values': lessonsList.map((lesson) {
                return {
                  'mapValue': {
                    'fields': {
                      'title': {'stringValue': lesson['title']!},
                      'videoUrl': {'stringValue': lesson['videoUrl']!},
                    }
                  }
                };
              }).toList()
            }
          }
        }
      }
    };
  }).toList();

  try {
    final bodyJson = json.encode({
      'fields': {
        'title': {'stringValue': 'القرآن الكريم - الصف السابع'},
        'subjectId': {'stringValue': 'quran'},
        'grade': {'stringValue': 'الصف السابع'},
        'colorHex': {'stringValue': '#FFB300'},
        'iconName': {'stringValue': 'menu_book'},
        'units': {'arrayValue': {'values': formattedUnits}},
      }
    });

    final request = await client.patchUrl(url);
    request.headers.set('Content-Type', 'application/json; charset=utf-8');
    
    // استخدام utf8.encode لتجنب خطأ تشفير الحروف العربية في HttpClient
    request.add(utf8.encode(bodyJson));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      print('✅ تم بنجاح تنسيق وتحديث مستند [القرآن الكريم - الصف السابع] في Firestore:');
      print('• العنوان (title): القرآن الكريم - الصف السابع');
      print('• الوحدات (units): 6 وحدات، كل وحدة تحتوي على 10 دروس متكاملة.');
    } else {
      print('⚠️ خطأ أثناء التحديث (الحالة: ${response.statusCode}):');
      print(responseBody);
    }
  } catch (e) {
    print('❌ خطأ في الاتصال: $e');
  } finally {
    client.close();
  }
}
