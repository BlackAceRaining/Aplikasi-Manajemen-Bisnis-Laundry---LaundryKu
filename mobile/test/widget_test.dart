import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/main.dart';
import 'package:mobile/features/auth/login_screen.dart';

void main() {
  testWidgets('App boots to login screen when not authenticated',
      (WidgetTester tester) async {
    // No stored token -> AuthGate must show the LoginScreen.
    // AuthGate is pumped without AppTheme so google_fonts network loading
    // is not triggered inside the test environment.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthGate()),
      ),
    );
    // checkAuth() hits real platform channels, so settle it with runAsync.
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Masuk'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
