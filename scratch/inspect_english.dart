import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;

  print('=== Inspecting English Grade 7 ===');
  
  // Try to find the document
  final query = await db.collection('subjects')
      .where('subjectId', isEqualTo: 'english')
      .where('grade', isEqualTo: 'الصف السابع')
      .get();
      
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
        print('  Lesson $j: ${lesson['title']}');
        final questions = lesson['questions'] as List? ?? [];
        print('    Questions count: ${questions.length}');
        if (questions.isNotEmpty) {
           print('    Q0: ${questions.first['questionText']}');
        }
      }
    }
  }
}
