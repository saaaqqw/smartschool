import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────
/// نماذج المنهج الدراسي — CurriculumUnit & SchoolSubject
/// ──────────────────────────────────────────────────────────────

/// وحدة دراسية ضمن مادة (مع شريط تقدم يُمرَّر من Firestore).
class CurriculumUnit {
  const CurriculumUnit({
    required this.title,
    required this.icon,
    this.progress = 0.0,
  });

  final String title;
  final IconData icon;

  /// نسبة الإنجاز (0.0 – 1.0) — تُسحب من Firestore ولا تُحسب محلياً.
  final double progress;
}

/// مادة دراسية أساسية مع قائمة وحداتها.
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
