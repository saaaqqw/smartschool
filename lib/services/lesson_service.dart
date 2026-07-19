import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/lesson_model.dart';
import '../core/stores/user_profile_store.dart';

/// خدمة Firestore للدروس والأسئلة المرتبطة بها.
///
/// هيكل البيانات:
///   subjects/{subjectId}/lessons/{lessonId}          ← مستند الدرس (يحتوي على lessonGrade)
///   subjects/{subjectId}/lessons/{lessonId}/questions ← subcollection الأسئلة
class LessonService {
  static final _db = FirebaseFirestore.instance;

  // ── استخراج رقم الدرس من معرف مثل 'lesson_1' ──
  static int _parseLessonNum(String lessonId) {
    final clean = lessonId.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 1;
  }

  // ════════════════════════════════════════════════════════════
  // قراءة قائمة الدروس لوحدة محددة
  // ════════════════════════════════════════════════════════════

  /// جلب جميع دروس وحدة معينة من خريطة units داخل مستند المادة مدموجة بدرجة الطالب.
  Future<List<LessonModel>> fetchLessonsForUnit({
    required String subjectId,
    required int unitIndex,
  }) async {
    final doc = await _db.collection('subjects').doc(subjectId).get();
    if (!doc.exists || doc.data() == null) return [];

    final unitsRaw = doc.data()!['units'] as List? ?? [];
    if (unitIndex >= unitsRaw.length || unitsRaw[unitIndex] is! Map) {
      return [];
    }

    final uid = userProfileNotifier.value.uid;
    final cleanTitle = subjectId.split(' - ').first;
    Map<String, dynamic> scores = {};
    if (uid.isNotEmpty) {
      final gradesDoc = await _db.collection('grades').doc('${uid}_$cleanTitle').get();
      if (gradesDoc.exists && gradesDoc.data() != null) {
        scores = Map<String, dynamic>.from(gradesDoc.data()!['lessonScores'] as Map? ?? {});
      }
    }

    final unitMap = unitsRaw[unitIndex] as Map;
    final lessonsRaw = unitMap['lessons'] as List? ?? [];

    List<LessonModel> results = [];
    for (int i = 0; i < lessonsRaw.length; i++) {
      final lData = lessonsRaw[i] is Map ? lessonsRaw[i] as Map : {};
      final title = lData['title'] as String? ?? 'الدرس ${i + 1}';
      final videoUrl = lData['videoUrl'] as String? ?? '';
      final numStr = '${i + 1}';
      final studentGrade = scores.containsKey(numStr) ? (scores[numStr] as num?)?.toDouble() : null;
      final grade = studentGrade ?? ((lData['lessonGrade'] as num?)?.toDouble() ?? 0.0);

      results.add(LessonModel(
        id: 'lesson_${i + 1}',
        title: title,
        videoUrl: videoUrl,
        unitIndex: unitIndex,
        lessonNumber: i + 1,
        lessonGrade: grade,
      ));
    }
    return results;
  }

