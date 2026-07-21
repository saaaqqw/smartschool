import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';

import '../../services/firebase_service.dart';
import '../../services/firebase_sync_service.dart';
import '../../core/stores/user_profile_store.dart';
import '../shell/main_navigation_screen.dart';
import 'profile_editor_screen.dart';

/// المفتاح العالمي للتنقل واستدعاء الحوارات عند استلام رابط البريد
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// مكوّن يستمع لروابط التطبيق (App Links / Dynamic Links) الخاصة بالمصادقة عبر البريد
class EmailLinkListener extends StatefulWidget {
  const EmailLinkListener({super.key, required this.child});

  final Widget child;

  @override
  State<EmailLinkListener> createState() => _EmailLinkListenerState();
}

class _EmailLinkListenerState extends State<EmailLinkListener> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final _firebaseService = FirebaseService();
  bool _isProcessingLink = false;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initLinkListeners();
  }

  Future<void> _initLinkListeners() async {
    // 1. فحص الرابط الابتدائي إذا تم فتح التطبيق منه مباشرة
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleLink(initialUri.toString());
      }
    } catch (_) {}

    // 2. الاستماع لأي روابط تأتي والتطبيق مفتوح أو في الخلفية
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri.toString());
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleLink(String link) async {
    if (_isProcessingLink) return;
    if (!_firebaseService.isSignInWithEmailLink(link)) return;

    _isProcessingLink = true;

    try {
      String? email = await _firebaseService.getPendingEmailLink();

      // إذا فُتح الرابط من جهاز آخر ولم يتم العثور على البريد المحفوظ، اطلب إدخال البريد
      if (email == null || email.isEmpty) {
        if (!mounted) {
          _isProcessingLink = false;
          return;
        }
        email = await _promptForEmail();
        if (email == null || email.isEmpty) {
          _isProcessingLink = false;
          return;
        }
      }

      final context = appNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('جاري التحقق من رابط الدخول السريع...', style: GoogleFonts.tajawal()),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final creds = await _firebaseService.signInWithEmailLink(email: email, emailLink: link);
      final uid = creds.user?.uid ?? '';

      // جلب الملف الشخصي من Firestore
      final model = await _firebaseService.getUserProfile(uid);

      // إذا كان المستخدم مسجلاً مسبقاً وملفه مكتمل، توجه للشاشة الرئيسية
      if (model != null && model.fullName.isNotEmpty && model.school.isNotEmpty) {
        final profile = UserProfile.fromUserModel(model).copyWith(email: email);
        await saveUserProfile(profile);

        FirebaseSyncService.initializeAllSubjects().ignore();
        FirebaseSyncService.initializeUserProgress(uid).ignore();

        appNavigatorKey.currentState?.pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      } else {
        // مستخدم جديد (أو بياناته غير مكتملة) -> توجه لصفحة إكمال بيانات الطالب مع البريد المؤكد
        appNavigatorKey.currentState?.pushAndRemoveUntil<void>(
          ProfileEditorScreen.route(isOnboarding: true),
          (route) => false,
        );
      }
    } catch (e) {
      final context = appNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الدخول عبر الرابط: $e', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      _isProcessingLink = false;
    }
  }

  Future<String?> _promptForEmail() async {
    final context = appNavigatorKey.currentContext;
    if (context == null) return null;

    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text('تأكيد البريد الإلكتروني', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'يرجى كتابة بريدك الإلكتروني الذي أرسلنا عليه رابط التحقق لإتمام المصادقة بنجاح:',
                style: GoogleFonts.tajawal(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: GoogleFonts.tajawal(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text('إلغاء', style: GoogleFonts.tajawal()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text('تأكيد ومتابعة', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
