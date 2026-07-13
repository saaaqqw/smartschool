import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════
//  LessonModel — مستند الدرس في Firestore
//  المسار: subjects/{subjectId}/lessons/{lessonId}
// ═══════════════════════════════════════════════════════════════
class LessonModel {
  final String id;          // مثال: "lesson_1"
  final String title;       // عنوان الدرس
  final String videoUrl;    // معرّف يوتيوب أو رابط
  final int unitIndex;      // رقم الوحدة (0-based)
  final int lessonNumber;   // رقم الدرس داخل الوحدة
  final double lessonGrade; // أعلى درجة حققها الطالب (0.0 – 1.0)

  const LessonModel({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.unitIndex,
    required this.lessonNumber,
    this.lessonGrade = 0.0,
  });

  factory LessonModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return LessonModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      videoUrl: d['videoUrl'] as String? ?? '',
      unitIndex: (d['unitIndex'] as num?)?.toInt() ?? 0,
      lessonNumber: (d['lessonNumber'] as num?)?.toInt() ?? 1,
      lessonGrade: (d['lessonGrade'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory LessonModel.fromMap(String id, Map<String, dynamic> d, {int unitIndex = 0, int lessonNumber = 1}) {
    return LessonModel(
      id: id,
      title: d['title'] as String? ?? '',
      videoUrl: d['videoUrl'] as String? ?? '',
      unitIndex: (d['unitIndex'] as num?)?.toInt() ?? unitIndex,
      lessonNumber: (d['lessonNumber'] as num?)?.toInt() ?? lessonNumber,
      lessonGrade: (d['lessonGrade'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'videoUrl': videoUrl,
        'unitIndex': unitIndex,
        'lessonNumber': lessonNumber,
        'lessonGrade': lessonGrade,
      };

  LessonModel copyWith({double? lessonGrade}) => LessonModel(
        id: id,
        title: title,
        videoUrl: videoUrl,
        unitIndex: unitIndex,
        lessonNumber: lessonNumber,
        lessonGrade: lessonGrade ?? this.lessonGrade,
      );
}

// ═══════════════════════════════════════════════════════════════
//  QuizQuestionModel — سؤال في subcollection الأسئلة
//  المسار: subjects/{subjectId}/lessons/{lessonId}/questions/{qId}
// ═══════════════════════════════════════════════════════════════
class QuizQuestionModel {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestionModel({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final opts = (d['options'] as List? ?? []).map((e) => e.toString()).toList();
    final rawIdx = d['correctIndex'];
    return QuizQuestionModel(
      id: doc.id,
      question: d['question'] as String? ?? '',
      options: opts,
      correctIndex: rawIdx is int
          ? rawIdx
          : int.tryParse(rawIdx?.toString() ?? '0') ?? 0,
    );
  }

  factory QuizQuestionModel.fromMap(String id, Map<String, dynamic> d) {
    final opts = (d['options'] as List? ?? []).map((e) => e.toString()).toList();
    final rawIdx = d['correctIndex'];
    return QuizQuestionModel(
      id: id,
      question: d['question'] as String? ?? '',
      options: opts,
      correctIndex: rawIdx is int
          ? rawIdx
          : int.tryParse(rawIdx?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
      };
}
