import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_school/screens/auth/welcome_screen.dart';

void main() {
  testWidgets('Welcome screen smoke test', (WidgetTester tester) async {
    // Build our welcome screen wrapped in MaterialApp to avoid Firebase dependency errors in tests.
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar', 'SA'),
        home: WelcomeScreen(),
      ),
    );

    // Verify that the welcome screen shows the app title.
    expect(find.text('المدرسة الذكية'), findsOneWidget);

    // Verify that the instructions to tap anywhere are displayed.
    expect(find.text('اضغط في أي مكان للبدء'), findsOneWidget);

    // Verify that the old separate buttons are removed.
    expect(find.text('تسجيل الدخول'), findsNothing);
    expect(find.text('إنشاء حساب جديد'), findsNothing);
  });
}
