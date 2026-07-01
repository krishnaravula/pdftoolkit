import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_toolkit/core/config/env.dart';
import 'package:pdf_toolkit/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows home', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text(Env.appName), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('can open split screen from home tool', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.text('Split PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Split PDF'), findsWidgets);
    expect(
      find.text('Select a PDF to split into smaller files.'),
      findsOneWidget,
    );
  });
}
