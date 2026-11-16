import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_toolkit/core/config/env.dart';
import 'package:pdf_toolkit/core/widgets/app_widgets.dart';
import 'package:pdf_toolkit/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows home', (tester) async {
    await _launchApp(tester);

    expect(find.text(Env.appName), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('can open split screen from home tool', (tester) async {
    await _launchApp(tester);

    final splitTool = find.widgetWithText(ToolCard, 'Split PDF');
    await Scrollable.ensureVisible(tester.element(splitTool), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(splitTool.hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Split PDF'), findsWidgets);
    expect(
      find.text('Select a PDF to split into smaller files.'),
      findsOneWidget,
    );
  });
}

Future<void> _launchApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'onboarding_complete': true});
  final frameworkErrorHandler = FlutterError.onError;
  final dispatcher = PlatformDispatcher.instance;
  final platformErrorHandler = dispatcher.onError;
  try {
    await app.main();
  } finally {
    // App bootstrap installs handlers that would replace the test binding's.
    FlutterError.onError = frameworkErrorHandler;
    dispatcher.onError = platformErrorHandler;
  }
  await tester.pumpAndSettle();
}