  /// Stream يُحدَّث تلقائياً عند تغيير دروس الوحدة في خريطة units أو تغيير درجة الطالب في درس.
  Stream<List<LessonModel>> lessonsStream({
    required String subjectId,
    required int unitIndex,
  }) {
    final uid = userProfileNotifier.value.uid;
    final cleanTitle = subjectId.split(' - ').first;

    final subjectStream = _db.collection('subjects').doc(subjectId).snapshots();
    final gradesStream = uid.isNotEmpty
        ? _db.collection('grades').doc('${uid}_$cleanTitle').snapshots()
        : Stream<DocumentSnapshot<Map<String, dynamic>>?>.value(null);

    late StreamController<List<LessonModel>> controller;
    StreamSubscription? subjSub;
    StreamSubscription? gradesSub;

    DocumentSnapshot<Map<String, dynamic>>? lastSubjDoc;
    DocumentSnapshot<Map<String, dynamic>>? lastGradesDoc;

    void emitIfReady() {
      if (lastSubjDoc == null) return;
      final doc = lastSubjDoc!;
      if (!doc.exists || doc.data() == null) {
        if (!controller.isClosed) controller.add(<LessonModel>[]);
        return;
      }

      final unitsRaw = doc.data()!['units'] as List? ?? [];
      if (unitIndex >= unitsRaw.length || unitsRaw[unitIndex] is! Map) {
        if (!controller.isClosed) controller.add(<LessonModel>[]);
        return;
      }

      final unitMap = unitsRaw[unitIndex] as Map;
      final lessonsRaw = unitMap['lessons'] as List? ?? [];
      final scores = lastGradesDoc != null && lastGradesDoc!.exists
          ? (lastGradesDoc!.data()?['lessonScores'] as Map? ?? {})
          : {};

      List<LessonModel> results = [];
      for (int i = 0; i < lessonsRaw.length; i++) {
        final lData = lessonsRaw[i] is Map ? lessonsRaw[i] as Map : {};
        final title = lData['title'] as String? ?? 'الدرس ${i + 1}';
        final videoUrl = lData['videoUrl'] as String? ?? '';
        final numStr = '${i + 1}';
        final studentGrade = scores.containsKey(numStr)
            ? (scores[numStr] as num?)?.toDouble()
            : null;
        final grade = studentGrade ?? ((lData['lessonGrade'] as num?)?.toDouble() ?? 0.0);

        results.add(LessonModel(
          id: 'lesson_${i + 1}',
          title: title,
          videoUrl: videoUrl,
          unitIndex: unitIndex,
          lessonNumber: i + 1,
          lessonGrade: grade,
        ));
      }

      if (!controller.isClosed) controller.add(results);
    }

    controller = StreamController<List<LessonModel>>.broadcast(
      onListen: () {
        subjSub = subjectStream.listen((doc) {
          lastSubjDoc = doc;
          emitIfReady();
        });
        gradesSub = gradesStream.listen((doc) {
          lastGradesDoc = doc;
          emitIfReady();
        });
      },
      onCancel: () {
        subjSub?.cancel();
        gradesSub?.cancel();
      },
    );

    return controller.stream;
  }

  // ════════════════════════════════════════════════════════════
  // قراءة الأسئلة من خريطة الدرس المنظّمة وخلطها عشوائياً
  // ════════════════════════════════════════════════════════════

  /// يجلب كل أسئلة الدرس من مصفوفة questions داخل خريطة الدرس في units.
  Future<List<QuizQuestionModel>> fetchRandomizedQuestions({
    required String subjectId,
    required String lessonId,
    int? unitIndex,
    int limit = 10,
  }) async {
    final lessonNum = _parseLessonNum(lessonId);
    final doc = await _db.collection('subjects').doc(subjectId).get();

    if (!doc.exists || doc.data() == null) return [];

    final unitsRaw = doc.data()!['units'] as List? ?? [];
    List<QuizQuestionModel> all = [];

    if (unitIndex != null && unitIndex >= 0 && unitIndex < unitsRaw.length) {
      if (unitsRaw[unitIndex] is Map) {
        final uMap = unitsRaw[unitIndex] as Map;
        final lList = uMap['lessons'] as List? ?? [];
        if (lessonNum - 1 < lList.length && lList[lessonNum - 1] is Map) {
          final lMap = lList[lessonNum - 1] as Map;
          final qList = lMap['questions'] as List? ?? [];
          for (int qIdx = 0; qIdx < qList.length; qIdx++) {
            if (qList[qIdx] is Map) {
              final qMap = Map<String, dynamic>.from(qList[qIdx] as Map);
              all.add(QuizQuestionModel.fromMap('q_$qIdx', qMap));
            }
          }
        }
      }
    } else {
      // البحث في كافة الوحدات كحل بديل في حال لم يتم تمرير unitIndex
      for (int uIdx = 0; uIdx < unitsRaw.length; uIdx++) {
        if (unitsRaw[uIdx] is Map) {
          final uMap = unitsRaw[uIdx] as Map;
          final lList = uMap['lessons'] as List? ?? [];
          if (lessonNum - 1 < lList.length && lList[lessonNum - 1] is Map) {
            final lMap = lList[lessonNum - 1] as Map;
            final qList = lMap['questions'] as List? ?? [];
            for (int qIdx = 0; qIdx < qList.length; qIdx++) {
              if (qList[qIdx] is Map) {
                final qMap = Map<String, dynamic>.from(qList[qIdx] as Map);
                all.add(QuizQuestionModel.fromMap('q_$qIdx', qMap));
              }
            }
            break; // تم العثور على الدرس وأسئلته بنجاح
          }
        }
      }
    }

    // ── الخلط العشوائي ─────────────────────────────────────
    if (all.isEmpty) return [];
    all.shuffle(Random());

    // ── تقليص إلى العدد المطلوب ──────────────────────────────
    if (limit > 0 && all.length > limit) {
      return all.sublist(0, limit);
    }
    return all;
  }

