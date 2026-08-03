import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/stores/user_profile_store.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const NotificationsScreen());
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  Set<String> _readIds = {};
  bool _notificationsEnabled = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('read_notification_ids') ?? [];
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    if (mounted) {
      setState(() {
        _readIds = list.toSet();
        _notificationsEnabled = enabled;
      });
    }
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = docs.map((d) => d.id).toSet();
    _readIds.addAll(ids);
    await prefs.setStringList('read_notification_ids', _readIds.toList());
    if (mounted) setState(() {});
  }

  Future<void> _markSingleAsRead(String docId) async {
    final prefs = await SharedPreferences.getInstance();
    _readIds.add(docId);
    await prefs.setStringList('read_notification_ids', _readIds.toList());
    if (mounted) setState(() {});
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'الآن';
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      return 'الآن';
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'منذ لحظات';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = userProfileNotifier.value;
    final studentGrade = profile.grade.trim();
    final uid = profile.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الإشعارات والتنبيهات',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w800, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13),
          indicatorColor: scheme.primary,
          tabs: const [
            Tab(text: '📢 إشعارات المدرسة', icon: null),
            Tab(text: '📊 نتائجي', icon: null),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── التبويب الأول: إشعارات المدرسة ──────────────────────
          _SchoolNotificationsTab(
            studentGrade: studentGrade,
            readIds: _readIds,
            notificationsEnabled: _notificationsEnabled,
            onMarkAllRead: _markAllAsRead,
            onMarkOneRead: _markSingleAsRead,
            formatTimestamp: _formatTimestamp,
          ),

          // ── التبويب الثاني: نتائج الاختبارات الشخصية ─────────────
          _MyResultsTab(
            uid: uid,
            formatTimestamp: _formatTimestamp,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// التبويب الأول: إشعارات المدرسة (الكود الأصلي)
// ══════════════════════════════════════════════════════════════════
class _SchoolNotificationsTab extends StatelessWidget {
  const _SchoolNotificationsTab({
    required this.studentGrade,
    required this.readIds,
    required this.notificationsEnabled,
    required this.onMarkAllRead,
    required this.onMarkOneRead,
    required this.formatTimestamp,
  });

  final String studentGrade;
  final Set<String> readIds;
  final bool notificationsEnabled;
  final Future<void> Function(List<QueryDocumentSnapshot>) onMarkAllRead;
  final Future<void> Function(String) onMarkOneRead;
  final String Function(dynamic) formatTimestamp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 54, color: scheme.error),
                  const SizedBox(height: 12),
                  Text(
                    'حدث خطأ في تحميل الإشعارات',
                    style: GoogleFonts.tajawal(
                        fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;
        final docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          final target = (data['targetGrade'] ?? 'الكل').toString().trim();
          if (target == 'الكل' || target == 'جميع الطلاب') return true;
          if (studentGrade.isNotEmpty && target == studentGrade) return true;
          return false;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_off_rounded, size: 64, color: scheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد إشعارات حالياً',
                    style: GoogleFonts.tajawal(
                        fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ستظهر هنا جميع إعلانات المدرسة وتنبيهات المعلمين الخاصة بصفك الدراسي.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                        fontSize: 14, color: scheme.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        final unreadCount = docs.where((d) => !readIds.contains(d.id)).length;

        return Column(
          children: [
            if (!notificationsEnabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.amber.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Icon(Icons.notifications_off_rounded,
                        size: 22, color: Colors.amber.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تنبيه: الإشعارات الفورية معطلة من إعدادات التطبيق.',
                        style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    Icon(Icons.mark_email_unread_rounded, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لديك ($unreadCount) إشعار جديد',
                        style: GoogleFonts.tajawal(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => onMarkAllRead(docs),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: Text('قراءة الكل',
                          style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final title = data['title'] ?? 'تنبيه جديد';
                  final body = data['body'] ?? '';
                  final type = (data['type'] ?? 'general').toString().toLowerCase();
                  final target = data['targetGrade'] ?? 'الكل';
                  final sender = data['senderName'] ?? 'إدارة المدرسة';
                  final imageUrl = data['imageUrl'] ?? '';
                  final actionLink = data['actionLink'] ?? '';
                  final timestamp = data['createdAt'];
                  final isRead = readIds.contains(doc.id);

                  Color cardAccentColor;
                  IconData cardIcon;
                  String typeLabel;

                  if (type == 'urgent' || type == 'هام' || type == 'عاجل وهام') {
                    cardAccentColor = Colors.red.shade600;
                    cardIcon = Icons.notification_important_rounded;
                    typeLabel = 'عاجل وهام';
                  } else if (type == 'study' || type == 'أكاديمي' || type == 'درس جديد') {
                    cardAccentColor = Colors.amber.shade700;
                    cardIcon = Icons.auto_stories_rounded;
                    typeLabel = 'تنبيه دراسي';
                  } else {
                    cardAccentColor = scheme.primary;
                    cardIcon = Icons.notifications_active_rounded;
                    typeLabel = 'تنبيه عام';
                  }

                  return Card(
                    elevation: 0,
                    color: isRead
                        ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                        : cardAccentColor.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isRead
                            ? Colors.transparent
                            : cardAccentColor.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (!isRead) onMarkOneRead(doc.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cardAccentColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(cardIcon, color: cardAccentColor, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: cardAccentColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          typeLabel,
                                          style: GoogleFonts.tajawal(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: cardAccentColor),
                                        ),
                                      ),
                                      if (target != 'الكل' && target != 'جميع الطلاب') ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: scheme.secondary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            target.toString(),
                                            style: GoogleFonts.tajawal(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: scheme.secondary),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Text(
                                        formatTimestamp(timestamp),
                                        style: GoogleFonts.tajawal(
                                            fontSize: 11.5,
                                            color: scheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    title.toString(),
                                    style: GoogleFonts.tajawal(
                                        fontSize: 16,
                                        fontWeight:
                                            isRead ? FontWeight.w700 : FontWeight.w900,
                                        color: scheme.onSurface,
                                        height: 1.3),
                                  ),
                                  if (body.toString().trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      body.toString(),
                                      style: GoogleFonts.tajawal(
                                          fontSize: 13.5,
                                          color: scheme.onSurfaceVariant,
                                          height: 1.45),
                                    ),
                                  ],
                                  if (imageUrl.toString().trim().isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        imageUrl.toString().trim(),
                                        height: 140,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const SizedBox(),
                                      ),
                                    ),
                                  ],
                                  if (actionLink.toString().trim().isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap: () async {
                                        final url =
                                            Uri.parse(actionLink.toString().trim());
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url,
                                              mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: scheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                              color:
                                                  scheme.primary.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.link_rounded,
                                                size: 16, color: scheme.primary),
                                            const SizedBox(width: 6),
                                            Text(
                                              'فتح الرابط المرفق',
                                              style: GoogleFonts.tajawal(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: scheme.primary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline_rounded,
                                          size: 14, color: scheme.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        'من: $sender',
                                        style: GoogleFonts.tajawal(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: scheme.onSurfaceVariant),
                                      ),
                                      const Spacer(),
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: cardAccentColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// التبويب الثاني: نتائج الاختبارات الشخصية
// ══════════════════════════════════════════════════════════════════
class _MyResultsTab extends StatelessWidget {
  const _MyResultsTab({
    required this.uid,
    required this.formatTimestamp,
  });

  final String uid;
  final String Function(dynamic) formatTimestamp;

  // تحويل اسم اللون من Firestore إلى Color
  static Color _parseColor(String? hex, ColorScheme scheme) {
    if (hex == null || hex.isEmpty) return scheme.primary;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return scheme.primary;
    }
  }

  // تحويل اسم الأيقونة من Firestore إلى IconData
  static IconData _parseIcon(String? name) {
    switch (name) {
      case 'star':       return Icons.star_rounded;
      case 'trophy':     return Icons.emoji_events_rounded;
      case 'target':     return Icons.gps_fixed_rounded;
      case 'trending_up':return Icons.trending_up_rounded;
      case 'bar_chart':  return Icons.bar_chart_rounded;
      case 'refresh':    return Icons.refresh_rounded;
      case 'check_circle':return Icons.check_circle_rounded;
      default:           return Icons.notifications_rounded;
    }
  }

  // شارة الـ trend
  static Widget _trendBadge(String? trend, ColorScheme scheme) {
    switch (trend) {
      case 'improved':
        return _badge('↑ تحسّن', const Color(0xFF10B981));
      case 'stable':
        return _badge('← ثبات', Colors.blueGrey);
      case 'declined':
        return _badge('↓ تراجع', Colors.deepOrange);
      case 'firstAttempt':
        return _badge('✦ أول محاولة', scheme.primary);
      default:
        return const SizedBox.shrink();
    }
  }

  static Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.tajawal(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (uid.isEmpty) {
      return Center(
        child: Text(
          'يجب تسجيل الدخول لعرض النتائج',
          style: GoogleFonts.tajawal(fontSize: 15, color: scheme.onSurfaceVariant),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(60)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'حدث خطأ في تحميل النتائج',
              style: GoogleFonts.tajawal(color: scheme.error),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.quiz_rounded, size: 64, color: scheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد نتائج بعد',
                    style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ستظهر هنا نتائج اختباراتك تلقائياً بعد إكمال أي اختبار.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                        fontSize: 14, color: scheme.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>? ?? {};
            final title = data['title'] as String? ?? 'نتيجة اختبار';
            final body = data['body'] as String? ?? '';
            final type = data['type'] as String? ?? 'quiz_result';
            final trend = data['trend'] as String?;
            final score = (data['score'] as num?)?.toDouble() ?? 0.0;
            final prevScore = (data['previousScore'] as num?)?.toDouble();
            final subject = data['subjectTitle'] as String? ?? '';
            final lessonOrUnit = data['lessonOrUnitTitle'] as String? ?? '';
            final iconName = data['iconName'] as String?;
            final colorHex = data['colorHex'] as String?;
            final timestamp = data['createdAt'];
            final isRead = data['isRead'] as bool? ?? false;

            final accent = _parseColor(colorHex, scheme);
            final icon = _parseIcon(iconName);
            final scorePct = (score * 100).round();
            final prevPct = prevScore != null ? (prevScore * 100).round() : null;
            final isUnitExam = type == 'unit_exam_result';

            return Card(
              elevation: 0,
              color: isRead
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                  : accent.withValues(alpha: 0.07),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isRead
                      ? Colors.transparent
                      : accent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── أيقونة النتيجة ──────────────────────────────
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: accent, size: 26),
                    ),
                    const SizedBox(width: 14),

                    // ── المحتوى ─────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الصف العلوي: نوع + trend + وقت
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isUnitExam ? 'اختبار وحدة' : 'اختبار درس',
                                  style: GoogleFonts.tajawal(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: accent),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _trendBadge(trend, scheme),
                              const Spacer(),
                              Text(
                                formatTimestamp(timestamp),
                                style: GoogleFonts.tajawal(
                                    fontSize: 11, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // العنوان
                          Text(
                            title,
                            style: GoogleFonts.tajawal(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                                height: 1.3),
                          ),
                          const SizedBox(height: 4),

                          // النص التحفيزي / التقديري
                          Text(
                            body,
                            style: GoogleFonts.tajawal(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                                height: 1.45),
                          ),
                          const SizedBox(height: 10),

                          // الصف السفلي: المادة + الدرجة
                          Row(
                            children: [
                              if (subject.isNotEmpty) ...[
                                Icon(Icons.book_rounded,
                                    size: 13, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  subject,
                                  style: GoogleFonts.tajawal(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (lessonOrUnit.isNotEmpty) ...[
                                  Text(' • ',
                                      style: TextStyle(
                                          color: scheme.onSurfaceVariant)),
                                  Flexible(
                                    child: Text(
                                      lessonOrUnit,
                                      style: GoogleFonts.tajawal(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                              const Spacer(),
                              // درجة الطالب
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$scorePct٪',
                                      style: GoogleFonts.tajawal(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: accent),
                                    ),
                                    if (prevPct != null) ...[
                                      Text(
                                        ' (سابقاً $prevPct٪)',
                                        style: GoogleFonts.tajawal(
                                            fontSize: 11,
                                            color: scheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
