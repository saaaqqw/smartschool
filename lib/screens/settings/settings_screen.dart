import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/locale/locale_notifier.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/stores/user_profile_store.dart';
import '../../services/firebase_service.dart';
import '../auth/register_screen.dart';
import '../auth/welcome_screen.dart';
import '../../core/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _kSettingsCardRadius = 20;

/// إعدادات المدرسة الذكية — واجهة عربية كاملة (RTL) وبطاقات حديثة.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const SettingsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
    );
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(
          AppLocalizations.of(context).translate('settings'),
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _buildProfileHeader(context, scheme),
          const SizedBox(height: 28),
          _buildCategoryLabel(AppLocalizations.of(context).translate('account'), scheme),
          const SizedBox(height: 10),
          _SettingsCard(
            scheme: scheme,
            child: Column(
              children: [
                _ChevronTile(
                  icon: Icons.shield_outlined,
                  label: 'الحماية',
                  onTap: () => _showM3InfoDialog(
                    context,
                    icon: Icons.shield_outlined,
                    title: 'إعدادات الأمان',
                    body:
                        'نلتزم بحماية حسابك وبياناتك الشخصية داخل تطبيق المدرسة الذكية. '
                        'لا تشارك بيانات الدخول مع أي شخص، ويُنصح باستخدام كلمة مرور قوية '
                        'وتغييرها عند الشك بأي نشاط غير معتاد على حسابك.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildCategoryLabel('تفضيلات التطبيق', scheme),
          const SizedBox(height: 10),
          _SettingsCard(
            scheme: scheme,
            child: Column(
              children: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: appThemeModeNotifier,
                  builder: (context, mode, _) {
                    final dark = mode == ThemeMode.dark;
                    return _SwitchTile(
                      icon: Icons.dark_mode_outlined,
                      label: AppLocalizations.of(context).translate('dark_mode'),
                      value: dark,
                      onChanged: (v) {
                        appThemeModeNotifier.value =
                            v ? ThemeMode.dark : ThemeMode.light;
                      },
                    );
                  },
                ),
                _divider(scheme),
                _SwitchTile(
                  icon: Icons.notifications_outlined,
                  label: 'الإشعارات',
                  value: _notificationsEnabled,
                  onChanged: (v) {
                    _toggleNotifications(v);
                    _toast(context, 'تم تحديث إعدادات الإشعارات');
                  },
                ),
                _divider(scheme),
                _LanguageTile(
                  scheme: scheme,
                  onTap: () => _showLanguageSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildCategoryLabel(AppLocalizations.of(context).translate('support'), scheme),
          const SizedBox(height: 10),
          _SettingsCard(
            scheme: scheme,
            child: Column(
              children: [
                _ChevronTile(
                  icon: Icons.help_outline,
                  label: AppLocalizations.of(context).translate('help_center'),
                  onTap: () => _showM3InfoDialog(
                    context,
                    icon: Icons.help_outline,
                    title: 'مركز المساعدة',
                    body:
                        'أهلاً بك في مركز مساعدة Smart School. يمكنك التواصل معنا عبر البريد الإلكتروني للدعم الفني.',
                  ),
                ),
                _divider(scheme),
                _ChevronTile(
                  icon: Icons.description_outlined,
                  label: AppLocalizations.of(context).translate('terms_of_service'),
                  onTap: () => _showM3InfoDialog(
                    context,
                    icon: Icons.description_outlined,
                    title: 'شروط الخدمة',
                    body:
                        'باستخدامك لتطبيق Smart School، فإنك توافق على سياسة الاستخدام العادل وحماية خصوصية البيانات.',
                  ),
                ),
                _divider(scheme),
                _ChevronTile(
                  icon: Icons.group_outlined,
                  label: AppLocalizations.of(context).translate('team'),
                  onTap: () => _showM3InfoDialog(
                    context,
                    icon: Icons.group_outlined,
                    title: 'فريق العمل',
                    body:
                        'تم تطوير هذا التطبيق بواسطة المهندس محمد سعيد (طالب علوم حاسوب - مستوى رابع) لخدمة طلاب المرحلة المتوسطة.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout_rounded, size: 22),
            label: Text(
              AppLocalizations.of(context).translate('logout'),
              style: GoogleFonts.tajawal(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              elevation: 2,
              shadowColor: scheme.shadow.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              AppLocalizations.of(context).translate('version'),
              style: GoogleFonts.tajawal(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: scheme.onSurfaceVariant.withValues(
                  alpha: isDark ? 0.85 : 0.75,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, ColorScheme scheme) {
    final profile = userProfileNotifier.value;
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: scheme.primaryContainer,
                backgroundImage: profile.profileImageUrl.isNotEmpty
                    ? CachedNetworkImageProvider(profile.profileImageUrl)
                    : null,
                child: profile.profileImageUrl.isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        size: 56,
                        color: scheme.onPrimaryContainer,
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: scheme.primary,
                  elevation: 3,
                  shadowColor: scheme.shadow.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      RegisterScreen.route(isEditMode: true),
                    ),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: 18,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ValueListenableBuilder<UserProfile>(
          valueListenable: userProfileNotifier,
          builder: (context, profile, _) {
            return Column(
              children: [
                Text(
                  profile.fullName.trim().isEmpty
                      ? 'طالب'
                      : profile.fullName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'طالب علوم حاسوب',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryLabel(String text, ColorScheme scheme) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Text(
          text,
          style: GoogleFonts.tajawal(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  static Widget _divider(ColorScheme scheme) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 56,
      color: scheme.outlineVariant.withValues(alpha: 0.45),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.tajawal()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// حوار Material 3 موحّد لعناصر الدعم والحماية.
  void _showM3InfoDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    final scheme = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: scheme.surfaceContainerHigh,
            surfaceTintColor: scheme.surfaceTint,
            elevation: 3,
            shadowColor: scheme.shadow.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            icon: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: scheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              title,
              textAlign: TextAlign.right,
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                height: 1.2,
                color: scheme.onSurface,
              ),
            ),
            content: SingleChildScrollView(
              child: Text(
                body,
                textAlign: TextAlign.right,
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageSheet(BuildContext parentContext) {
    final scheme = Theme.of(parentContext).colorScheme;
    showModalBottomSheet<void>(
      context: parentContext,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ValueListenableBuilder<Locale>(
          valueListenable: appLocaleNotifier,
          builder: (context, currentLocale, _) {
            final isArabic = currentLocale.languageCode == 'ar';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'تغيير اللغة / Change Language',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text(
                        'العربية',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isArabic ? const Icon(Icons.check_rounded) : null,
                      onTap: () async {
                        await updateLocale(const Locale('ar', 'SA'));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (parentContext.mounted) {
                          _toast(parentContext, 'تم اختيار العربية');
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        'English',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      trailing: !isArabic ? const Icon(Icons.check_rounded) : null,
                      onTap: () async {
                        await updateLocale(const Locale('en', 'US'));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (parentContext.mounted) {
                          _toast(parentContext, 'English selected');
                        }
                      },
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

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تسجيل الخروج',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'هل تريد المغادرة؟',
          style: GoogleFonts.tajawal(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.tajawal()),
          ),
          FilledButton(
            onPressed: () async {
              await FirebaseService().signOut();
              await clearUserProfile();
              if (ctx.mounted) {
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            child: Text('تأكيد', style: GoogleFonts.tajawal()),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.scheme,
    required this.child,
  });

  final ColorScheme scheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: isDark ? 2 : 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      surfaceTintColor: scheme.surfaceTint.withValues(alpha: isDark ? 0.18 : 0.08),
      borderRadius: BorderRadius.circular(_kSettingsCardRadius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kSettingsCardRadius),
        child: child,
      ),
    );
  }
}

/// في RTL يظهر الرمز على يمين السطر (البداية المنطقية) والنص يليه.
class _ChevronTile extends StatelessWidget {
  const _ChevronTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      horizontalTitleGap: 12,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
      ),
      title: Text(
        label,
        textAlign: TextAlign.right,
        style: GoogleFonts.tajawal(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.chevron_left_rounded,
        color: scheme.outline,
        size: 28,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      horizontalTitleGap: 8,
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
      ),
      title: Text(
        label,
        textAlign: TextAlign.right,
        style: GoogleFonts.tajawal(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeTrackColor: scheme.primary.withValues(alpha: 0.45),
        activeThumbColor: scheme.onPrimary,
        onChanged: onChanged,
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.scheme,
    required this.onTap,
  });

  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      horizontalTitleGap: 12,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.language_rounded,
          color: scheme.onPrimaryContainer,
          size: 22,
        ),
      ),
      title: Text(
        AppLocalizations.of(context).translate('change_language'),
        textAlign: TextAlign.right,
        style: GoogleFonts.tajawal(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.chevron_left_rounded,
        color: scheme.outline,
        size: 28,
      ),
    );
  }
}
