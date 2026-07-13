import 'dart:convert';
import 'dart:io';

void main() async {
  final docId = Uri.encodeComponent('القرآن الكريم - الصف السابع');
  final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/saqer1-448ea/databases/(default)/documents/subjects/$docId?updateMask.fieldPaths=title&updateMask.fieldPaths=colorHex&updateMask.fieldPaths=iconName&key=AIzaSyBWJPKtuVV9Sz0slgjQmmvtcIz3Uxmd9uc');

  final client = HttpClient();
  print('=== تنسيق مستند [القرآن الكريم - الصف السابع] في Firestore ===\n');

  try {
    final body = json.encode({
      'fields': {
        'title': {'stringValue': 'القرآن الكريم - الصف السابع'},
        'colorHex': {'stringValue': '#FFB300'},
        'iconName': {'stringValue': 'menu_book'},
      }
    });

    final request = await client.patchUrl(url);
    request.headers.set('Content-Type', 'application/json');
    request.write(body);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      print('✅ تم تنسيق وتحديث مستند [القرآن الكريم - الصف السابع] بنجاح ليطابق بقية المواد:');
      print('• العنوان (title): القرآن الكريم - الصف السابع');
      print('• اللون (colorHex): #FFB300');
      print('• الأيقونة (iconName): menu_book');
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