  // ════════════════════════════════════════════════════════════
  // تحديث أعلى درجة (Best Score) في خريطة الدرس مباشرة
  // ════════════════════════════════════════════════════════════

  Future<bool> saveBestScore({
    required String subjectId,
    required String lessonId,
    int? unitIndex,
    required double newScore,
  }) async {
    final lessonNum = _parseLessonNum(lessonId);
    final String scoreKey = unitIndex != null ? 'u${unitIndex}_l$lessonNum' : '$lessonNum';
    final uid = userProfileNotifier.value.uid;
    if (uid.isEmpty) return false;

    final cleanTitle = subjectId.split(' - ').first;
    final gradesDocRef = _db.collection('grades').doc('${uid}_$cleanTitle');

    return _db.runTransaction<bool>((tx) async {
      // 1. قراءة مستند درجات الطالب الخاص في هذه المادة
      final gradesSnap = await tx.get(gradesDocRef);
      Map<String, dynamic> lessonScores = {};
      if (gradesSnap.exists && gradesSnap.data() != null) {
        lessonScores = Map<String, dynamic>.from(gradesSnap.data()!['lessonScores'] as Map? ?? {});
      }

      final currentLessonScore = (lessonScores[scoreKey] as num?)?.toDouble() ?? 0.0;
      if (newScore > currentLessonScore || !lessonScores.containsKey(scoreKey)) {
        lessonScores[scoreKey] = newScore;
      } else {
        // الدرجة الحالية أفضل أو مساوية، لا داعي للتحديث
        return true;
      }

      // 3. حساب المعدل العام للمادة للطالب بناءً على متوسط الدروس المنجزة والمختبرة فقط
      double sumRatio = 0.0;
      for (final val in lessonScores.values) {
        final numVal = (val as num?)?.toDouble() ?? 0.0;
        sumRatio += (numVal > 1.0 ? numVal / 100.0 : numVal).clamp(0.0, 1.0);
      }
      final overallRatio = lessonScores.isNotEmpty
          ? (sumRatio / lessonScores.length).clamp(0.0, 1.0)
          : (newScore > 1.0 ? newScore / 100.0 : newScore).clamp(0.0, 1.0);

      tx.set(
        gradesDocRef,
        {
          'userId': uid,
          'subjectId': cleanTitle,
          'score': (overallRatio * 100.0).clamp(0.0, 100.0),
          'maxScore': 100.0,
          'lessonScores': lessonScores,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return true;
    });
  }

  /// قراءة درجة درس واحد للطالب من مستنده الخاص (أو استعادة التوافق من المنهج إن وجد سابقاً).
  Future<double> fetchLessonGrade({
    required String subjectId,
    required String lessonId,
    int? unitIndex,
  }) async {
    final lessonNum = _parseLessonNum(lessonId);
    final String scoreKey = unitIndex != null ? 'u${unitIndex}_l$lessonNum' : '$lessonNum';
    final uid = userProfileNotifier.value.uid;
    if (uid.isNotEmpty) {
      final cleanTitle = subjectId.split(' - ').first;
      final gradeDoc = await _db.collection('grades').doc('${uid}_$cleanTitle').get();
      if (gradeDoc.exists && gradeDoc.data() != null) {
        final scores = gradeDoc.data()!['lessonScores'] as Map? ?? {};
        if (scores.containsKey(scoreKey)) {
          return (scores[scoreKey] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    final doc = await _db.collection('subjects').doc(subjectId).get();
    if (!doc.exists || doc.data() == null) return 0.0;

    final unitsRaw = doc.data()!['units'] as List? ?? [];
    for (int uIdx = 0; uIdx < unitsRaw.length; uIdx++) {
      if (unitsRaw[uIdx] is Map) {
        final uMap = unitsRaw[uIdx] as Map;
        final lList = uMap['lessons'] as List? ?? [];
        if (lessonNum - 1 < lList.length && lList[lessonNum - 1] is Map) {
          final lMap = lList[lessonNum - 1] as Map;
          return (lMap['lessonGrade'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }
    return 0.0;
  }

  // ════════════════════════════════════════════════════════════
  // إدارة الأسئلة في خريطة الدرس داخل units
  // ════════════════════════════════════════════════════════════

  Future<void> addQuestion({
    required String subjectId,
    required String lessonId,
    required QuizQuestionModel question,
  }) async {
    final lessonNum = _parseLessonNum(lessonId);
    final docRef = _db.collection('subjects').doc(subjectId);

    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return;

    final unitsRaw = List<dynamic>.from(snap.data()!['units'] as List? ?? []);
    for (int uIdx = 0; uIdx < unitsRaw.length; uIdx++) {
      if (unitsRaw[uIdx] is Map) {
        final uMap = Map<String, dynamic>.from(unitsRaw[uIdx] as Map);
        final lList = List<dynamic>.from(uMap['lessons'] as List? ?? []);
        if (lessonNum - 1 < lList.length && lList[lessonNum - 1] is Map) {
          final lMap = Map<String, dynamic>.from(lList[lessonNum - 1] as Map);
          final qList = List<dynamic>.from(lMap['questions'] as List? ?? []);
          qList.add(question.toFirestore());
          lMap['questions'] = qList;
          lList[lessonNum - 1] = lMap;
          uMap['lessons'] = lList;
          unitsRaw[uIdx] = uMap;
          await docRef.set({'units': unitsRaw}, SetOptions(merge: true));
          break;
        }
      }
    }
  }

  Future<void> seedQuestions({
    required String subjectId,
    required String lessonId,
    required List<QuizQuestionModel> questions,
  }) async {
    for (final q in questions) {
      await addQuestion(subjectId: subjectId, lessonId: lessonId, question: q);
    }
  }

  Future<void> ensureLessonExists({
    required String subjectId,
    required LessonModel lesson,
  }) async {
    final docRef = _db.collection('subjects').doc(subjectId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return;

    final unitsRaw = List<dynamic>.from(snap.data()!['units'] as List? ?? []);
    while (unitsRaw.length <= lesson.unitIndex) {
      unitsRaw.add({'title': 'الوحدة ${unitsRaw.length + 1}', 'lessons': []});
    }
    final uMap = Map<String, dynamic>.from(unitsRaw[lesson.unitIndex] as Map);
    final lList = List<dynamic>.from(uMap['lessons'] as List? ?? []);
    while (lList.length < lesson.lessonNumber) {
      lList.add({
        'title': '',
        'videoUrl': '',
        'summaryContent': '',
        'questions': [],
      });
    }
    if ((lList[lesson.lessonNumber - 1] is Map) &&
        (lList[lesson.lessonNumber - 1] as Map)['title']
            .toString()
            .trim()
            .isEmpty) {
      lList[lesson.lessonNumber - 1] = {
        'title': lesson.title,
        'videoUrl': lesson.videoUrl,
        'summaryContent': '',
        'questions': [],
      };
      uMap['lessons'] = lList;
      unitsRaw[lesson.unitIndex] = uMap;
      await docRef.set({'units': unitsRaw}, SetOptions(merge: true));
    }
  }
}
