import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/features/split/split_screen.dart';

void main() {
  testWidgets('Split screen shows empty state before selecting PDF', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SplitScreen())),
    );

    expect(find.text('Split PDF'), findsWidgets);
    expect(find.text('Select PDF'), findsOneWidget);
    expect(
      find.text('Select a PDF to split into smaller files.'),
      findsOneWidget,
    );
  });
}
