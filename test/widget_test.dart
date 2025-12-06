import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanchar_messaging_app/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders correctly', (WidgetTester tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(
      home: SplashScreen(),
    ));

    // Verify that Sanchar text is present.
    expect(find.text('Sanchar'), findsOneWidget);
    expect(find.text('Connecting You...'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);

    // Wait for the splash screen delay (3 seconds) + transition
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Verify that we navigated to OnboardingScreen
    expect(find.text('Connect Instantly'), findsOneWidget);
    expect(find.text('Sanchar'), findsNothing);
  });
}
