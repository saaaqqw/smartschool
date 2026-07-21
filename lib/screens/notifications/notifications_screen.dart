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

class _NotificationsScreenState extends State<NotificationsScreen> {
  Set<String> _readIds = {};
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadReadNotifications();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الإشعارات والتنبيهات',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
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
          // تصفية الإشعارات لتشمل التنبيهات الموجهة لـ (الكل) أو للصف الحالي للطالب
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ستظهر هنا جميع إعلانات المدرسة وتنبيهات المعلمين الخاصة بصفك الدراسي.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final unreadCount = docs.where((d) => !_readIds.contains(d.id)).length;

          return Column(
            children: [
              if (!_notificationsEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.amber.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_off_rounded, size: 22, color: Colors.amber.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تنبيه: الإشعارات الفورية معطلة من إعدادات التطبيق. لن تظهر التنبيهات الجديدة في شريط الرئيسية.',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
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
                          'لديك ($unreadCount) إشعار جديد لم يتم قراءته',
                          style: GoogleFonts.tajawal(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _markAllAsRead(docs),
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: Text('قراءة الكل', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 12)),
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
                    final isRead = _readIds.contains(doc.id);

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
                          if (!isRead) _markSingleAsRead(doc.id);
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
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: cardAccentColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            typeLabel,
                                            style: GoogleFonts.tajawal(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: cardAccentColor,
                                            ),
                                          ),
                                        ),
                                        if (target != 'الكل' && target != 'جميع الطلاب') ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: scheme.secondary.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              target.toString(),
                                              style: GoogleFonts.tajawal(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: scheme.secondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: GoogleFonts.tajawal(
                                            fontSize: 11.5,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      title.toString(),
                                      style: GoogleFonts.tajawal(
                                        fontSize: 16,
                                        fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                        color: scheme.onSurface,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (body.toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        body.toString(),
                                        style: GoogleFonts.tajawal(
                                          fontSize: 13.5,
                                          color: scheme.onSurfaceVariant,
                                          height: 1.45,
                                        ),
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
                                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                        ),
                                      ),
                                    ],
                                    if (actionLink.toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () async {
                                          final url = Uri.parse(actionLink.toString().trim());
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url, mode: LaunchMode.externalApplication);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: scheme.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.link_rounded, size: 16, color: scheme.primary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'فتح الرابط المرفق',
                                                style: GoogleFonts.tajawal(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: scheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline_rounded, size: 14, color: scheme.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Text(
                                          'من: $sender',
                                          style: GoogleFonts.tajawal(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: scheme.onSurfaceVariant,
                                          ),
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
      ),
    );
  }
}
