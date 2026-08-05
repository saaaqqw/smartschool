import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'db_keys.dart';

/// خدمة تنظيف قاعدة البيانات (Database Cleanup Service)
///
/// تقوم هذه الخدمة بحذف المجموعات الفرعية القديمة (Sub-collections)
/// مثل `lessons`, `summaries`, و `questions` من كافة مستندات المواد (`subjects`).
/// وبذلك تصبح قاعدة البيانات نظيفة تماماً وتعتمد حصرياً على خريطة الدروس في `units`.
class DatabaseCleanupService {
  static final _db = FirebaseFirestore.instance;

  /// تنظيف وحذف جميع المجموعات الفرعية القديمة من كافة مستندات المادة.
  /// يُرجع عدد المجموعات أو المستندات الفرعية التي تم حذفها بنجاح.
  static Future<int> cleanOldSubcollections() async {
    int totalDeleted = 0;
    try {
      final subjectsSnap = await _db.collection('subjects').get();

      for (final subjectDoc in subjectsSnap.docs) {
        final subjectDocRef = subjectDoc.reference;

        // 1) حذف مجموعة summaries الفرعية إن وجدت
        totalDeleted += await _deleteCollection(subjectDocRef.collection('summaries'));

        // 2) حذف مجموعة lessons الفرعية وما بداخلها من أسئلة إن وجدت
        final lessonsSnap = await subjectDocRef.collection('lessons').get();
        for (final lessonDoc in lessonsSnap.docs) {
          // أولاً: حذف مجموعة questions الفرعية داخل كل درس قديم
          totalDeleted += await _deleteCollection(lessonDoc.reference.collection('questions'));
          // ثانياً: حذف مستند الدرس نفسه
          await lessonDoc.reference.delete();
          totalDeleted++;
        }
      }
      debugPrint('🎉 [DatabaseCleanupService] تم تنظيف قاعدة البيانات وحذف $totalDeleted عنصر فرعي قديم بنجاح!');
    } catch (e) {
      debugPrint('❌ [DatabaseCleanupService] خطأ أثناء تنظيف قاعدة البيانات: $e');
    }
    return totalDeleted;
  }

  /// حذف المستندات التي تعود للصفوف غير المدعومة حالياً (فقط 7، 8، 9 هي المدعومة)
  static Future<int> deleteUnusedGradesData() async {
    int totalDeleted = 0;
    final validGrades = ['الصف السابع', 'الصف الثامن', 'الصف التاسع'];
    try {
      final subjectsSnap = await _db.collection('subjects').get();
      for (final doc in subjectsSnap.docs) {
        final docId = doc.id;
        // Check if docId contains one of the valid grades
        bool isValid = false;
        for (final validGrade in validGrades) {
          if (docId.contains(validGrade)) {
            isValid = true;
            break;
          }
        }
        
        // If the document does not belong to a valid grade, delete it
        if (!isValid) {
          await doc.reference.delete();
          totalDeleted++;
          debugPrint('🗑️ Deleted unused grade subject: $docId');
        }
      }
      debugPrint('🎉 [DatabaseCleanupService] تم تنظيف وحذف $totalDeleted مادة من الصفوف غير المستخدمة!');
    } catch (e) {
      debugPrint('❌ [DatabaseCleanupService] خطأ أثناء حذف مواد الصفوف القديمة: $e');
    }
    return totalDeleted;
  }


  /// حذف المستندات القديمة المكررة ذات الأسماء الإنجليزية من مجموعة subjects
  /// (مثل: math, science, arabic, english, social, islamic, quran)
  /// واعتماد التسمية العربية حصرياً (`المادة - الصف`).
  static Future<int> deleteEnglishDuplicateSubjects() async {
    int totalDeleted = 0;
    try {
      final subjectsSnap = await _db.collection('subjects').get();
      final englishIds = {
        'math',
        'science',
        'arabic',
        'english',
        'social',
        'islamic',
        'quran'
      };

      for (final doc in subjectsSnap.docs) {
        // إذا كان معرف المستند إنجليزياً خالصاً أو ضمن المعرفات الإنجليزية القديمة
        if (englishIds.contains(doc.id) ||
            RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(doc.id)) {
          final docRef = doc.reference;
          // 1) تنظيف أي مجلدات فرعية داخل المستند أولاً
          totalDeleted += await _deleteCollection(docRef.collection('summaries'));
          final lessonsSnap = await docRef.collection('lessons').get();
          for (final lessonDoc in lessonsSnap.docs) {
            totalDeleted += await _deleteCollection(
                lessonDoc.reference.collection('questions'));
            await lessonDoc.reference.delete();
            totalDeleted++;
          }
          // 2) حذف المستند نفسه
          await docRef.delete();
          totalDeleted++;
        }
      }
      debugPrint(
          '🎉 [DatabaseCleanupService] تم حذف $totalDeleted مستند/مجلد إنجليزي مكرر بنجاح!');
    } catch (e) {
      debugPrint(
          '❌ [DatabaseCleanupService] خطأ أثناء حذف المستندات الإنجليزية: $e');
    }
    return totalDeleted;
  }

