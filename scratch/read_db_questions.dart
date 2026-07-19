import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;

  print('=== Inspecting English Grade 7 Semester 1 ===');
  
  final query = await db.collection('subjects')
      .where('subjectId', isEqualTo: 'english')
      .where('grade', isEqualTo: 'الصف السابع')
      .where('semester', isEqualTo: 'الفصل الدراسي الأول')
      .get();
      
  if (query.docs.isEmpty) {
     print('No document found!');
     return;
  }
      
  for (var doc in query.docs) {
    print('Document ID: ${doc.id}');
    final data = doc.data();
    final units = data['units'] as List? ?? [];
    
    for (int i = 0; i < units.length; i++) {
      final unit = units[i];
      print('Unit $i: ${unit['title']}');
      final lessons = unit['lessons'] as List? ?? [];
      for (int j = 0; j < lessons.length; j++) {
        final lesson = lessons[j];
        final questions = lesson['questions'] as List? ?? [];
        if (questions.isNotEmpty) {
           print('  Lesson $j (${lesson['title']}) - Questions: ${questions.length}');
           print('    Q0: ${questions.first['questionText'] ?? questions.first['question']}');
        }
      }
    }
  }
}
