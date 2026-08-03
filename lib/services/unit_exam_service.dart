import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/lesson_model.dart';
import '../core/stores/user_profile_store.dart';
import 'db_keys.dart';

/// خدمة اختبار الوحدة الشامل
///
/// المنطق:
///   1. يجلب [questionsPerLesson] أسئلة عشوائية من كل درس في الوحدة.
///   2. يحفظ نتيجة الاختبار في حقل [unitExamScores] داخل مستند progress.
///   3. يتحقق من اكتمال الشرطين (جميع الدروس مكتملة + اجتياز الاختبار ≥60%).
class UnitExamService {
  static final _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════
  // جلب أسئلة اختبار الوحدة (questionsPerLesson أسئلة من كل درس)
  // ═══════════════════════════════════════════════════════════════

  /// يجلب أسئلة عشوائية من جميع دروس الوحدة.
  /// يأخذ [questionsPerLesson] من كل درس (أو أقل إن كانت الأسئلة المتوفرة أقل).
  /// يُعيد قائمة مختلطة عشوائياً من كل دروس الوحدة مرتبة بترتيب الدروس.
  Future<List<QuizQuestionModel>> fetchUnitExamQuestions({
    required String subjectId,
    required int unitIndex,
    int questionsPerLesson = 5,
  }) async {
    final doc = await _db.collection('subjects').doc(subjectId).get();
    if (!doc.exists || doc.data() == null) return [];

    final unitsRaw = doc.data()!['units'] as List? ?? [];
    if (unitIndex >= unitsRaw.length || unitsRaw[unitIndex] is! Map) return [];

    final unitMap = unitsRaw[unitIndex] as Map;
    final lessonsRaw = unitMap['lessons'] as List? ?? [];

    final List<QuizQuestionModel> allQuestions = [];
    final rng = Random();

    for (int lIdx = 0; lIdx < lessonsRaw.length; lIdx++) {
      if (lessonsRaw[lIdx] is! Map) continue;
      final lMap = lessonsRaw[lIdx] as Map;
      final qList = lMap['questions'] as List? ?? [];

      // بناء أسئلة هذا الدرس
      final List<QuizQuestionModel> lessonQs = [];
      for (int qIdx = 0; qIdx < qList.length; qIdx++) {
        if (qList[qIdx] is Map) {
          final qMap = Map<String, dynamic>.from(qList[qIdx] as Map);
          lessonQs.add(QuizQuestionModel.fromMap('u${unitIndex}_l${lIdx + 1}_q$qIdx', qMap));
        }
      }

      // خلط أسئلة الدرس وأخذ questionsPerLesson منها
      lessonQs.shuffle(rng);
      final take = lessonQs.length < questionsPerLesson ? lessonQs.length : questionsPerLesson;
      allQuestions.addAll(lessonQs.sublist(0, take));
    }

    return allQuestions;
  }

  // ═══════════════════════════════════════════════════════════════
  // حفظ نتيجة اختبار الوحدة
  // ═══════════════════════════════════════════════════════════════

