import 'package:flutter_test/flutter_test.dart';
import 'package:smart_school/main.dart';

void main() {
  testWidgets('Welcome screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartSchoolApp());

    // Verify that the welcome screen shows the app title.
    expect(find.text('المدرسة الذكية'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
  });
}
