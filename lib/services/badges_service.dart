import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// نموذج الشارة الرقمية (Badge) لحفز الطالب ومكافأته
class BadgeModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  BadgeModel copyWith({bool? isUnlocked, DateTime? unlockedAt}) {
    return BadgeModel(
      id: id,
      title: title,
      description: description,
      icon: icon,
      color: color,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

/// قائمة الشارات الأساسية المتاحة في المدرسة الذكية
final List<BadgeModel> kAllBadges = [
  const BadgeModel(
    id: 'first_step',
    title: 'بطل البداية 🚀',
    description: 'أكملت أول درس واختبار لك في المدرسة الذكية بنجاح!',
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFFE91E63),
  ),
  const BadgeModel(
    id: 'quiz_master',
    title: 'خبير الاختبارات 🎯',
    description: 'حصلت على درجة ممتازة في 3 اختبارات أو أكثر!',
    icon: Icons.military_tech_rounded,
    color: Color(0xFFFFB300),
  ),
  const BadgeModel(
    id: 'math_genius',
    title: 'عبقري الرياضيات 📐',
    description: 'حققت معدلاً يتجاوز 90% في مادة الرياضيات!',
    icon: Icons.calculate_rounded,
    color: Color(0xFF3949AB),
  ),
  const BadgeModel(
    id: 'science_star',
    title: 'نجم العلوم 🔬',
    description: 'حققت معدلاً يتجاوز 90% في مادة العلوم!',
    icon: Icons.science_rounded,
    color: Color(0xFF00897B),
  ),
  const BadgeModel(
    id: 'diligent_student',
    title: 'شعلة المثابرة 🔥',
    description: 'أنجزت جلساتك الدراسية وحافظت على الحضور المستمر!',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF5722),
  ),
  const BadgeModel(
    id: 'quran_reader',
    title: 'حافظ القرآن 📖',
    description: 'أتممت دروس واختبارات القرآن الكريم والتربية الإسلامية!',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF43A047),
  ),
];

/// خدمة إدارة الشارات ومكافآت التلعيب (Gamification) في Firestore
class BadgesService {
  static final _db = FirebaseFirestore.instance;

  /// جلب الشارات المكتسبة للطالب ومطابقاتها مع القائمة الشاملة
  static Future<List<BadgeModel>> fetchStudentBadges(String uid) async {
    if (uid.isEmpty) return kAllBadges;
    try {
      final doc = await _db.collection('users').doc(uid).collection('badges').doc('status').get();
      final Map<String, dynamic> unlockedMap =
          doc.exists && doc.data() != null ? Map<String, dynamic>.from(doc.data()!['unlocked'] as Map? ?? {}) : {};

      return kAllBadges.map((badge) {
        if (unlockedMap.containsKey(badge.id)) {
          final timestamp = unlockedMap[badge.id] as Timestamp?;
          return badge.copyWith(
            isUnlocked: true,
            unlockedAt: timestamp?.toDate() ?? DateTime.now(),
          );
        }
        return badge;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching badges: $e');
      return kAllBadges;
    }
  }

  /// فحص وحفظ الشارة للطالب عند تحقيق الإنجاز
  static Future<bool> unlockBadge(String uid, String badgeId) async {
    if (uid.isEmpty) return false;
    try {
      final docRef = _db.collection('users').doc(uid).collection('badges').doc('status');
      final snap = await docRef.get();
      Map<String, dynamic> unlockedMap =
          snap.exists && snap.data() != null ? Map<String, dynamic>.from(snap.data()!['unlocked'] as Map? ?? {}) : {};

      if (!unlockedMap.containsKey(badgeId)) {
        unlockedMap[badgeId] = FieldValue.serverTimestamp();
        await docRef.set({
          'unlocked': unlockedMap,
          'lastUnlockedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true; // شارة جديدة اكتسبت الآن!
      }
    } catch (e) {
      debugPrint('Error unlocking badge: $e');
    }
    return false;
  }

  /// فحص وإصدار الشارات تلقائياً بناءً على درجات ومعدلات الطالب
  static Future<List<String>> checkAndAwardBadges({
    required String uid,
    required Map<String, double> subjectPercentages,
    required int totalCompletedLessons,
  }) async {
    if (uid.isEmpty) return [];
    List<String> newlyUnlockedTitles = [];

    // 1. بطل البداية
    if (totalCompletedLessons >= 1 || subjectPercentages.values.any((p) => p > 0)) {
      if (await unlockBadge(uid, 'first_step')) {
        newlyUnlockedTitles.add('بطل البداية 🚀');
      }
    }

    // 2. خبير الاختبارات
    if (subjectPercentages.values.where((p) => p >= 80).length >= 3 || totalCompletedLessons >= 3) {
      if (await unlockBadge(uid, 'quiz_master')) {
        newlyUnlockedTitles.add('خبير الاختبارات 🎯');
      }
    }

    // 3. عبقري الرياضيات
    if ((subjectPercentages['الرياضيات'] ?? 0) >= 90) {
      if (await unlockBadge(uid, 'math_genius')) {
        newlyUnlockedTitles.add('عبقري الرياضيات 📐');
      }
    }

    // 4. نجم العلوم
    if ((subjectPercentages['العلوم'] ?? 0) >= 90) {
      if (await unlockBadge(uid, 'science_star')) {
        newlyUnlockedTitles.add('نجم العلوم 🔬');
      }
    }

    // 5. حافظ القرآن
    if ((subjectPercentages['القرآن الكريم'] ?? 0) >= 85 || (subjectPercentages['التربية الإسلامية'] ?? 0) >= 85) {
      if (await unlockBadge(uid, 'quran_reader')) {
        newlyUnlockedTitles.add('حافظ القرآن 📖');
      }
    }

    return newlyUnlockedTitles;
  }
}
