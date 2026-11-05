import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import 'pdf_box_reader.dart' as box;

/// Builds real PDF fixtures on disk for the merge normalization tests.
///
/// Vector/text pages are produced with the `pdf` package (built-in Helvetica so
/// the text is extractable). Image/scanned pages are produced with pdfrx's
/// `createFromJpegData`, letting us give a page an arbitrary point size that is
/// independent of the embedded image's pixel resolution.
class PdfTestFixtures {
  PdfTestFixtures(this.dir);

  final Directory dir;

  /// A multi-page US Letter document with extractable text on every page.
  Future<String> letterTextDocument({
    int pageCount = 4,
    String textPrefix = 'Letter page',
    String fileName = 'letter_text.pdf',
  }) async {
    return _buildTextDocument(
      width: 612,
      height: 792,
      pageCount: pageCount,
      textPrefix: textPrefix,
      fileName: fileName,
    );
  }

  /// A single landscape (792 x 612) vector/text page.
  Future<String> landscapeTextDocument({
    String textPrefix = 'Landscape page',
    String fileName = 'landscape_text.pdf',
  }) async {
    return _buildTextDocument(
      width: 792,
      height: 612,
      pageCount: 1,
      textPrefix: textPrefix,
      fileName: fileName,
    );
  }

  /// A vector/text page of a non-Letter size (defaults to A4), forcing the merge
  /// to scale it via the form-XObject path while keeping its text extractable.
  Future<String> customSizeTextDocument({
    double width = 595.28,
    double height = 841.89,
    String textPrefix = 'Vector A4 page',
    String fileName = 'a4_text.pdf',
  }) async {
    return _buildTextDocument(
      width: width,
      height: height,
      pageCount: 1,
      textPrefix: textPrefix,
      fileName: fileName,
    );
  }

  Future<String> _buildTextDocument({
    required double width,
    required double height,
    required int pageCount,
    required String textPrefix,
    required String fileName,
  }) async {
    final doc = pw.Document();
    for (var i = 0; i < pageCount; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat(width, height),
          build: (context) => pw.Center(child: pw.Text('$textPrefix ${i + 1}')),
        ),
      );
    }
    return _write(fileName, await doc.save());
  }

  /// A single image-only ("scanned") page whose MediaBox is [widthPts] x
  /// [heightPts] points. This reproduces the bug where a scanner sets the page
  /// size to pixel dimensions. The embedded JPEG's pixel size is independent.
  Future<String> scannedImageDocument({
    required double widthPts,
    required double heightPts,
    int? pixelWidth,
    int? pixelHeight,
    String fileName = 'scanned.pdf',
  }) async {
    final pw = pixelWidth ?? widthPts.round();
    final ph = pixelHeight ?? heightPts.round();

    final image = img.Image(width: pw, height: ph);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    // A thick dark border marks the full extent of the scanned image so the
    // rendered page's content bounds can be measured. Thickness is generous so
    // it survives downscaling when rendered at 72 dpi.
    final border = (pw < ph ? pw : ph) ~/ 40;
    img.drawRect(
      image,
      x1: 0,
      y1: 0,
      x2: pw - 1,
      y2: ph - 1,
      color: img.ColorRgb8(20, 20, 20),
      thickness: border.toDouble(),
    );
    // A dark inner rectangle so the page is clearly neither blank nor all black.
    img.fillRect(
      image,
      x1: pw ~/ 4,
      y1: ph ~/ 4,
      x2: (pw * 3) ~/ 4,
      y2: (ph * 3) ~/ 4,
      color: img.ColorRgb8(40, 40, 40),
    );
    final jpeg = Uint8List.fromList(img.encodeJpg(image, quality: 85));

    final doc = await PdfDocument.createFromJpegData(
      jpeg,
      width: widthPts,
      height: heightPts,
      sourceName: 'scan',
    );
    try {
      return await _write(fileName, await doc.encodePdf());
    } finally {
      await doc.dispose();
    }
  }

  /// Copies [inputPath], applying an absolute [quarterTurns] rotation to every
  /// page, and returns the new file path.
  Future<String> rotatedCopy(
    String inputPath,
    int quarterTurns, {
    String? fileName,
  }) async {
    final source = await PdfDocument.openFile(inputPath);
    final output = await PdfDocument.createNew(sourceName: 'rotated');
    try {
      final rotation = PdfPageRotation.values[quarterTurns % 4];
      output.pages = [
        for (final page in source.pages) page.rotatedTo(rotation),
      ];
      final bytes = await output.encodePdf();
      return await _write(fileName ?? 'rotated_$quarterTurns.pdf', bytes);
    } finally {
      await output.dispose();
      await source.dispose();
    }
  }

  /// Copies [inputPath], setting a CropBox (inset from the MediaBox) on page
  /// [pageIndex], and returns the new file path.
  Future<String> croppedCopy(
    String inputPath, {
    int pageIndex = 0,
    double left = 50,
    double bottom = 100,
    double right = 562,
    double top = 692,
    String fileName = 'cropped.pdf',
  }) async {
    final doc = await PdfDocument.openFile(inputPath);
    try {
      await box.applyCropBox(
        doc,
        pageIndex: pageIndex,
        left: left,
        bottom: bottom,
        right: right,
        top: top,
      );
      return await _write(fileName, await doc.encodePdf());
    } finally {
      await doc.dispose();
    }
  }

  String _path(String fileName) =>
      '${dir.path}${Platform.pathSeparator}$fileName';

  Future<String> _write(String fileName, Uint8List bytes) async {
    final path = _path(fileName);
    await File(path).writeAsBytes(bytes);
    return path;
  }
}
