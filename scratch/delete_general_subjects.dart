import 'dart:io';

void main() async {
  final List<String> docIdsToDelete = [
    'arabic',
    'english',
    'islamic',
    'math',
    'quran',
    'science',
    'social',
  ];

  final client = HttpClient();
  print('=== البدء في حذف المستندات العامة (7 مستندات) من Firestore ===\n');

  int successCount = 0;
  for (final docId in docIdsToDelete) {
    final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/saqer1-448ea/databases/(default)/documents/subjects/$docId?key=AIzaSyBWJPKtuVV9Sz0slgjQmmvtcIz3Uxmd9uc');

    try {
      final request = await client.deleteUrl(url);
      final response = await request.close();
      if (response.statusCode == 200) {
        print('✅ تم حذف المستند [$docId] بنجاح.');
        successCount++;
      } else {
        print('⚠️ حدث خطأ أثناء حذف [$docId] (الحالة: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ خطأ في الاتصال أثناء حذف [$docId]: $e');
    }
  }

  client.close();
  print('\n=== انتهت العملية: تم حذف $successCount من أصل ${docIdsToDelete.length} مستندات ===');
}
