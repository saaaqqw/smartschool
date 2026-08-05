import 'package:flutter/material.dart';
import 'models/curriculum_models.dart';

export 'models/curriculum_models.dart';

/// ──────────────────────────────────────────────────────────────
/// بيانات المنهج الثابتة — قائمة المواد الأساسية وعناوين الوحدات
/// ──────────────────────────────────────────────────────────────

const List<String> _unitTitles = [
  'مقدمة المادة',
  'الوحدة الأولى',
  'الوحدة الثانية',
  'الوحدة الثالثة',
  'مراجعة نصف العام',
  'الاختبارات النهائية',
];

const List<IconData> _unitIcons = [
  Icons.auto_stories_rounded,
  Icons.menu_book_rounded,
  Icons.play_circle_outline_rounded,
  Icons.menu_book_rounded,
  Icons.fact_check_rounded,
  Icons.quiz_rounded,
];

/// يُنشئ 6 وحدات افتراضية لمادة ما (تقدمها 0 — يُحدَّث من Firestore).
List<CurriculumUnit> _defaultUnits() {
  return List<CurriculumUnit>.generate(
    6,
    (i) => CurriculumUnit(
      title: _unitTitles[i],
      icon: _unitIcons[i],
    ),
  );
}

List<CurriculumUnit> _unitsForSocial() {
  return const [
    CurriculumUnit(title: 'الجغرافيا',       icon: Icons.map_rounded),
    CurriculumUnit(title: 'التربية الوطنية', icon: Icons.flag_rounded),
    CurriculumUnit(title: 'التاريخ',          icon: Icons.history_edu_rounded),
  ];
}

List<CurriculumUnit> _unitsForQuran() {
  return const [
    CurriculumUnit(title: 'تلاوة وحفظ القرآن', icon: Icons.menu_book_rounded),
    CurriculumUnit(title: 'التجويد',            icon: Icons.record_voice_over_rounded),
  ];
}

List<CurriculumUnit> _unitsForIslamic() {
  return const [
    CurriculumUnit(title: 'الإيمان والعقيدة', icon: Icons.stars_rounded),
    CurriculumUnit(title: 'الحديث الشريف',    icon: Icons.format_quote_rounded),
    CurriculumUnit(title: 'الفقه والعبادات',   icon: Icons.balance_rounded),
    CurriculumUnit(title: 'السيرة النبوية',   icon: Icons.mosque_rounded),
  ];
}

List<CurriculumUnit> _unitsForEnglish() {
  return const [
    CurriculumUnit(title: 'كتاب الحصة (Coursebook)', icon: Icons.menu_book_rounded),
    CurriculumUnit(title: 'كتاب الواجب (Workbook)', icon: Icons.edit_note_rounded),
  ];
}

/// المواد الأساسية لمشروع المدرسة الذكية.
final List<SchoolSubject> kCoreSubjects = [
  SchoolSubject(
    subjectId: 'math',
    title: 'الرياضيات',
    color: const Color(0xFF3949AB),
    icon: Icons.calculate_rounded,
    units: _defaultUnits(),
  ),
  SchoolSubject(
    subjectId: 'science',
    title: 'العلوم',
    color: const Color(0xFF00897B),
    icon: Icons.science_rounded,
    units: _defaultUnits(),
  ),
  SchoolSubject(
    subjectId: 'arabic',
    title: 'اللغة العربية',
    color: const Color(0xFFC62828),
    icon: Icons.translate_rounded,
    units: _defaultUnits(),
  ),
  SchoolSubject(
    subjectId: 'english',
    title: 'الإنجليزية',
    color: const Color(0xFF1565C0),
    icon: Icons.abc_rounded,
    units: _unitsForEnglish(),
  ),
  SchoolSubject(
    subjectId: 'social',
    title: 'الاجتماعيات',
    color: const Color(0xFF6D4C41),
    icon: Icons.public_rounded,
    units: _unitsForSocial(),
  ),
  SchoolSubject(
    subjectId: 'islamic',
    title: 'التربية الإسلامية',
    color: const Color(0xFF6A1B9A),
    icon: Icons.mosque_rounded,
    units: _unitsForIslamic(),
  ),
  SchoolSubject(
    subjectId: 'quran',
    title: 'القرآن الكريم',
    color: Colors.amber,
    icon: Icons.menu_book,
    units: _unitsForQuran(),
  ),
];

/// المواد القابلة للتدريس الفعلي
List<SchoolSubject> get kTeachableSubjects {
  return kCoreSubjects;
}
