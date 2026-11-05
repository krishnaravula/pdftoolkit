import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/domain/entities/pdf_page_operation.dart';
import 'package:pdf_toolkit/services/pdf/pdf_service.dart';
import 'package:pdfrx/pdfrx.dart';

import '../helpers/pdf_box_reader.dart';
import '../helpers/pdf_test_fixtures.dart';

void main() {
  late Directory workDirectory;
  late PdfTestFixtures fixtures;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Pdfrx.cacheDirectoryPath ??= Directory.systemTemp
        .createTempSync('pdfrx_organizer_cache')
        .path;
    await pdfrxFlutterInitialize();
  });

  setUp(() {
    workDirectory = Directory.systemTemp.createTempSync('organizer_test');
    fixtures = PdfTestFixtures(workDirectory);
  });

  tearDown(() {
    if (workDirectory.existsSync()) {
      workDirectory.deleteSync(recursive: true);
    }
  });

  test('organizer combines, reorders, rotates, and duplicates pages', () async {
    final first = await fixtures.letterTextDocument(
      pageCount: 2,
      textPrefix: 'First document',
      fileName: 'first.pdf',
    );
    final second = await fixtures.letterTextDocument(
      pageCount: 1,
      textPrefix: 'Second document',
      fileName: 'second.pdf',
    );
    final output =
        '${workDirectory.path}${Platform.pathSeparator}organized.pdf';

    await PdfService().organizePages(
      operations: [
        PdfPageOperation(
          sourcePath: second,
          pageNumber: 1,
          clockwiseQuarterTurns: 1,
        ),
        PdfPageOperation(sourcePath: first, pageNumber: 2),
        PdfPageOperation(sourcePath: first, pageNumber: 1),
        PdfPageOperation(sourcePath: first, pageNumber: 1),
      ],
      outputPath: output,
    );

    final boxes = await readPageBoxes(output);
    expect(boxes, hasLength(4));
    expect(boxes.first.rotationQuarterTurns, 1);

    final document = await PdfDocument.openFile(output);
    try {
      final text = <String>[];
      for (final page in document.pages) {
        text.add((await page.loadText())?.fullText ?? '');
      }
      expect(text[0], contains('Second document 1'));
      expect(text[1], contains('First document 2'));
      expect(text[2], contains('First document 1'));
      expect(text[3], contains('First document 1'));
    } finally {
      await document.dispose();
    }
  });
}
