import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import 'package:pdf_toolkit/domain/entities/pdf_stamp_placement.dart';
import 'package:pdf_toolkit/services/pdf/pdf_service.dart';

import '../helpers/pdf_test_fixtures.dart';

void main() {
  late Directory workDirectory;
  late PdfTestFixtures fixtures;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Pdfrx.cacheDirectoryPath ??= Directory.systemTemp
        .createTempSync('pdfrx_signing_cache')
        .path;
    await pdfrxFlutterInitialize();
  });

  setUp(() {
    workDirectory = Directory.systemTemp.createTempSync('esign_test');
    fixtures = PdfTestFixtures(workDirectory);
  });

  tearDown(() {
    if (workDirectory.existsSync()) workDirectory.deleteSync(recursive: true);
  });

  test(
    'stamps preserve source text and leave the original unchanged',
    () async {
      final source = await fixtures.letterTextDocument(
        textPrefix: 'Unsigned content',
      );
      final output = '${workDirectory.path}${Platform.pathSeparator}signed.pdf';
      final png = _redStamp();

      await PdfService().applyVisualStamps(
        inputPath: source,
        outputPath: output,
        placements: [
          PdfStampPlacement(
            pageNumber: 1,
            left: 0.1,
            top: 0.1,
            width: 0.3,
            height: 0.1,
            pngBytes: png,
          ),
          PdfStampPlacement(
            pageNumber: 1,
            left: 0.62,
            top: 0.76,
            width: 0.22,
            height: 0.1,
            pngBytes: png,
          ),
        ],
      );

      final sourceDoc = await PdfDocument.openFile(source);
      final signedDoc = await PdfDocument.openFile(output);
      try {
        final sourceText = (await sourceDoc.pages.first.loadText())!.fullText;
        final signedText = (await signedDoc.pages.first.loadText())!.fullText;
        expect(signedDoc.pages, hasLength(sourceDoc.pages.length));
        expect(signedText, sourceText);
        expect(sourceText, contains('Unsigned content 1'));
        expect(await PdfService().digitalSignatureCount(source), 0);
        expect(await PdfService().digitalSignatureCount(output), 0);

        final originalImage = await _render(sourceDoc.pages.first);
        final signedImage = await _render(signedDoc.pages.first);
        expect(_isRed(signedImage.getPixel(150, 120)), isTrue);
        expect(_isRed(signedImage.getPixel(450, 640)), isTrue);
        expect(_isRed(originalImage.getPixel(150, 120)), isFalse);
      } finally {
        await signedDoc.dispose();
        await sourceDoc.dispose();
      }
    },
  );

  test('stamps display on rotated and cropped pages', () async {
    final source = await fixtures.letterTextDocument(
      pageCount: 1,
      textPrefix: 'Geometry content',
    );
    final rotated = await fixtures.rotatedCopy(source, 1);
    final cropped = await fixtures.croppedCopy(source);
    final paths = [rotated, cropped];

    for (var i = 0; i < paths.length; i++) {
      final output =
          '${workDirectory.path}${Platform.pathSeparator}geometry_$i.pdf';
      await PdfService().applyVisualStamps(
        inputPath: paths[i],
        outputPath: output,
        placements: [
          PdfStampPlacement(
            pageNumber: 1,
            left: 0.12,
            top: 0.14,
            width: 0.24,
            height: 0.12,
            pngBytes: _redStamp(),
          ),
        ],
      );

      final doc = await PdfDocument.openFile(output);
      try {
        final page = doc.pages.single;
        final image = await _render(page);
        final x = (page.width * 0.24).round();
        final y = (page.height * 0.2).round();
        expect(_isRed(image.getPixel(x, y)), isTrue);
        expect(
          (await page.loadText())!.fullText,
          contains('Geometry content 1'),
        );
      } finally {
        await doc.dispose();
      }
    }
  });
}

Uint8List _redStamp() {
  final image = img.Image(width: 100, height: 40);
  img.fill(image, color: img.ColorRgba8(210, 20, 30, 255));
  return Uint8List.fromList(img.encodePng(image));
}

Future<img.Image> _render(PdfPage page) async {
  final rendered = await page.render(
    fullWidth: page.width,
    fullHeight: page.height,
  );
  if (rendered == null) throw StateError('Could not render PDF page.');
  final image = rendered.createImageNF();
  rendered.dispose();
  return image;
}

bool _isRed(img.Pixel pixel) => pixel.r > 150 && pixel.r > pixel.g * 2;
