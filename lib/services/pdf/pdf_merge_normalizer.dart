import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

import 'pdf_merge_page_size.dart';
import 'pdf_page_geometry.dart';

/// Summary of what the normalizer did, useful for diagnostics and tests.
class MergeNormalizationResult {
  const MergeNormalizationResult({
    required this.normalizedPageCount,
    required this.copiedPageCount,
    required this.targetWidth,
    required this.targetHeight,
  });

  /// Pages that were scaled/centered onto a fresh target-sized page.
  final int normalizedPageCount;

  /// Pages copied verbatim because they already matched the target size.
  final int copiedPageCount;

  final double targetWidth;
  final double targetHeight;
}

/// Message sent to the PDFium worker isolate describing the merge to perform.
///
/// Only primitive / collection values are used so the record can be sent across
/// the isolate boundary. Document handles are passed as their native pointer
/// addresses.
typedef _MergeMessage = ({
  int destAddress,
  List<int> srcAddresses,
  List<int> pageCounts,
  double targetWidth,
  double targetHeight,
});

/// Merges PDF pages onto a uniform target page size using PDFium's form-XObject
/// mechanism, preserving vector graphics and selectable text.
///
/// Each source page is imported as a reusable form XObject
/// ([pdfium.PDFium.FPDF_NewXObjectFromPage]) — never rasterized — and drawn onto
/// a new page of the target size with a proportional, centered transform. This
/// keeps text and vector content intact while guaranteeing consistent output
/// dimensions.
///
/// The source documents are only read; all writes go to [outputDoc], so
/// repeated merges never mutate or corrupt the inputs.
class PdfMergeNormalizer {
  PdfMergeNormalizer._();

  /// Builds [outputDoc] from the pages of [sourceDocs], sizing every output
  /// page according to [mode].
  ///
  /// Must not be called with [MergePageSizeMode.preserveOriginal]; callers
  /// should use the plain page-concatenation path for that mode instead.
  static Future<MergeNormalizationResult> normalizeInto({
    required List<PdfDocument> sourceDocs,
    required PdfDocument outputDoc,
    required MergePageSizeMode mode,
  }) async {
    if (sourceDocs.isEmpty || sourceDocs.first.pages.isEmpty) {
      throw ArgumentError('normalizeInto requires at least one non-empty PDF');
    }

    final firstPage = sourceDocs.first.pages.first;
    final target = resolveTargetPageSize(
      mode,
      TargetPageSize(firstPage.width, firstPage.height),
    );
    if (target == null) {
      throw ArgumentError('normalizeInto does not support preserveOriginal');
    }

    // Native document handles are stable pointers; capture their addresses so
    // the work can run inside the PDFium worker isolate.
    final destAddress = await outputDoc.useNativeDocumentHandle((h) => h);
    final srcAddresses = <int>[
      for (final doc in sourceDocs) await doc.useNativeDocumentHandle((h) => h),
    ];
    final pageCounts = [for (final doc in sourceDocs) doc.pages.length];

    // Run all PDFium mutation on the worker isolate: PDFium's registered Dart
    // callbacks are bound to that isolate, so page creation/import must happen
    // there rather than via useNativeDocumentHandle (which runs on the caller).
    final counts = await PdfrxEntryFunctions.instance.compute(
      _mergeOnWorker,
      (
        destAddress: destAddress,
        srcAddresses: srcAddresses,
        pageCounts: pageCounts,
        targetWidth: target.width,
        targetHeight: target.height,
      ),
    );

    // Sync pdfrx's page list with the pages created natively.
    await outputDoc.reloadPages();

    return MergeNormalizationResult(
      normalizedPageCount: counts.$1,
      copiedPageCount: counts.$2,
      targetWidth: target.width,
      targetHeight: target.height,
    );
  }
}

/// Tolerance (in points) for treating a page as already matching the target.
const double _epsilon = 0.5;

