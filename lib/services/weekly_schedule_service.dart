import 'package:cloud_firestore/cloud_firestore.dart';

/// يمثّل الجدول الدراسي الأسبوعي وإعدادات وقت الدراسة للطالب.
class WeeklySchedule {
  /// مفاتيح أيام الأسبوع بالعربية
  static const List<String> dayKeys = [
    'السبت',
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  /// خريطة: اسم اليوم → قائمة المواد
  final Map<String, List<String>> schedule;

  /// وقت بدء الدراسة (ساعة 0-23، دقيقة 0-59)
  final int startHour;
  final int startMinute;

  /// مدة الدراسة بالدقائق
  final int durationMinutes;

  const WeeklySchedule({
    required this.schedule,
    required this.startHour,
    required this.startMinute,
    required this.durationMinutes,
  });

  factory WeeklySchedule.empty() {
    return WeeklySchedule(
      schedule: {for (final d in dayKeys) d: []},
      startHour: 16,
      startMinute: 0,
      durationMinutes: 120,
    );
  }

  factory WeeklySchedule.fromMap(Map<String, dynamic> map) {
    final rawSchedule = map['schedule'] as Map<String, dynamic>? ?? {};
    final schedule = <String, List<String>>{};
    for (final day in dayKeys) {
      final list = rawSchedule[day];
      if (list is List) {
        schedule[day] = list.map((e) => e.toString()).toList();
      } else {
        schedule[day] = [];
      }
    }
    return WeeklySchedule(
      schedule: schedule,
      startHour: (map['startHour'] as num?)?.toInt() ?? 16,
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 120,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schedule': schedule,
      'startHour': startHour,
      'startMinute': startMinute,
      'durationMinutes': durationMinutes,
    };
  }

  WeeklySchedule copyWith({
    Map<String, List<String>>? schedule,
    int? startHour,
    int? startMinute,
    int? durationMinutes,
  }) {
    return WeeklySchedule(
      schedule: schedule ?? Map<String, List<String>>.from(this.schedule),
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

/// خدمة قراءة وكتابة الجدول الدراسي الأسبوعي في Firestore.
class WeeklyScheduleService {
  static const String _docField = 'weekly_schedule';

  /// مرجع مستند إعدادات الطالب.
  DocumentReference _ref(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// حفظ الجدول وإعدادات الدراسة.
  Future<void> saveSchedule(String uid, WeeklySchedule ws) async {
    await _ref(uid).set(
      {_docField: ws.toMap()},
      SetOptions(merge: true),
    );
  }

  /// قراءة الجدول مرة واحدة.
  Future<WeeklySchedule> fetchSchedule(String uid) async {
    final doc = await _ref(uid).get();
    if (!doc.exists) return WeeklySchedule.empty();
    final data = doc.data() as Map<String, dynamic>?;
    final raw = data?[_docField] as Map<String, dynamic>?;
    if (raw == null) return WeeklySchedule.empty();
    return WeeklySchedule.fromMap(raw);
  }

  /// Stream يتحدث فور تغيير أي إعداد.
  Stream<WeeklySchedule> scheduleStream(String uid) {
    return _ref(uid).snapshots().map((doc) {
      if (!doc.exists) return WeeklySchedule.empty();
      final data = doc.data() as Map<String, dynamic>?;
      final raw = data?[_docField] as Map<String, dynamic>?;
      if (raw == null) return WeeklySchedule.empty();
      return WeeklySchedule.fromMap(raw);
    });
  }

  /// تبديل حالة إنجاز مهمة اليوم (اسم المادة + تاريخ اليوم).
  Future<void> toggleTodayTask({
    required String uid,
    required String dayKey,
    required String subject,
    required bool completed,
  }) async {
    final dateStr = _todayDateStr();
    final taskDocId = '${dateStr}_${subject.replaceAll(' ', '_')}';
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_tasks')
        .doc(taskDocId)
        .set({
      'subject': subject,
      'dayKey': dayKey,
      'date': dateStr,
      'completed': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// جلب حالات إنجاز مهام اليوم.
  Stream<Map<String, bool>> todayTasksStream(String uid) {
    final dateStr = _todayDateStr();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_tasks')
        .where('date', isEqualTo: dateStr)
        .snapshots()
        .map((snap) {
      final result = <String, bool>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final subject = data['subject'] as String? ?? '';
        final completed = data['completed'] as bool? ?? false;
        result[subject] = completed;
      }
      return result;
    });
  }

  /// إرجاع اسم اليوم الحالي بالعربية.
  static String todayArabicDay() {
    final weekday = DateTime.now().weekday; // 1=Mon ... 7=Sun
    // نحوّل رقم اليوم إلى اسم عربي
    const map = {
      1: 'الاثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
      6: 'السبت',
      7: 'الأحد',
    };
    return map[weekday] ?? 'الأحد';
  }

  static String _todayDateStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// إلغاء مادة من خطة اليوم مؤقتاً (دون التأثير على الجدول الأسبوعي الدائم).
  Future<void> cancelTodayTask({
    required String uid,
    required String subject,
    required String dayKey,
  }) async {
    final dateStr = _todayDateStr();
    final taskDocId = '${dateStr}_${subject.replaceAll(' ', '_')}';
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_tasks')
        .doc(taskDocId)
        .set({
      'subject': subject,
      'dayKey': dayKey,
      'date': dateStr,
      'cancelled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream يُرجع مجموعة أسماء المواد الملغاة لهذا اليوم.
  Stream<Set<String>> todayCancelledStream(String uid) {
    final dateStr = _todayDateStr();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_tasks')
        .where('date', isEqualTo: dateStr)
        .where('cancelled', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => doc.data()['subject'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();
    });
  }

  /// إعادة تعيين جميع المهام الملغاة لليوم الحالي.
  Future<void> resetCancelledTasks(String uid) async {
    final dateStr = _todayDateStr();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_tasks')
        .where('date', isEqualTo: dateStr)
        .where('cancelled', isEqualTo: true)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'cancelled': false});
    }
    await batch.commit();
  }
}
