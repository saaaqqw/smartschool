import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/subject_curriculum.dart';

/// ──────────────────────────────────────────────────────────────
/// خدمة التزامن الشامل مع Firestore
/// تتولى:
///   1. تهيئة تقدم الطالب في المواد (عند أول دخول)
///   2. مزامنة وقت المؤقت مع Firestore (حفظ/استعادة)
///   3. تهيئة مستندات المواد في subjects collection
///   4. حفظ جلسات الدراسة اليومية
/// ──────────────────────────────────────────────────────────────
class FirebaseSyncService {
  static final _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════
  // دوال المعرفات والمساعدة للفصلين الدراسيين (الأول والثاني)
  // ═══════════════════════════════════════════════════════════════

  static String getSubjectDocId(
    String subjectTitle,
    String grade, {
    String semester = 'الفصل الدراسي الأول',
  }) {
    final cleanGrade = grade.isEmpty ? 'الصف السابع' : grade;
    if (semester == 'الفصل الدراسي الثاني') {
      return '$subjectTitle - $cleanGrade - الفصل الدراسي الثاني';
    }
    return '$subjectTitle - $cleanGrade';
  }

  static String getProgressDocId(String subjectTitle, {String semester = 'الفصل الدراسي الأول'}) {
    if (semester == 'الفصل الدراسي الثاني') {
      return '$subjectTitle - الفصل الدراسي الثاني';
    }
    return subjectTitle;
  }

  // ═══════════════════════════════════════════════════════════════
  // 1. تهيئة تقدم المواد
  // ═══════════════════════════════════════════════════════════════

