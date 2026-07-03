import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/services/pdf/pdf_page_geometry.dart';

void main() {
  group('PdfPageGeometry.from', () {
    test('uses MediaBox when CropBox is absent', () {
      final g = PdfPageGeometry.from(
        mediaBox: const PdfBox(0, 0, 612, 792),
        rotationDegrees: 0,
      );
      expect(g.displayWidth, 612);
      expect(g.displayHeight, 792);
      expect(g.rotationQuarterTurns, 0);
    });

    test('clips CropBox to MediaBox and reports cropped visible size', () {
      final g = PdfPageGeometry.from(
        mediaBox: const PdfBox(0, 0, 612, 792),
        cropBox: const PdfBox(50, 100, 562, 692),
        rotationDegrees: 0,
      );
      expect(g.visibleBox.left, 50);
      expect(g.visibleBox.bottom, 100);
      expect(g.displayWidth, 512);
      expect(g.displayHeight, 592);
    });

    test('swaps width/height for 90 and 270 degree rotation', () {
      final g90 = PdfPageGeometry.from(
        mediaBox: const PdfBox(0, 0, 612, 792),
        rotationDegrees: 90,
      );
      expect(g90.displayWidth, 792);
      expect(g90.displayHeight, 612);
      expect(g90.rotationQuarterTurns, 1);

      final g270 = PdfPageGeometry.from(
        mediaBox: const PdfBox(0, 0, 612, 792),
        rotationDegrees: 270,
      );
      expect(g270.displayWidth, 792);
      expect(g270.displayHeight, 612);
      expect(g270.rotationQuarterTurns, 3);
    });

    test('keeps width/height for 180 degree rotation', () {
      final g = PdfPageGeometry.from(
        mediaBox: const PdfBox(0, 0, 612, 792),
        rotationDegrees: 180,
      );
      expect(g.displayWidth, 612);
      expect(g.displayHeight, 792);
      expect(g.rotationQuarterTurns, 2);
    });

    test('honors non-zero box origins', () {
      final g = PdfPageGeometry.from(
        mediaBox: const PdfBox(10, 20, 622, 812),
        rotationDegrees: 0,
      );
      expect(g.visibleBox.left, 10);
      expect(g.visibleBox.bottom, 20);
      expect(g.displayWidth, 612);
      expect(g.displayHeight, 792);
    });

    test('falls back to default Letter for a malformed MediaBox', () {
      final g = PdfPageGeometry.from(
        mediaBox: const PdfBox(0, 0, 0, 0),
        rotationDegrees: 0,
      );
      expect(g.displayWidth, 612);
      expect(g.displayHeight, 792);
    });

    test('falls back to MediaBox for a malformed CropBox', () {
      final g = PdfPageGeometry.from(
        mediaBox: const PdfBox(0, 0, 400, 500),
        cropBox: const PdfBox(0, 0, -1, -1),
        rotationDegrees: 0,
      );
      expect(g.displayWidth, 400);
      expect(g.displayHeight, 500);
    });
  });

  group('computeFitTransform', () {
    test('scales an oversized page down proportionally and centers it', () {
      final fit = computeFitTransform(
        visibleWidth: 1609,
        visibleHeight: 2000,
        targetWidth: 612,
        targetHeight: 792,
      );
      // Width-constrained: 612/1609 < 792/2000.
      expect(fit.scale, closeTo(612 / 1609, 1e-9));
      expect(fit.scaledWidth, closeTo(612, 1e-6));
      expect(fit.scaledHeight, lessThan(792));
      // Flush horizontally, centered vertically.
      expect(fit.offsetX, closeTo(0, 1e-6));
      expect(fit.offsetY, closeTo((792 - fit.scaledHeight) / 2, 1e-6));
    });

    test('scales a landscape page to fit width and centers vertically', () {
      final fit = computeFitTransform(
        visibleWidth: 792,
        visibleHeight: 612,
        targetWidth: 612,
        targetHeight: 792,
      );
      expect(fit.scale, closeTo(612 / 792, 1e-9));
      expect(fit.scaledWidth, closeTo(612, 1e-6));
      expect(fit.offsetX, closeTo(0, 1e-6));
      expect(fit.offsetY, greaterThan(0));
    });

    test('does not upscale beyond the target uniformly', () {
      final fit = computeFitTransform(
        visibleWidth: 306,
        visibleHeight: 396,
        targetWidth: 612,
        targetHeight: 792,
      );
      // Same aspect ratio, exactly 2x on both axes, centered at origin.
      expect(fit.scale, closeTo(2.0, 1e-9));
      expect(fit.offsetX, closeTo(0, 1e-6));
      expect(fit.offsetY, closeTo(0, 1e-6));
    });

    test('produces an identity-like transform for an exact match', () {
      final fit = computeFitTransform(
        visibleWidth: 612,
        visibleHeight: 792,
        targetWidth: 612,
        targetHeight: 792,
      );
      expect(fit.scale, closeTo(1.0, 1e-9));
      expect(fit.offsetX, closeTo(0, 1e-6));
      expect(fit.offsetY, closeTo(0, 1e-6));
    });

    test('never distorts: same scale on both axes', () {
      final fit = computeFitTransform(
        visibleWidth: 1000,
        visibleHeight: 300,
        targetWidth: 612,
        targetHeight: 792,
      );
      // The matrix uses `scale` for both a and d, so aspect ratio is preserved.
      final aspectIn = 1000 / 300;
      final aspectOut = fit.scaledWidth / fit.scaledHeight;
      expect(aspectOut, closeTo(aspectIn, 1e-6));
    });

    test('handles degenerate visible size without producing NaN', () {
      final fit = computeFitTransform(
        visibleWidth: 0,
        visibleHeight: 0,
        targetWidth: 612,
        targetHeight: 792,
      );
      expect(fit.scale.isFinite, isTrue);
      expect(fit.scale, closeTo(1.0, 1e-9));
    });
  });
}