  /// تنظيف سجلات الدرجات والمعدلات القديمة غير المرتبطة بطالب معين (`grades` بدون `userId` أو غير مبدؤة بـ `uid_`).
  static Future<int> cleanOldUnscopedGrades() async {
    int totalDeleted = 0;
    try {
      final gradesSnap = await _db.collection('grades').get();
      for (final doc in gradesSnap.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        // إذا كان معرف المستند لا يحتوي على شرطتين سفليتين (أي ليس بالصيغة uid__subject__grade__semester)
        // أو إذا كان حقل userId فارغاً أو مفقوداً
        if (!doc.id.contains('__') || userId == null || userId.isEmpty) {
          await doc.reference.delete();
          totalDeleted++;
        }
      }
      debugPrint('🎉 [DatabaseCleanupService] تم حذف $totalDeleted سجل درجات قديم غير مرتبط بالطالب بنجاح!');
    } catch (e) {
      debugPrint('❌ [DatabaseCleanupService] خطأ أثناء حذف درجات النظام القديم: $e');
    }
    return totalDeleted;
  }

  /// ترحيل المناهج (الدروس والفيديوهات والأسئلة) من المسارات القديمة 
  /// (المادة - الصف) أو (الفصل الأول) إلى المسارات الجديدة الصحيحة.
  static Future<void> migrateOldSubjectsToNewFormat() async {
    try {
      debugPrint('🔄 [DatabaseCleanupService] بدء ترحيل المناهج من النظام القديم إلى الجديد...');
      final subjectsSnap = await _db.collection('subjects').get();
      int migratedCount = 0;

      for (final oldDoc in subjectsSnap.docs) {
        bool needsMigration = false;
        String? title;
        String? grade;
        String? semester;
        
        final data = oldDoc.data();
        
        // 1. صيغة الشَرطة القديمة
        if (oldDoc.id.contains(' - ')) {
          needsMigration = true;
          final parts = oldDoc.id.split(' - ');
          title = data['title'] as String? ?? parts.first.trim();
          grade = data['grade'] as String? ?? parts.last.trim();
          semester = 'الفصل الدراسي الأول'; // افتراضي
        } 
        // 2. صيغة الفصل المختصرة
        else if (oldDoc.id.endsWith('__الفصل الأول') || oldDoc.id.endsWith('__الفصل الثاني')) {
          needsMigration = true;
          final parts = oldDoc.id.split('__');
          if (parts.length >= 3) {
            title = data['title'] as String? ?? parts[0];
            grade = data['grade'] as String? ?? parts[1];
            semester = parts[2] == 'الفصل الأول' ? 'الفصل الدراسي الأول' : 'الفصل الدراسي الثاني';
          }
        }

        if (needsMigration && title != null && grade != null && semester != null) {
          final oldUnits = data['units'] as List<dynamic>?;
          
          final newDocId = DbKeys.subjectDoc(
            subjectTitle: title,
            grade: grade,
            semester: semester,
          );
          
          // دمج آمن: قراءة المستند الجديد أولاً لتجنب مسح الدروس الموجودة فيه
          final newDocRef = _db.collection('subjects').doc(newDocId);
          final newDocSnap = await newDocRef.get();
          
          List<dynamic> mergedUnits = [];
          if (newDocSnap.exists && newDocSnap.data()!.containsKey('units')) {
            mergedUnits = List.from(newDocSnap.data()!['units'] as List<dynamic>);
          }
          
          // إذا كان القديم يحتوي على وحدات، نقوم بدمجها بحذر
          if (oldUnits != null) {
            for (int i = 0; i < oldUnits.length; i++) {
              final oldUnit = oldUnits[i] as Map<String, dynamic>;
              final oldLessons = oldUnit['lessons'] as List<dynamic>? ?? [];
              
              if (oldLessons.isNotEmpty) {
                // إذا كانت الوحدة موجودة في الجديد
                if (i < mergedUnits.length) {
                  final newUnit = mergedUnits[i] as Map<String, dynamic>;
                  final newLessons = List<dynamic>.from(newUnit['lessons'] as List<dynamic>? ?? []);
                  
                  // إضافة الدروس القديمة غير الموجودة في الجديد (بناءً على lessonNumber أو title)
                  for (final oldL in oldLessons) {
                    final exists = newLessons.any((nL) => nL['lessonNumber'] == oldL['lessonNumber'] || nL['title'] == oldL['title']);
                    if (!exists) {
                      newLessons.add(oldL);
                    }
                  }
                  
                  newUnit['lessons'] = newLessons;
                  mergedUnits[i] = newUnit;
                } else {
                  // إذا الوحدة غير موجودة في الجديد أصلاً، أضفها بالكامل
                  mergedUnits.add(oldUnit);
                }
              }
            }
          }
          
          // حفظ البيانات المدمجة بأمان
          await newDocRef.set({
            'subjectId': data['subjectId'] ?? title,
            'title': title,
            'grade': grade,
            'semester': semester,
            if (mergedUnits.isNotEmpty) 'units': mergedUnits,
            if (data.containsKey('bookUrl') && (!newDocSnap.exists || !newDocSnap.data()!.containsKey('bookUrl'))) 'bookUrl': data['bookUrl'],
            if (data.containsKey('bookTitle') && (!newDocSnap.exists || !newDocSnap.data()!.containsKey('bookTitle'))) 'bookTitle': data['bookTitle'],
            'createdAt': newDocSnap.exists ? newDocSnap.data()!['createdAt'] : FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          // حذف المستند القديم بعد الترحيل الناجح لتنظيف الازدواج
          await oldDoc.reference.delete();
          migratedCount++;
          debugPrint('✅ تم دمج وحذف المستند القديم المكرر بأمان: ${oldDoc.id}');
        }
      }
      debugPrint('✅ [DatabaseCleanupService] تم ترحيل ودمج $migratedCount منهج بنجاح!');
    } catch (e) {
      debugPrint('❌ [DatabaseCleanupService] خطأ أثناء الترحيل: $e');
    }
  }

  /// الفحص والتنظيف الشامل لقاعدة البيانات بصمت (صالح للاستدعاء التلقائي عند فتح لوحة المطور)
  static Future<void> cleanAllOnce() async {
    try {
      debugPrint('🧹 [DatabaseCleanupService] بدء الفحص والتنظيف التلقائي لقاعدة البيانات...');
      final subCount = await cleanOldSubcollections();
      final engCount = await deleteEnglishDuplicateSubjects();
      final gradesCount = await cleanOldUnscopedGrades();
      await migrateOldSubjectsToNewFormat(); // إضافة الترحيل هنا ليتم استدعاؤه تلقائياً
      final total = subCount + engCount + gradesCount;
      if (total > 0) {
        debugPrint(
            '🎉 [DatabaseCleanupService] تم تنظيف قاعدة البيانات بنجاح: تم حذف $total عنصر ($engCount مواد إنجليزية، $subCount مجلد فرعي، $gradesCount سجل درجات غير معرف)');
      } else {
        debugPrint('✨ [DatabaseCleanupService] قاعدة البيانات نظيفة تماماً ولا تحتوي على أي مخلفات قديمة.');
      }
    } catch (e) {
      debugPrint('❌ [DatabaseCleanupService] خطأ أثناء الفحص والتنظيف التلقائي: $e');
    }
  }

  /// دالة مساعدة لحذف كافة المستندات داخل CollectionReference باستخدام Batch
  static Future<int> _deleteCollection(CollectionReference collRef) async {
    int deletedCount = 0;
    final snap = await collRef.get();
    if (snap.docs.isEmpty) return 0;

    // حذف في دفعات (500 مستند لكل دفعة حد أقصى في Firestore Batch)
    var batch = _db.batch();
    int countInBatch = 0;

    for (final doc in snap.docs) {
      batch.delete(doc.reference);
      countInBatch++;
      deletedCount++;

      if (countInBatch >= 450) {
        await batch.commit();
        batch = _db.batch();
        countInBatch = 0;
      }
    }

    if (countInBatch > 0) {
      await batch.commit();
    }
    return deletedCount;
  }
}
