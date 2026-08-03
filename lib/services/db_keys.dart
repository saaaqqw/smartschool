/// ──────────────────────────────────────────────────────────────────
/// DbKeys — المرجع المركزي الوحيد لبناء معرفات مستندات Firestore
///
/// القاعدة الذهبية: كل معرف يشمل:
///   • اسم المادة + الصف الدراسي + الفصل الدراسي
/// لضمان العزل الكامل بين البيانات.
/// ──────────────────────────────────────────────────────────────────
class DbKeys {
  DbKeys._();

  static const _sep = '__';

  // ═══════════════════════════════════════════════════════════════
  // 1. /subjects/{docId}  — محتوى المادة (وحدات + دروس + أسئلة + فيديوهات)
  // ═══════════════════════════════════════════════════════════════

  /// مثال: "الرياضيات__الصف السابع__الفصل الدراسي الأول"
  static String subjectDoc({
    required String subjectTitle,
    required String grade,
    required String semester,
  }) {
    final g = grade.isEmpty ? 'الصف السابع' : grade;
    final s = semester.isEmpty ? 'الفصل الدراسي الأول' : semester;
    return '$subjectTitle$_sep$g$_sep$s';
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. /grades/{docId}  — درجات الطالب (مستقلة لكل صف وفصل)
  // ═══════════════════════════════════════════════════════════════

  /// مثال: "uid123__الرياضيات__الصف السابع__الفصل الدراسي الأول"
  static String gradesDoc({
    required String uid,
    required String subjectTitle,
    required String grade,
    required String semester,
  }) {
    final g = grade.isEmpty ? 'الصف السابع' : grade;
    final s = semester.isEmpty ? 'الفصل الدراسي الأول' : semester;
    return '$uid$_sep$subjectTitle$_sep$g$_sep$s';
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. /users/{uid}/progress/{docId}  — تقدم الطالب
  // ═══════════════════════════════════════════════════════════════

  /// مثال: "الرياضيات__الصف السابع__الفصل الدراسي الأول"
  static String progressDoc({
    required String subjectTitle,
    required String grade,
    required String semester,
  }) {
    final g = grade.isEmpty ? 'الصف السابع' : grade;
    final s = semester.isEmpty ? 'الفصل الدراسي الأول' : semester;
    return '$subjectTitle$_sep$g$_sep$s';
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. مفتاح درجة درس داخل lessonScores — دائماً u{unit}_l{lesson}
  // ═══════════════════════════════════════════════════════════════

  /// مثال: "u0_l3"  (الوحدة 0، الدرس 3)
  static String lessonScoreKey(int unitIndex, int lessonNumber) =>
      'u${unitIndex}_l$lessonNumber';

  // ═══════════════════════════════════════════════════════════════
  // مساعد: استخراج بيانات subjectDoc من الـ subjectDocId الكامل
  // ═══════════════════════════════════════════════════════════════

  /// يستخرج الصف والفصل من معرف المادة بالصيغة الجديدة.
  /// مثال: "الرياضيات__الصف السابع__الفصل الدراسي الأول"
  ///   → {title: "الرياضيات", grade: "الصف السابع", semester: "الفصل الدراسي الأول"}
  static Map<String, String> parseSubjectDoc(String docId) {
    final parts = docId.split(_sep);
    return {
      'title': parts.isNotEmpty ? parts[0] : '',
      'grade': parts.length > 1 ? parts[1] : 'الصف السابع',
      'semester': parts.length > 2 ? parts[2] : 'الفصل الدراسي الأول',
    };
  }
}
