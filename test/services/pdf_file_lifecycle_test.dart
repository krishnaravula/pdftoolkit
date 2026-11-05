import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/services/pdf/pdf_service.dart';
import 'package:pdfrx/pdfrx.dart';

import '../helpers/pdf_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pageCount releases its input before returning', () async {
    final directory = await Directory.systemTemp.createTemp('pdf_lifecycle_');
    addTearDown(() => directory.delete(recursive: true));
    Pdfrx.cacheDirectoryPath ??= directory.path;

    final path = await PdfTestFixtures(
      directory,
    ).letterTextDocument(pageCount: 1);
    expect(await PdfService().pageCount(path), 1);
    File(path).deleteSync();
  });
}
