import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/pdf_stamp_placement.dart';
import 'pdf_page_geometry.dart';

typedef _StampMessage = ({
  int documentAddress,
  List<Map<String, Object>> placements,
});

/// Adds transparent raster stamps to existing pages without rasterizing the
/// source page content. The mutation runs on pdfrx's PDFium worker isolate.
Future<void> embedPdfStamp({
  required PdfDocument document,
  required PdfStampPlacement placement,
}) async {
  final address = await document.useNativeDocumentHandle((handle) => handle);
  await PdfrxEntryFunctions.instance.compute(_embedPdfStampsOnWorker, (
    documentAddress: address,
    placements: [
      <String, Object>{
        'page': placement.pageNumber,
        'left': placement.left,
        'top': placement.top,
        'width': placement.width,
        'height': placement.height,
        'png': placement.pngBytes,
      },
    ],
  ));
}

Future<int> pdfDigitalSignatureCount(PdfDocument document) async {
  final address = await document.useNativeDocumentHandle((handle) => handle);
  return PdfrxEntryFunctions.instance.compute(_signatureCountOnWorker, address);
}

int _signatureCountOnWorker(int address) {
  final pdf = pdfium.getPdfium();
  return pdf.FPDF_GetSignatureCount(pdfium.FPDF_DOCUMENT.fromAddress(address));
}

void _embedPdfStampsOnWorker(_StampMessage message) {
  final pdf = pdfium.getPdfium();
  final document = pdfium.FPDF_DOCUMENT.fromAddress(message.documentAddress);

  for (final placement in message.placements) {
    final pageNumber = placement['page']! as int;
    final pageCount = pdf.FPDF_GetPageCount(document);
    if (pageNumber < 1 || pageNumber > pageCount) {
      throw PdfProcessingException('Page $pageNumber is not available.');
    }

    final page = pdf.FPDF_LoadPage(document, pageNumber - 1);
    if (page == nullptr) {
      throw PdfProcessingException('Could not open page $pageNumber.');
    }

    try {
      final geometry = _readGeometry(pdf, page);
      final left = placement['left']! as double;
      final top = placement['top']! as double;
      final width = placement['width']! as double;
      final height = placement['height']! as double;
      final matrix = _stampMatrix(
        geometry: geometry,
        left: left,
        top: top,
        width: width,
        height: height,
      );

      final image = img.decodeImage(placement['png']! as Uint8List);
      if (image == null || image.width < 1 || image.height < 1) {
        throw const PdfProcessingException('A signature image is invalid.');
      }
      final bgra = Uint8List.fromList(
        image.getBytes(order: img.ChannelOrder.bgra),
      );

      using((arena) {
        final pixels = arena<Uint8>(bgra.length);
        pixels.asTypedList(bgra.length).setAll(0, bgra);
        final bitmap = pdf.FPDFBitmap_CreateEx(
          image.width,
          image.height,
          pdfium.FPDFBitmap_BGRA,
          pixels.cast<Void>(),
          image.width * 4,
        );
        if (bitmap == nullptr) {
          throw const PdfProcessingException(
            'Could not prepare a signature image.',
          );
        }

        final imageObject = pdf.FPDFPageObj_NewImageObj(document);
        if (imageObject == nullptr) {
          pdf.FPDFBitmap_Destroy(bitmap);
          throw const PdfProcessingException(
            'Could not create a signature image object.',
          );
        }

        var inserted = false;
        try {
          final pagePointer = arena<pdfium.FPDF_PAGE>()..value = page;
          if (pdf.FPDFImageObj_SetBitmap(pagePointer, 1, imageObject, bitmap) ==
              0) {
            throw const PdfProcessingException(
              'Could not embed the signature image.',
            );
          }
          final nativeMatrix = arena<pdfium.FS_MATRIX>();
          nativeMatrix.ref
            ..a = matrix.a
            ..b = matrix.b
            ..c = matrix.c
            ..d = matrix.d
            ..e = matrix.e
            ..f = matrix.f;
          if (pdf.FPDFPageObj_SetMatrix(imageObject, nativeMatrix) == 0) {
            throw const PdfProcessingException(
              'Could not position the signature image.',
            );
          }
          if (pdf.FPDFPage_InsertObject(page, imageObject) == 0) {
            throw const PdfProcessingException(
              'Could not place the signature on the page.',
            );
          }
          inserted = true;
          if (pdf.FPDFPage_GenerateContent(page) == 0) {
            throw const PdfProcessingException(
              'Could not save the signature placement.',
            );
          }
        } finally {
          pdf.FPDFBitmap_Destroy(bitmap);
          if (!inserted) pdf.FPDFPageObj_Destroy(imageObject);
        }
      });
    } finally {
      pdf.FPDF_ClosePage(page);
    }
  }
}

PdfPageGeometry _readGeometry(pdfium.PDFium pdf, pdfium.FPDF_PAGE page) {
  final rotation = pdf.FPDFPage_GetRotation(page);
  final media = _readBox(pdf, page, media: true);
  final crop = _readBox(pdf, page, media: false);
  return PdfPageGeometry.from(
    mediaBox: media,
    cropBox: crop,
    rotationDegrees: rotation * 90,
  );
}

PdfBox? _readBox(
  pdfium.PDFium pdf,
  pdfium.FPDF_PAGE page, {
  required bool media,
}) {
  return using((arena) {
    final left = arena<Float>();
    final bottom = arena<Float>();
    final right = arena<Float>();
    final top = arena<Float>();
    final result = media
        ? pdf.FPDFPage_GetMediaBox(page, left, bottom, right, top)
        : pdf.FPDFPage_GetCropBox(page, left, bottom, right, top);
    if (result == 0) return null;
    return PdfBox(left.value, bottom.value, right.value, top.value);
  });
}

({double a, double b, double c, double d, double e, double f}) _stampMatrix({
  required PdfPageGeometry geometry,
  required double left,
  required double top,
  required double width,
  required double height,
}) {
  final box = geometry.visibleBox;
  final pageWidth = geometry.displayWidth;
  final pageHeight = geometry.displayHeight;
  final x = left * pageWidth;
  final y = top * pageHeight;
  final w = width * pageWidth;
  final h = height * pageHeight;

  return switch (geometry.rotationQuarterTurns) {
    1 => (a: 0, b: w, c: -h, d: 0, e: box.left + y + h, f: box.bottom + x),
    2 => (
      a: -w,
      b: 0,
      c: 0,
      d: -h,
      e: box.left + pageWidth - x,
      f: box.bottom + y + h,
    ),
    3 => (
      a: 0,
      b: -w,
      c: h,
      d: 0,
      e: box.left + box.width - y - h,
      f: box.bottom + box.height - x,
    ),
    _ => (
      a: w,
      b: 0,
      c: 0,
      d: h,
      e: box.left + x,
      f: box.bottom + pageHeight - y - h,
    ),
  };
}
