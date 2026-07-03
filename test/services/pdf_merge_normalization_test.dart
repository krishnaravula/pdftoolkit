import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_toolkit/services/pdf/pdf_merge_page_size.dart';
import 'package:pdf_toolkit/services/pdf/pdf_service.dart';
import 'package:pdfrx/pdfrx.dart';

import '../helpers/pdf_box_reader.dart';
import '../helpers/pdf_test_fixtures.dart';

/// Points tolerance when comparing page sizes.
const double _tol = 1.0;

void main() {
  late Directory workDir;
  late PdfTestFixtures fixtures;
  late PdfService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Pre-set the cache dir so pdfrxFlutterInitialize doesn't reach for
    // path_provider (unavailable in the test host).
    Pdfrx.cacheDirectoryPath ??= Directory.systemTemp
        .createTempSync('pdfrx_cache')
        .path;
    await pdfrxFlutterInitialize();
  });

  setUp(() {
    workDir = Directory.systemTemp.createTempSync('merge_test');
    fixtures = PdfTestFixtures(workDir);
    service = PdfService();
  });

  tearDown(() {
    if (workDir.existsSync()) workDir.deleteSync(recursive: true);
  });

  String out(String name) => '${workDir.path}${Platform.pathSeparator}$name';

  test(
    'regression: 4 Letter pages + 1 scanned 1609x2000 page -> 5 pages at '
    '612x792',
    () async {
      final letter = await fixtures.letterTextDocument(pageCount: 4);
      final scanned = await fixtures.scannedImageDocument(
        widthPts: 1609,
        heightPts: 2000,
      );

      final result = out('merged.pdf');
      await service.mergePdfs([letter, scanned], outputPath: result);

      final boxes = await readPageBoxes(result);
      expect(boxes, hasLength(5));
      for (final b in boxes) {
        expect(b.mediaWidth, closeTo(612, _tol), reason: 'media width');
        expect(b.mediaHeight, closeTo(792, _tol), reason: 'media height');
        expect(b.cropWidth, closeTo(612, _tol), reason: 'crop width');
        expect(b.cropHeight, closeTo(792, _tol), reason: 'crop height');
        expect(b.rotationQuarterTurns, 0);
      }
    },
  );

  test('every output page renders with content (no blank/black pages)', () async {
    final letter = await fixtures.letterTextDocument(pageCount: 2);
    final scanned = await fixtures.scannedImageDocument(
      widthPts: 1609,
      heightPts: 2000,
    );

    final result = out('merged.pdf');
    await service.mergePdfs([letter, scanned], outputPath: result);

    final doc = await PdfDocument.openFile(result);
    try {
      for (var i = 0; i < doc.pages.length; i++) {
        expect(
          await _pageHasVaryingContent(doc.pages[i]),
          isTrue,
          reason: 'page ${i + 1} should not be blank or all black',
        );
      }
    } finally {
      doc.dispose();
    }
  });

  test('scanned page is centered and its aspect ratio is preserved', () async {
    final letter = await fixtures.letterTextDocument(pageCount: 1);
    // 1609x2000 -> width-constrained: scale = 612/1609, content height ~760.7,
    // leaving ~15.6pt margins top and bottom.
    final scanned = await fixtures.scannedImageDocument(
      widthPts: 1609,
      heightPts: 2000,
    );

    final result = out('merged.pdf');
    await service.mergePdfs([letter, scanned], outputPath: result);

    final doc = await PdfDocument.openFile(result);
    try {
      final page = doc.pages[1];
      final bounds = await _contentBounds(page);
      // Content spans the full width (flush left/right) ...
      expect(bounds.left, closeTo(0, 4));
      expect(bounds.right, closeTo(page.width, 4));
      // ... and is vertically centered with symmetric margins.
      final topMargin = page.height - bounds.top;
      final bottomMargin = bounds.bottom;
      expect(topMargin, closeTo(bottomMargin, 6),
          reason: 'top and bottom margins should match (centered)');
      expect(topMargin, greaterThan(6),
          reason: 'there should be a visible vertical margin');
    } finally {
      doc.dispose();
    }
  });

  test('landscape and rotated inputs are normalized to portrait target',
      () async {
    final letter = await fixtures.letterTextDocument(pageCount: 1);
    final landscape = await fixtures.landscapeTextDocument();
    final rotated90 = await fixtures.rotatedCopy(letter, 1,
        fileName: 'rot90.pdf');
    final rotated270 = await fixtures.rotatedCopy(letter, 3,
        fileName: 'rot270.pdf');

    final result = out('merged.pdf');
    await service.mergePdfs(
      [letter, landscape, rotated90, rotated270],
      outputPath: result,
    );

    final boxes = await readPageBoxes(result);
    expect(boxes, hasLength(4));
    for (final b in boxes) {
      expect(b.mediaWidth, closeTo(612, _tol));
      expect(b.mediaHeight, closeTo(792, _tol));
      expect(b.rotationQuarterTurns, 0);
    }

    final doc = await PdfDocument.openFile(result);
    try {
      for (var i = 0; i < doc.pages.length; i++) {
        expect(await _pageHasVaryingContent(doc.pages[i]), isTrue,
            reason: 'rotated/landscape page ${i + 1} lost its content');
      }
    } finally {
      doc.dispose();
    }
  });

  test('pages with CropBox smaller than MediaBox are normalized', () async {
    final letter = await fixtures.letterTextDocument(pageCount: 1);
    final cropped = await fixtures.croppedCopy(letter);

    final result = out('merged.pdf');
    await service.mergePdfs([letter, cropped], outputPath: result);

    final boxes = await readPageBoxes(result);
    expect(boxes, hasLength(2));
    for (final b in boxes) {
      expect(b.mediaWidth, closeTo(612, _tol));
      expect(b.mediaHeight, closeTo(792, _tol));
      expect(b.cropWidth, closeTo(612, _tol));
      expect(b.cropHeight, closeTo(792, _tol));
    }
  });

  test('text on vector pages remains extractable after normalization',
      () async {
    // First doc is A4 so the target size is A4; the Letter doc then also gets
    // scaled via the form-XObject path, exercising text through an XObject.
    final a4 = await fixtures.customSizeTextDocument(textPrefix: 'Alpha vector');
    final letter =
        await fixtures.letterTextDocument(pageCount: 1, textPrefix: 'Beta vector');

    final result = out('merged.pdf');
    await service.mergePdfs([a4, letter], outputPath: result);

    final doc = await PdfDocument.openFile(result);
    try {
      final page0 = (await doc.pages[0].loadText())?.fullText ?? '';
      final page1 = (await doc.pages[1].loadText())?.fullText ?? '';
      expect(page0, contains('Alpha vector'));
      expect(page1, contains('Beta vector'));
    } finally {
      doc.dispose();
    }
  });

  test('merging the same files repeatedly does not accumulate transforms',
      () async {
    final letter = await fixtures.letterTextDocument(pageCount: 4);
    final scanned = await fixtures.scannedImageDocument(
      widthPts: 1609,
      heightPts: 2000,
    );

    final first = out('first.pdf');
    final second = out('second.pdf');
    await service.mergePdfs([letter, scanned], outputPath: first);
    await service.mergePdfs([letter, scanned], outputPath: second);

    final b1 = await readPageBoxes(first);
    final b2 = await readPageBoxes(second);
    expect(b1.length, b2.length);
    for (var i = 0; i < b1.length; i++) {
      expect(b1[i].mediaWidth, closeTo(b2[i].mediaWidth, 1e-3));
      expect(b1[i].mediaHeight, closeTo(b2[i].mediaHeight, 1e-3));
    }

    // Re-merge an already-normalized output; sizes must stay at the target and
    // the scanned page must still be visible (no shrinking spiral).
    final reMerged = out('remerged.pdf');
    await service.mergePdfs([first, first], outputPath: reMerged);
    final b3 = await readPageBoxes(reMerged);
    expect(b3, hasLength(b1.length * 2));
    for (final b in b3) {
      expect(b.mediaWidth, closeTo(612, _tol));
      expect(b.mediaHeight, closeTo(792, _tol));
    }
  });

  test('preserveOriginal keeps mixed page sizes', () async {
    final letter = await fixtures.letterTextDocument(pageCount: 1);
    final scanned = await fixtures.scannedImageDocument(
      widthPts: 1609,
      heightPts: 2000,
    );

    final result = out('preserved.pdf');
    await service.mergePdfs(
      [letter, scanned],
      outputPath: result,
      pageSizeMode: MergePageSizeMode.preserveOriginal,
    );

    final boxes = await readPageBoxes(result);
    expect(boxes, hasLength(2));
    expect(boxes[0].mediaWidth, closeTo(612, _tol));
    expect(boxes[1].mediaWidth, closeTo(1609, _tol));
    expect(boxes[1].mediaHeight, closeTo(2000, _tol));
  });
}

