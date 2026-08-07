import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GradeEntry {
  const GradeEntry({
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.color,
    required this.icon,
  });

  final String subject;
  final double score;
  final double maxScore;
  final Color color;
  final IconData icon;

  double get ratio => maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0;
  int get percent => (ratio * 100).round();

  String get ratingKey {
    if (percent >= 95) return 'rating_exc_plus';
    if (percent >= 90) return 'rating_exc';
    if (percent >= 80) return 'rating_vg';
    if (percent >= 70) return 'rating_good';
    if (percent >= 60) return 'rating_acc';
    return 'rating_poor';
  }

  bool get needsImprovement => percent < 80;

  Color get ratingColor {
    if (percent >= 90) return const Color(0xFF00897B);
    if (percent >= 80) return const Color(0xFF1E88E5);
    if (percent >= 70) return const Color(0xFFFB8C00);
    if (percent >= 60) return const Color(0xFFE53935);
    return const Color(0xFFB71C1C);
  }

  static Color colorForSubject(String subject) {
    const map = {
      'الرياضيات': Color(0xFF5C6BC0),
      'العلوم': Color(0xFF43A047),
      'اللغة العربية': Color(0xFF8E24AA),
      'اللغة الإنجليزية': Color(0xFFE53935),
      'التربية الإسلامية': Color(0xFF00ACC1),
      'التربية الاجتماعية': Color(0xFFFFB300),
      'القرآن الكريم': Color(0xFF00897B),
    };
    return map[subject] ?? const Color(0xFF78909C);
  }

  static IconData iconForSubject(String subject) {
    const map = {
      'الرياضيات': Icons.calculate_rounded,
      'العلوم': Icons.biotech_rounded,
      'اللغة العربية': Icons.language_rounded,
      'اللغة الإنجليزية': Icons.abc_rounded,
      'التربية الإسلامية': Icons.mosque_rounded,
      'التربية الاجتماعية': Icons.public_rounded,
      'القرآن الكريم': Icons.menu_book_rounded,
    };
    return map[subject] ?? Icons.menu_book_rounded;
  }

  static List<GradeEntry> parseList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return [];
    
    final Map<String, GradeEntry> uniqueEntries = {};
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final rawSubj = (d['subjectId'] ?? '') as String;
      if (rawSubj.isEmpty) continue;

      String cleanSubj = rawSubj.split('__').first.trim();
      const engMap = {
        'math': 'الرياضيات',
        'science': 'العلوم',
        'arabic': 'اللغة العربية',
        'english': 'اللغة الإنجليزية',
        'social': 'التربية الاجتماعية',
        'islamic': 'التربية الإسلامية',
        'quran': 'القرآن الكريم',
      };
      if (engMap.containsKey(cleanSubj.toLowerCase())) {
        cleanSubj = engMap[cleanSubj.toLowerCase()]!;
      }

      double score = (d['score'] as num?)?.toDouble() ?? 0.0;
      double maxScore = (d['maxScore'] as num?)?.toDouble() ?? 100.0;
      final lessonScores = d['lessonScores'] as Map? ?? {};

      if (lessonScores.isNotEmpty) {
        double sumRatio = 0.0;
        for (final val in lessonScores.values) {
          final numVal = (val as num?)?.toDouble() ?? 0.0;
          sumRatio += (numVal > 1.0 ? numVal / 100.0 : numVal).clamp(0.0, 1.0);
        }
        final ratio = (sumRatio / lessonScores.length).clamp(0.0, 1.0);
        score = ratio * 100.0;
        maxScore = 100.0;
      } else if (score <= 1.0 && score > 0.0 && maxScore == 100.0) {
        score = (score * 100.0).clamp(0.0, 100.0);
      }

      final entry = GradeEntry(
        subject: cleanSubj,
        score: score,
        maxScore: maxScore <= 0 ? 100.0 : maxScore,
        color: GradeEntry.colorForSubject(cleanSubj),
        icon: GradeEntry.iconForSubject(cleanSubj),
      );

      if (!uniqueEntries.containsKey(cleanSubj) ||
          entry.ratio > uniqueEntries[cleanSubj]!.ratio) {
        uniqueEntries[cleanSubj] = entry;
      }
    }

    return uniqueEntries.values.toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
  }
}
