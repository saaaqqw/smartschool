import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/saqer1-448ea/databases/(default)/documents/subjects?key=AIzaSyBWJPKtuVV9Sz0slgjQmmvtcIz3Uxmd9uc&pageSize=100');

  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    final data = json.decode(responseBody);
    final documents = data['documents'] as List? ?? [];

    print('=== محتويات مجموعة (subjects) في Firestore ===');
    print('عدد المستندات الحالية: ${documents.length}\n');

    final List<Map<String, dynamic>> parsedList = [];

    for (var doc in documents) {
      final name = doc['name'] as String;
      final docId = name.split('/').last;
      final fields = doc['fields'] as Map<String, dynamic>? ?? {};

      String getFieldVal(String key) {
        if (!fields.containsKey(key)) return 'غير محدد';
        final f = fields[key];
        if (f.containsKey('stringValue')) return f['stringValue'];
        if (f.containsKey('integerValue')) return f['integerValue'].toString();
        if (f.containsKey('arrayValue')) {
          final arr = f['arrayValue']['values'] as List? ?? [];
          return 'مصفوفة تحتوي على ${arr.length} عناصر';
        }
        return f.toString();
      }

      parsedList.add({
        'docId': docId,
        'title': getFieldVal('title'),
        'subjectId': getFieldVal('subjectId'),
        'grade': getFieldVal('grade'),
        'unitsCount': getFieldVal('units'),
        'createTime': doc['createTime'] ?? '',
      });
    }

    final outputFile = File('scratch/firestore_subjects.json');
    await outputFile.writeAsString(json.encode({'total': documents.length, 'subjects': parsedList}));

    for (var item in parsedList) {
      print('--- مستند: [${item['docId']}] ---');
      print('• العنوان (title): ${item['title']}');
      print('• المعرّف (subjectId): ${item['subjectId']}');
      print('• الصف (grade): ${item['grade']}');
      print('• الوحدات (units): ${item['unitsCount']}');
      print('-----------------------------------------');
    }
  } catch (e) {
    print('خطأ أثناء قراءة Firestore: $e');
  } finally {
    client.close();
  }
}