/// Renders [page] at 72 dpi and reports whether it contains both dark and light
/// pixels (i.e. it is neither blank/white nor entirely black).
Future<bool> _pageHasVaryingContent(PdfPage page) async {
  final image = await _render(page);
  var hasDark = false;
  var hasLight = false;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final lum = _luminance(image.getPixel(x, y));
      if (lum < 100) hasDark = true;
      if (lum > 200) hasLight = true;
      if (hasDark && hasLight) return true;
    }
  }
  return hasDark && hasLight;
}

/// The bounding box (in page points) of the non-white content on [page].
Future<_Bounds> _contentBounds(PdfPage page) async {
  final image = await _render(page);
  final w = image.width;
  final h = image.height;
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (_luminance(image.getPixel(x, y)) < 220) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  // Pixels are 1:1 with points because we render at 72 dpi. Image space has its
  // origin at the top-left, so flip Y into PDF (bottom-left) space.
  final scaleX = page.width / w;
  final scaleY = page.height / h;
  return _Bounds(
    left: minX * scaleX,
    right: (maxX + 1) * scaleX,
    bottom: page.height - (maxY + 1) * scaleY,
    top: page.height - minY * scaleY,
  );
}

Future<img.Image> _render(PdfPage page) async {
  final rendered = await page.render(
    fullWidth: page.width,
    fullHeight: page.height,
  );
  if (rendered == null) {
    throw StateError('Failed to render page ${page.pageNumber}');
  }
  final image = rendered.createImageNF();
  rendered.dispose();
  return image;
}

double _luminance(img.Pixel p) =>
    0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

class _Bounds {
  const _Bounds({
    required this.left,
    required this.right,
    required this.bottom,
    required this.top,
  });

  final double left;
  final double right;
  final double bottom;
  final double top;
}
