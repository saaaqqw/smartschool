import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/saqer1-448ea/databases/(default)/documents/subjects?key=AIzaSyBWJPKtuVV9Sz0slgjQmmvtcIz3Uxmd9uc');

  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    final data = json.decode(responseBody);
    final documents = data['documents'] as List? ?? [];

    for (var doc in documents) {
      final name = doc['name'] as String;
      final docId = name.split('/').last;
      final fields = doc['fields'] as Map<String, dynamic>? ?? {};
      final title = fields['title']?['stringValue'] ?? '';

      if (title.contains('الرياضيات') || title.contains('القرآن')) {
        print('=== مستند (title: $title) | docId: $docId ===');
        print(json.encode(fields));
        print('=========================================\n');
      }
    }
  } catch (e) {
    print('خطأ: $e');
  } finally {
    client.close();
  }
}
