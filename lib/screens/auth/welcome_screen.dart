import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';

/// شاشة الترحيب — نقطة الدخول قبل التسجيل.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _pulseAnimation;
  late final String _motivationalMessage;

  // قائمة بالرسائل الترحيبية والتحفيزية
  static const List<String> _quotes = [
    'العلم نور، وطريقك نحو التميز الدراسي يبدأ بخطوة اليوم!',
    'كل يوم هو فرصة جديدة لتتعلم شيئاً رائعاً وتتقدم خطوة نحو حلمك.',
    'النجاح هو مجموع جهود صغيرة تتكرر يوماً بعد يوم. ابدأ رحلتك الآن!',
    'استثمر في عقلك اليوم لتصنع مستقبلاً باهراً تفتخر به.',
    'أنت قادر على تحقيق أهدافك، دعنا ننظم دراستك ونصل للقمة معاً!',
    'التعليم هو السلاح الأقوى الذي يمكنك استخدامه لتغيير مستقبلك.',
  ];

  @override
  void initState() {
    super.initState();
    // اختيار رسالة عشوائية عند فتح التطبيق
    final random = Random();
    _motivationalMessage = _quotes[random.nextInt(_quotes.length)];

    // إعداد حركة الوميض/النبض للنص السفلي
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(LoginScreen.route());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToLogin,
        child: Stack(
          children: [
            // خلفية متدرجة جذابة وفاخرة
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          scheme.surfaceContainerLowest,
                          scheme.primaryContainer.withValues(alpha: 0.15),
                          scheme.surfaceContainerHigh,
                        ]
                      : [
                          scheme.primary.withValues(alpha: 0.08),
                          scheme.surface,
                          scheme.primaryContainer.withValues(alpha: 0.12),
                        ],
                ),
              ),
            ),
            
            // دوائر جمالية ناعمة في الخلفية لمظهر احترافي
            Positioned(
              top: -size.height * 0.1,
              right: -size.width * 0.2,
              child: Container(
                width: size.width * 0.6,
                height: size.width * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.15,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.secondary.withValues(alpha: 0.05),
                ),
              ),
            ),

            // محتوى الشاشة
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    
                    // شعار التطبيق مع خلفية مضيئة ناعمة
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        size: 96,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // اسم التطبيق
                    Text(
                      'المدرسة الذكية',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // خط ديكوري ناعم
                    Container(
                      width: 60,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    const Spacer(flex: 2),
                    
                    // بطاقة الرسالة التحفيزية (مظهر زجاجي ناعم)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            color: scheme.primary.withValues(alpha: 0.4),
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _motivationalMessage,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1.6,
                              color: scheme.onSurface.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(flex: 4),
                    
                    // نص تفاعلي نابض في الأسفل للتوجيه
                    FadeTransition(
                      opacity: _pulseAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'اضغط في أي مكان للبدء',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            Icons.keyboard_double_arrow_down_rounded,
                            color: scheme.primary,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
