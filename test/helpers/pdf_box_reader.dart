import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

/// The boxes and rotation of a single PDF page, read directly from PDFium so
/// the merge output is verified independently of the code under test.
class PageBoxes {
  const PageBoxes({
    required this.mediaWidth,
    required this.mediaHeight,
    required this.cropWidth,
    required this.cropHeight,
    required this.rotationQuarterTurns,
  });

  final double mediaWidth;
  final double mediaHeight;
  final double cropWidth;
  final double cropHeight;
  final int rotationQuarterTurns;

  @override
  String toString() =>
      'PageBoxes(media=${mediaWidth}x$mediaHeight, '
      'crop=${cropWidth}x$cropHeight, rot=$rotationQuarterTurns)';
}

/// Reads MediaBox/CropBox/rotation for every page of the PDF at [path].
///
/// The native calls run on pdfrx's PDFium worker isolate (via
/// [PdfrxEntryFunctions.compute]) because PDFium's own Dart callbacks are bound
/// to that isolate.
///
/// When a page has no explicit CropBox, its CropBox is reported as equal to the
/// MediaBox, matching the PDF specification.
Future<List<PageBoxes>> readPageBoxes(String path) async {
  final doc = await PdfDocument.openFile(path);
  try {
    final address = await doc.useNativeDocumentHandle((h) => h);
    return await PdfrxEntryFunctions.instance.compute(
      _readBoxesOnWorker,
      address,
    );
  } finally {
    await doc.dispose();
  }
}

/// Sets a CropBox on page [pageIndex] of an already-open pdfrx document.
Future<void> applyCropBox(
  PdfDocument doc, {
  required int pageIndex,
  required double left,
  required double bottom,
  required double right,
  required double top,
}) async {
  final address = await doc.useNativeDocumentHandle((h) => h);
  await PdfrxEntryFunctions.instance.compute(_applyCropBoxOnWorker, (
    address: address,
    pageIndex: pageIndex,
    left: left,
    bottom: bottom,
    right: right,
    top: top,
  ));
}

List<PageBoxes> _readBoxesOnWorker(int address) {
  final pdf = pdfium.getPdfium();
  final handle = pdfium.FPDF_DOCUMENT.fromAddress(address);
  final count = pdf.FPDF_GetPageCount(handle);
  final result = <PageBoxes>[];
  for (var i = 0; i < count; i++) {
    final page = pdf.FPDF_LoadPage(handle, i);
    try {
      final rotation = pdf.FPDFPage_GetRotation(page);
      final media = _readBox(pdf, page, isMedia: true);
      final crop = _readBox(pdf, page, isMedia: false) ?? media;
      final m = media ?? crop!;
      final c = crop ?? m;
      result.add(
        PageBoxes(
          mediaWidth: m.$1,
          mediaHeight: m.$2,
          cropWidth: c.$1,
          cropHeight: c.$2,
          rotationQuarterTurns: rotation,
        ),
      );
    } finally {
      pdf.FPDF_ClosePage(page);
    }
  }
  return result;
}

void _applyCropBoxOnWorker(
  ({
    int address,
    int pageIndex,
    double left,
    double bottom,
    double right,
    double top,
  })
  m,
) {
  final pdf = pdfium.getPdfium();
  final handle = pdfium.FPDF_DOCUMENT.fromAddress(m.address);
  final page = pdf.FPDF_LoadPage(handle, m.pageIndex);
  try {
    pdf.FPDFPage_SetCropBox(page, m.left, m.bottom, m.right, m.top);
    pdf.FPDFPage_GenerateContent(page);
  } finally {
    pdf.FPDF_ClosePage(page);
  }
}

(double, double)? _readBox(
  pdfium.PDFium pdf,
  pdfium.FPDF_PAGE page, {
  required bool isMedia,
}) {
  return using((arena) {
    final left = arena<Float>();
    final bottom = arena<Float>();
    final right = arena<Float>();
    final top = arena<Float>();
    final ok = isMedia
        ? pdf.FPDFPage_GetMediaBox(page, left, bottom, right, top)
        : pdf.FPDFPage_GetCropBox(page, left, bottom, right, top);
    if (ok == 0) return null;
    return (right.value - left.value, top.value - bottom.value);
  });
}
