import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:pdf_toolkit/core/errors/app_exception.dart';
import 'package:pdf_toolkit/domain/entities/pdf_job.dart';
import 'package:pdf_toolkit/services/pdf/pdf_service.dart';

import '../helpers/pdf_test_fixtures.dart';

void main() {
  late Directory workDirectory;
  late PdfTestFixtures fixtures;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Pdfrx.cacheDirectoryPath ??= Directory.systemTemp
        .createTempSync('pdfrx_split_cache')
        .path;
    await pdfrxFlutterInitialize();
  });

  setUp(() {
    workDirectory = Directory.systemTemp.createTempSync('split_test');
    fixtures = PdfTestFixtures(workDirectory);
  });

  tearDown(() {
    if (workDirectory.existsSync()) workDirectory.deleteSync(recursive: true);
  });

  test('splits lazily into the requested page groups', () async {
    final source = await fixtures.letterTextDocument(pageCount: 5);
    final outputDir = Directory(
      '${workDirectory.path}${Platform.pathSeparator}out',
    )..createSync();

    final outputs = await PdfService().splitPdf(
      source,
      mode: SplitMode.everyNPages,
      pagesPerFile: 2,
      outputDirectory: outputDir.path,
    );

    expect(outputs, hasLength(3));
    final pageCounts = <int>[];
    for (final output in outputs) {
      final doc = await PdfDocument.openFile(output);
      pageCounts.add(doc.pages.length);
      await doc.dispose();
    }
    expect(pageCounts, [2, 2, 1]);
  });

  test('removes already-created outputs after cancellation', () async {
    final source = await fixtures.letterTextDocument(pageCount: 3);
    final outputDir = Directory(
      '${workDirectory.path}${Platform.pathSeparator}out',
    )..createSync();
    final token = PdfCancellationToken();

    await expectLater(
      () => PdfService().splitPdf(
        source,
        mode: SplitMode.singlePages,
        outputDirectory: outputDir.path,
        cancellationToken: token,
        onProgress: (current, total, message) {
          if (current == 1) token.cancel();
        },
      ),
      throwsA(isA<PdfOperationCancelledException>()),
    );

    expect(outputDir.listSync(), isEmpty);
  });
}
