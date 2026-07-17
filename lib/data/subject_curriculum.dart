import 'package:flutter/material.dart';

/// وحدة دراسية ضمن مادة (مع شريط تقدم تجريبي 0–1).
class CurriculumUnit {
  const CurriculumUnit({
    required this.title,
    required this.icon,
    required this.progress,
  });

  final String title;
  final IconData icon;
  /// نسبة الإنجاز المعروضة (يمكن ربطها لاحقاً بالتخزين/Firebase).
  final double progress;
}

/// مادة أساسية مع قائمة وحدات ثابتة (6 وحدات).
class SchoolSubject {
  const SchoolSubject({
    required this.subjectId,
    required this.title,
    required this.color,
    required this.icon,
    required this.units,
  });

  final String subjectId;
  final String title;
  final Color color;
  final IconData icon;
  final List<CurriculumUnit> units;
}

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

double _demoProgress(int subjectIndex, int unitIndex) {
  final n = (subjectIndex * 19 + unitIndex * 31 + 7) % 92;
  return (n / 100).clamp(0.08, 0.98);
}

List<CurriculumUnit> _unitsForSubject(int subjectIndex) {
  return List<CurriculumUnit>.generate(
    6,
    (i) => CurriculumUnit(
      title: _unitTitles[i],
      icon: _unitIcons[i],
      progress: _demoProgress(subjectIndex, i),
    ),
  );
}

List<CurriculumUnit> _unitsForSocial() {
  return [
    CurriculumUnit(
      title: 'الجغرافيا',
      icon: Icons.map_rounded,
      progress: _demoProgress(4, 0),
    ),
    CurriculumUnit(
      title: 'التربية الوطنية',
      icon: Icons.flag_rounded,
      progress: _demoProgress(4, 1),
    ),
    CurriculumUnit(
      title: 'التاريخ',
      icon: Icons.history_edu_rounded,
      progress: _demoProgress(4, 2),
    ),
  ];
}

List<CurriculumUnit> _unitsForQuran() {
  return [
    CurriculumUnit(
      title: 'تلاوة وحفظ القرآن',
      icon: Icons.menu_book_rounded,
      progress: _demoProgress(6, 0),
    ),
    CurriculumUnit(
      title: 'التفسير',
      icon: Icons.lightbulb_outline_rounded,
      progress: _demoProgress(6, 1),
    ),
    CurriculumUnit(
      title: 'التجويد',
      icon: Icons.record_voice_over_rounded,
      progress: _demoProgress(6, 2),
    ),
  ];
}

List<CurriculumUnit> _unitsForIslamic() {
  return [
    CurriculumUnit(
      title: 'الإيمان والعقيدة',
      icon: Icons.stars_rounded,
      progress: _demoProgress(5, 0),
    ),
    CurriculumUnit(
      title: 'الحديث الشريف',
      icon: Icons.format_quote_rounded,
      progress: _demoProgress(5, 1),
    ),
    CurriculumUnit(
      title: 'الفقه والعبادات',
      icon: Icons.balance_rounded,
      progress: _demoProgress(5, 2),
    ),
    CurriculumUnit(
      title: 'السيرة النبوية',
      icon: Icons.mosque_rounded,
      progress: _demoProgress(5, 3),
    ),
  ];
}

/// المواد الأساسية لمشروع المدرسة الذكية.
final List<SchoolSubject> kCoreSubjects = [
  SchoolSubject(
    subjectId: 'math',
    title: 'الرياضيات',
    color: const Color(0xFF3949AB),
    icon: Icons.calculate_rounded,
    units: _unitsForSubject(0),
  ),
  SchoolSubject(
    subjectId: 'science',
    title: 'العلوم',
    color: const Color(0xFF00897B),
    icon: Icons.science_rounded,
    units: _unitsForSubject(1),
  ),
  SchoolSubject(
    subjectId: 'arabic',
    title: 'اللغة العربية',
    color: const Color(0xFFC62828),
    icon: Icons.translate_rounded,
    units: _unitsForSubject(2),
  ),
  SchoolSubject(
    subjectId: 'english',
    title: 'الإنجليزية',
    color: const Color(0xFF1565C0),
    icon: Icons.abc_rounded,
    units: _unitsForSubject(3),
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