/// Worker-isolate entry point. Returns `(normalizedCount, copiedCount)`.
(int, int) _mergeOnWorker(_MergeMessage message) {
  final pdf = pdfium.getPdfium();
  final dest = pdfium.FPDF_DOCUMENT.fromAddress(message.destAddress);
  final targetWidth = message.targetWidth;
  final targetHeight = message.targetHeight;

  var destIndex = 0;
  var normalized = 0;
  var copied = 0;

  for (var s = 0; s < message.srcAddresses.length; s++) {
    final src = pdfium.FPDF_DOCUMENT.fromAddress(message.srcAddresses[s]);
    for (var p = 0; p < message.pageCounts[s]; p++) {
      final didNormalize = _placePage(
        pdf: pdf,
        dest: dest,
        src: src,
        srcPageIndex: p,
        destIndex: destIndex,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      if (didNormalize) {
        normalized++;
      } else {
        copied++;
      }
      destIndex++;
    }
  }

  return (normalized, copied);
}

/// Places one source page onto the output document. Returns `true` if the page
/// was scaled/centered onto a new target-sized page, `false` if it was copied
/// verbatim (already the right size).
bool _placePage({
  required pdfium.PDFium pdf,
  required pdfium.FPDF_DOCUMENT dest,
  required pdfium.FPDF_DOCUMENT src,
  required int srcPageIndex,
  required int destIndex,
  required double targetWidth,
  required double targetHeight,
}) {
  final geometry = _readGeometry(pdf, src, srcPageIndex);

  final alreadyMatches =
      geometry.rotationQuarterTurns == 0 &&
      geometry.visibleBox.left.abs() < _epsilon &&
      geometry.visibleBox.bottom.abs() < _epsilon &&
      (geometry.displayWidth - targetWidth).abs() < _epsilon &&
      (geometry.displayHeight - targetHeight).abs() < _epsilon;

  if (alreadyMatches) {
    _importPageVerbatim(pdf, dest, src, srcPageIndex, destIndex);
    return false;
  }

  final fit = computeFitTransform(
    visibleWidth: geometry.displayWidth,
    visibleHeight: geometry.displayHeight,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );
  _placePageAsForm(
    pdf: pdf,
    dest: dest,
    src: src,
    srcPageIndex: srcPageIndex,
    destIndex: destIndex,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
    fit: fit,
  );
  return true;
}

PdfPageGeometry _readGeometry(
  pdfium.PDFium pdf,
  pdfium.FPDF_DOCUMENT src,
  int pageIndex,
) {
  final page = pdf.FPDF_LoadPage(src, pageIndex);
  try {
    final rotation = pdf.FPDFPage_GetRotation(page);
    final media = _readBox(pdf, page, isMedia: true);
    final crop = _readBox(pdf, page, isMedia: false);
    return PdfPageGeometry.from(
      mediaBox: media,
      cropBox: crop,
      rotationDegrees: rotation * 90,
    );
  } finally {
    pdf.FPDF_ClosePage(page);
  }
}

PdfBox? _readBox(
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
    return PdfBox(left.value, bottom.value, right.value, top.value);
  });
}

void _importPageVerbatim(
  pdfium.PDFium pdf,
  pdfium.FPDF_DOCUMENT dest,
  pdfium.FPDF_DOCUMENT src,
  int srcPageIndex,
  int destIndex,
) {
  using((arena) {
    final indices = arena<Int>();
    indices.value = srcPageIndex;
    pdf.FPDF_ImportPagesByIndex(dest, src, indices, 1, destIndex);
  });
}

void _placePageAsForm({
  required pdfium.PDFium pdf,
  required pdfium.FPDF_DOCUMENT dest,
  required pdfium.FPDF_DOCUMENT src,
  required int srcPageIndex,
  required int destIndex,
  required double targetWidth,
  required double targetHeight,
  required FitTransform fit,
}) {
  final newPage = pdf.FPDFPage_New(dest, destIndex, targetWidth, targetHeight);
  // Make both boxes explicit so every output page reports the target size.
  pdf.FPDFPage_SetMediaBox(newPage, 0, 0, targetWidth, targetHeight);
  pdf.FPDFPage_SetCropBox(newPage, 0, 0, targetWidth, targetHeight);

  final xobject = pdf.FPDF_NewXObjectFromPage(dest, src, srcPageIndex);
  if (xobject == nullptr) {
    pdf.FPDF_ClosePage(newPage);
    throw StateError('FPDF_NewXObjectFromPage failed for page $srcPageIndex');
  }
  try {
    final formObj = pdf.FPDF_NewFormObjectFromXObject(xobject);
    if (formObj == nullptr) {
      throw StateError(
        'FPDF_NewFormObjectFromXObject failed for page $srcPageIndex',
      );
    }

    using((arena) {
      final matrix = arena<pdfium.FS_MATRIX>();
      matrix.ref
        ..a = fit.scale
        ..b = 0
        ..c = 0
        ..d = fit.scale
        ..e = fit.offsetX
        ..f = fit.offsetY;
      pdf.FPDFPageObj_SetMatrix(formObj, matrix);
    });

    pdf.FPDFPage_InsertObject(newPage, formObj);
    pdf.FPDFPage_GenerateContent(newPage);
  } finally {
    pdf.FPDF_CloseXObject(xobject);
    pdf.FPDF_ClosePage(newPage);
  }
}
