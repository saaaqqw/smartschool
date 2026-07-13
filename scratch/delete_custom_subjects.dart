import 'dart:io';

void main() async {
  final List<String> docIdsToDelete = [
    // المستندات العامة السبعة
    'arabic',
    'english',
    'islamic',
    'math',
    'quran',
    'science',
    'social',
    // مستندات القرآن الكريم للصفين الثامن والتاسع
    'القرآن الكريم - الصف الثامن',
    'القرآن الكريم - الصف التاسع',
  ];

  final client = HttpClient();
  print('=== البدء في حذف المستندات المحددة من Firestore ===\n');

  int successCount = 0;
  for (final docId in docIdsToDelete) {
    final encodedId = Uri.encodeComponent(docId);
    final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/saqer1-448ea/databases/(default)/documents/subjects/$encodedId?key=AIzaSyBWJPKtuVV9Sz0slgjQmmvtcIz3Uxmd9uc');

    try {
      final request = await client.deleteUrl(url);
      final response = await request.close();
      if (response.statusCode == 200) {
        print('✅ تم حذف المستند [$docId] بنجاح.');
        successCount++;
      } else if (response.statusCode == 404) {
        print('ℹ️ المستند [$docId] محذوف بالفعل أو غير موجود (404).');
        successCount++;
      } else {
        print('⚠️ حدث خطأ أثناء حذف [$docId] (الحالة: ${response.statusCode})');
      }
    } catch (e) {
      print('❌ خطأ في الاتصال أثناء حذف [$docId]: $e');
    }
  }

  client.close();
  print('\n=== انتهت العملية بنجاح ===');
}
