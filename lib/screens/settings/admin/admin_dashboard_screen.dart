import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/stores/user_profile_store.dart';
import '../../../core/config/developer_auth_service.dart';
import 'admin_management_screen.dart';
import 'admin_content_screen.dart';
import 'admin_settings_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = userProfileNotifier.value;
    
    // التحقق من الصلاحيات
    final isOwner = DeveloperAuthService.isSuperAdmin(profile.email);
    
    if (!isOwner) {
      // للمشرفين والمعلمين العاديين، الدخول المباشر لشاشة إدارة المحتوى
      return const AdminContentScreen();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لوحة تحكم الإدارة (المالك)',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: scheme.surface,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مرحباً بك يا ${profile.fullName.split(' ').first}!',
                style: GoogleFonts.tajawal(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اختر القسم الذي تريد إدارته اليوم:',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              
              _AdminCard(
                title: 'الإدارة والتواصل',
                subtitle: 'إدارة المشرفين وصلاحيات التطبيق',
                icon: Icons.admin_panel_settings_rounded,
                color: Colors.orange,
                onTap: () => Navigator.push(context, AdminManagementScreen.route()),
              ),
                
              _AdminCard(
                title: 'المحتوى التعليمي',
                subtitle: 'إضافة الدروس، ملخصات الفيديو، بنك الأسئلة',
                icon: Icons.play_lesson_rounded,
                color: Colors.blue,
                onTap: () => Navigator.push(context, AdminContentScreen.route()),
              ),
              
              _AdminCard(
                title: 'الإعدادات والإشعارات',
                subtitle: 'بث الإشعارات وإعدادات الذكاء الاصطناعي',
                icon: Icons.settings_suggest_rounded,
                color: Colors.purple,
                onTap: () => Navigator.push(context, AdminSettingsScreen.route()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).colorScheme.outlineVariant, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