  /// يحفظ نتيجة اختبار الوحدة في [unitExamScores] داخل مستند progress.
  /// يُحدِّث [unitProgress] إلى 1.0 إذا اجتاز الطالب الاختبار بنسبة ≥ [passMark].
  Future<bool> saveUnitExamScore({
    required String uid,
    required String subjectTitle,
    required String unitTitle,
    required double score,
    String semester = 'الفصل الدراسي الأول',
    String grade = 'الصف السابع',
    double passMark = 0.6,
  }) async {
    if (uid.isEmpty) return false;

    // ★ استخدام DbKeys لضمان تطابق مستند التقدم مع بقية الخدمات
    final docId = DbKeys.progressDoc(
      subjectTitle: subjectTitle,
      grade: grade,
      semester: semester,
    );
    final docRef = _db.collection('users').doc(uid).collection('progress').doc(docId);

    final passed = score >= passMark;

    final Map<String, dynamic> updateData = {
      'unitExamScores': {unitTitle: score},
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    // إذا اجتاز → تحديث تقدم الوحدة إلى 100%
    if (passed) {
      updateData['unitProgress'] = {unitTitle: 1.0};
    }

    await docRef.set(updateData, SetOptions(merge: true));
    return passed;
  }

  // ═══════════════════════════════════════════════════════════════
  // جلب درجة اختبار الوحدة السابقة (إن وجدت)
  // ═══════════════════════════════════════════════════════════════

  Future<double?> fetchUnitExamScore({
    required String uid,
    required String subjectTitle,
    required String unitTitle,
    String semester = 'الفصل الدراسي الأول',
    String grade = 'الصف السابع',
  }) async {
    if (uid.isEmpty) return null;
    final docId = DbKeys.progressDoc(
      subjectTitle: subjectTitle,
      grade: grade,
      semester: semester,
    );
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(docId)
        .get();

    if (!snap.exists || snap.data() == null) return null;
    final examScores = snap.data()!['unitExamScores'] as Map? ?? {};
    final val = examScores[unitTitle];
    if (val == null) return null;
    return (val as num).toDouble();
  }

  // ═══════════════════════════════════════════════════════════════
  // التحقق من الشرط الأول: هل أكمل الطالب جميع دروس الوحدة؟
  // ═══════════════════════════════════════════════════════════════

  /// يتحقق من [completed_lessons_set] لمعرفة عدد الدروس المكتملة من وحدة معينة.
  /// يُعيد عدد الدروس المكتملة.
  Future<int> countCompletedLessons({
    required String uid,
    required String subjectTitle,
    required int unitIndex,
    required int totalLessons,
    String semester = 'الفصل الدراسي الأول',
    String grade = 'الصف السابع',
  }) async {
    if (uid.isEmpty) return 0;
    final docId = DbKeys.progressDoc(
      subjectTitle: subjectTitle,
      grade: grade,
      semester: semester,
    );
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(docId)
        .get();

    if (!snap.exists || snap.data() == null) return 0;
    final completedSet = List<String>.from(snap.data()!['completed_lessons_set'] as List? ?? []);

    int count = 0;
    for (int l = 1; l <= totalLessons; l++) {
      if (completedSet.contains('u${unitIndex}_l$l')) count++;
    }
    return count;
  }

  /// Stream يراقب [completed_lessons_set] ويُعيد عدد الدروس المكتملة في الوحدة.
  Stream<int> completedLessonsStream({
    required String uid,
    required String subjectTitle,
    required int unitIndex,
    required int totalLessons,
    String semester = 'الفصل الدراسي الأول',
    String grade = 'الصف السابع',
  }) {
    if (uid.isEmpty) return Stream.value(0);
    final docId = DbKeys.progressDoc(
      subjectTitle: subjectTitle,
      grade: grade,
      semester: semester,
    );
    return _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(docId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return 0;
      final completedSet =
          List<String>.from(snap.data()!['completed_lessons_set'] as List? ?? []);
      int count = 0;
      for (int l = 1; l <= totalLessons; l++) {
        if (completedSet.contains('u${unitIndex}_l$l')) count++;
      }
      return count;
    });
  }

  /// Stream يُعيد درجة اختبار الوحدة (null إن لم يُجرَ بعد).
  Stream<double?> unitExamScoreStream({
    required String uid,
    required String subjectTitle,
    required String unitTitle,
    String semester = 'الفصل الدراسي الأول',
    String grade = 'الصف السابع',
  }) {
    if (uid.isEmpty) return Stream.value(null);
    final docId = DbKeys.progressDoc(
      subjectTitle: subjectTitle,
      grade: grade,
      semester: semester,
    );
    return _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(docId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final examScores = snap.data()!['unitExamScores'] as Map? ?? {};
      final val = examScores[unitTitle];
      if (val == null) return null;
      return (val as num).toDouble();
    });
  }

  // ★ تم حذف _getProgressDocId المكررة واستبدالها بـ DbKeys.progressDoc
  // لضمان توحيد معرفات المستندات عبر كل الخدمات.
}

// ══════════════════════════════════════════════════════════════════
// Extension مريح لجلب عدد الدروس المكتملة بشكل مباشر من UserProfile
// ══════════════════════════════════════════════════════════════════
extension UnitExamServiceQuick on UnitExamService {
  /// تختصر الدالة بجلب uid و semester و grade من userProfileNotifier تلقائياً.
  Stream<int> completedLessonsStreamAuto({
    required String subjectTitle,
    required int unitIndex,
    required int totalLessons,
  }) {
    final uid = userProfileNotifier.value.uid;
    final semester = userProfileNotifier.value.semester;
    final grade = userProfileNotifier.value.grade;
    return completedLessonsStream(
      uid: uid,
      subjectTitle: subjectTitle,
      unitIndex: unitIndex,
      totalLessons: totalLessons,
      semester: semester,
      grade: grade,
    );
  }

  Stream<double?> unitExamScoreStreamAuto({
    required String subjectTitle,
    required String unitTitle,
  }) {
    final uid = userProfileNotifier.value.uid;
    final semester = userProfileNotifier.value.semester;
    final grade = userProfileNotifier.value.grade;
    return unitExamScoreStream(
      uid: uid,
      subjectTitle: subjectTitle,
      unitTitle: unitTitle,
      semester: semester,
      grade: grade,
    );
  }
}
