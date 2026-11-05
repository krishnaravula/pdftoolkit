import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/data/local/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('reading position defaults to first page and persists', () async {
    final preferences = AppPreferences(await SharedPreferences.getInstance());

    expect(preferences.readingPageFor('/documents/guide.pdf'), 1);

    await preferences.setReadingPage('/documents/guide.pdf', 17);

    expect(preferences.readingPageFor('/documents/guide.pdf'), 17);
  });

  test('invalid reading positions are ignored', () async {
    final preferences = AppPreferences(await SharedPreferences.getInstance());

    await preferences.setReadingPage('/documents/guide.pdf', 0);

    expect(preferences.readingPageFor('/documents/guide.pdf'), 1);
  });
}
