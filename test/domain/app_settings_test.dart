import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/domain/entities/app_settings.dart';

void main() {
  test('new installs default processed files to Documents/PDF Tools', () {
    expect(
      DefaultSaveLocation.fromKey(null),
      DefaultSaveLocation.documentsPdfTools,
    );
  });

  test('stored save-location values remain compatible', () {
    for (final value in DefaultSaveLocation.values) {
      expect(DefaultSaveLocation.fromKey(value.name), value);
    }
  });
}