  /// يضمن وجود مستند التقدم لكل مادة دراسية للطالب لكلا الفصلين.
  static Future<void> initializeUserProgress(String uid) async {
    if (uid.isEmpty) return;

    final batch = _db.batch();
    final progressRef = _db.collection('users').doc(uid).collection('progress');

    final semesters = ['الفصل الدراسي الأول', 'الفصل الدراسي الثاني'];
    for (final semester in semesters) {
      for (final subject in kCoreSubjects) {
        final docId = getProgressDocId(subject.title, semester: semester);
        final docRef = progressRef.doc(docId);
        final snap = await docRef.get();

        if (!snap.exists) {
          batch.set(docRef, {
            'subjectId': subject.subjectId,
            'subjectTitle': subject.title,
            'semester': semester,
            'currentUnitIndex': 0,
            'currentLessonNumber': 1,
            'unitProgress': {},
            'totalLessonsCompleted': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    await batch.commit();
  }

  /// جلب تقدم مادة معينة للطالب.
  static Future<Map<String, dynamic>> fetchSubjectProgress(
    String uid,
    String subjectTitle, {
    String semester = 'الفصل الدراسي الأول',
  }) async {
    final docId = getProgressDocId(subjectTitle, semester: semester);
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(docId)
        .get();

    if (!doc.exists) {
      return {
        'currentUnitIndex': 0,
        'currentLessonNumber': 1,
        'unitProgress': {},
        'totalLessonsCompleted': 0,
      };
    }

    return doc.data() ?? {};
  }

  /// Stream مستمر لتقدم مادة معينة للطالب.
  static Stream<Map<String, dynamic>> subjectProgressStream(
      String uid, String subjectTitle) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(subjectTitle)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. مزامنة المؤقت مع Firestore
  // ═══════════════════════════════════════════════════════════════

  static const String _timerDocField = 'study_timer';

  /// حفظ حالة مؤقت الدراسة في Firestore.
  static Future<void> saveTimerState({
    required String uid,
    required Duration elapsed,
    required int targetMinutes,
    required bool isRunning,
  }) async {
    if (uid.isEmpty) return;
    await _db.collection('users').doc(uid).set({
      _timerDocField: {
        'elapsedSeconds': elapsed.inSeconds,
        'targetMinutes': targetMinutes,
        'isRunning': isRunning,
        'savedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  /// استعادة حالة مؤقت الدراسة من Firestore.
  static Future<Map<String, dynamic>> loadTimerState(String uid) async {
    if (uid.isEmpty) return {};
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    return data[_timerDocField] as Map<String, dynamic>? ?? {};
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. حفظ جلسات الدراسة اليومية
  // ═══════════════════════════════════════════════════════════════

  /// حفظ/تحديث إجمالي وقت الدراسة لليوم الحالي.
  static Future<void> saveStudySession({
    required String uid,
    required int elapsedMinutes,
    required int targetMinutes,
  }) async {
    if (uid.isEmpty) return;

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await _db
        .collection('users')
        .doc(uid)
        .collection('study_sessions')
        .doc(dateStr)
        .set({
      'date': dateStr,
      'totalMinutes': elapsedMinutes,
      'targetMinutes': targetMinutes,
      'completed': elapsedMinutes >= targetMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// جلب إجمالي وقت دراسة المستخدم لآخر 7 أيام.
  static Future<List<Map<String, dynamic>>> fetchWeeklyStudySessions(
      String uid) async {
    if (uid.isEmpty) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('study_sessions')
        .orderBy('date', descending: true)
        .limit(7)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. تهيئة مستندات المواد في Firestore
  // ═══════════════════════════════════════════════════════════════

  /// يضمن وجود مستند المادة في مجموعة subjects للفصل المختار.
  static Future<void> ensureSubjectExists(
    SchoolSubject subject, {
    String grade = 'الصف السابع',
    String semester = 'الفصل الدراسي الأول',
  }) async {
    final docId = getSubjectDocId(subject.title, grade, semester: semester);
    final docRef = _db.collection('subjects').doc(docId);
    final snap = await docRef.get();
    if (!snap.exists) {
      await docRef.set({
        'subjectId': subject.subjectId,
        'title': subject.title,
        'grade': grade,
        'semester': semester,
        'units': subject.units
            .asMap()
            .entries
            .map((e) => {
                  'index': e.key,
                  'title': e.value.title,
                  'lessons': [],
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static const List<String> kAllGrades = [
    'الصف السابع',
    'الصف الثامن',
    'الصف التاسع',
    'الصف العاشر',
    'الصف الحادي عشر',
    'الصف الثاني عشر',
  ];

  /// تهيئة جميع المواد في Firestore لجميع الصفوف ولكلا الفصلين (الأول والثاني).
  static Future<void> initializeAllSubjects({
    List<String> grades = kAllGrades,
  }) async {
    for (final grade in grades) {
      for (final subject in kCoreSubjects) {
        await ensureSubjectExists(subject, grade: grade, semester: 'الفصل الدراسي الأول');
        await ensureSubjectExists(subject, grade: grade, semester: 'الفصل الدراسي الثاني');
      }
    }
    await syncCurriculumBranchesToFirestore(grades: grades);
  }

  /// مزامنة وتحديث أسماء فروع المواد في Firestore (الاجتماعيات، التربية الإسلامية، والقرآن الكريم) لجميع الصفوف
  static Future<void> syncCurriculumBranchesToFirestore({
    List<String> grades = kAllGrades,
  }) async {
    final targetSubjects = kCoreSubjects.where((s) =>
        s.subjectId == 'social' ||
        s.subjectId == 'islamic' ||
        s.subjectId == 'quran');

    for (final grade in grades) {
      for (final semester in ['الفصل الدراسي الأول', 'الفصل الدراسي الثاني']) {
        for (final subject in targetSubjects) {
          final docId = getSubjectDocId(subject.title, grade, semester: semester);
          final docRef = _db.collection('subjects').doc(docId);
          final snap = await docRef.get();
          if (snap.exists) {
            final data = snap.data();
            final existingUnits = (data?['units'] as List? ?? []);
            final updatedUnits = <Map<String, dynamic>>[];

            for (int i = 0; i < subject.units.length; i++) {
              final branch = subject.units[i];
              final existingLessons = i < existingUnits.length
                  ? (existingUnits[i] is Map ? (existingUnits[i]['lessons'] ?? []) : [])
                  : [];
              updatedUnits.add({
                'index': i,
                'title': branch.title,
                'lessons': existingLessons,
              });
            }
            await docRef.update({'units': updatedUnits});
          } else {
            await ensureSubjectExists(subject, grade: grade, semester: semester);
          }
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. تحديث عدد الدروس المكتملة
  // ═══════════════════════════════════════════════════════════════

  /// يزيد عداد الدروس المكتملة للمادة بمقدار 1 حسب الفصل الدراسي.
  static Future<void> incrementLessonsCompleted(
    String uid,
    String subjectTitle, {
    String semester = 'الفصل الدراسي الأول',
  }) async {
    if (uid.isEmpty) return;
    final docId = getProgressDocId(subjectTitle, semester: semester);
    await _db
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(docId)
        .set({
      'totalLessonsCompleted': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
