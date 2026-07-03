import 'dart:math' as math;

/// Pure-Dart PDF page geometry helpers used by the merge normalizer.
///
/// These functions have no dependency on PDFium so they can be unit tested in
/// isolation. They compute the *visible* (displayed) size of a source page from
/// its MediaBox, CropBox and rotation, and the affine transform required to fit
/// that visible content, centered and proportionally scaled, onto a target
/// page.
///
/// Coordinates follow the PDF convention: the origin is the bottom-left corner
/// and Y grows upward. Sizes are expressed in PDF points (1/72 inch).

/// Default page size used when a source page has missing or malformed boxes.
/// US Letter, matching PDFium's own fallback in `fpdf_ppo.cpp`.
const PdfBox kDefaultMediaBox = PdfBox(0, 0, 612, 792);

/// A rectangular PDF box (e.g. MediaBox or CropBox), in points.
class PdfBox {
  const PdfBox(this.left, this.bottom, this.right, this.top);

  final double left;
  final double bottom;
  final double right;
  final double top;

  double get width => right - left;
  double get height => top - bottom;

  /// A box is usable only if it has strictly positive, finite extents.
  bool get isValid =>
      left.isFinite &&
      bottom.isFinite &&
      right.isFinite &&
      top.isFinite &&
      right > left &&
      top > bottom;

  /// Returns a copy with corners ordered so that `left < right` and
  /// `bottom < top`, guarding against boxes stored with swapped corners.
  PdfBox ordered() => PdfBox(
    math.min(left, right),
    math.min(bottom, top),
    math.max(left, right),
    math.max(bottom, top),
  );

  /// Intersection of two ordered boxes, or `null` if they do not overlap.
  PdfBox? intersect(PdfBox other) {
    final a = ordered();
    final b = other.ordered();
    final l = math.max(a.left, b.left);
    final btm = math.max(a.bottom, b.bottom);
    final r = math.min(a.right, b.right);
    final t = math.min(a.top, b.top);
    if (r <= l || t <= btm) return null;
    return PdfBox(l, btm, r, t);
  }

  @override
  String toString() => 'PdfBox($left, $bottom, $right, $top)';
}

/// Resolved geometry of a source page: the effective visible box and rotation,
/// together with the rotation-adjusted display dimensions.
class PdfPageGeometry {
  PdfPageGeometry._({
    required this.visibleBox,
    required this.rotationQuarterTurns,
    required this.displayWidth,
    required this.displayHeight,
  });

  /// The effective visible region (CropBox clipped to MediaBox), in unrotated
  /// page coordinates. Its origin may be non-zero.
  final PdfBox visibleBox;

  /// Page rotation as a number of clockwise quarter turns (0, 1, 2, 3).
  final int rotationQuarterTurns;

  /// Visible width after applying rotation (points).
  final double displayWidth;

  /// Visible height after applying rotation (points).
  final double displayHeight;

  /// Builds page geometry from raw boxes and a rotation value.
  ///
  /// [rotationDegrees] may be any of 0, 90, 180, 270 (other values are reduced
  /// modulo 360 and snapped to the nearest quarter turn). Missing or malformed
  /// boxes fall back to sensible defaults: an invalid MediaBox becomes
  /// [kDefaultMediaBox], and an invalid or absent CropBox falls back to the
  /// MediaBox.
  factory PdfPageGeometry.from({
    PdfBox? mediaBox,
    PdfBox? cropBox,
    required int rotationDegrees,
  }) {
    final media = (mediaBox != null && mediaBox.isValid)
        ? mediaBox.ordered()
        : kDefaultMediaBox;

    PdfBox visible;
    if (cropBox != null && cropBox.isValid) {
      visible = cropBox.intersect(media) ?? media;
    } else {
      visible = media;
    }

    final quarter = _degreesToQuarterTurns(rotationDegrees);
    final swap = quarter.isOdd;
    final displayWidth = swap ? visible.height : visible.width;
    final displayHeight = swap ? visible.width : visible.height;

    return PdfPageGeometry._(
      visibleBox: visible,
      rotationQuarterTurns: quarter,
      displayWidth: displayWidth,
      displayHeight: displayHeight,
    );
  }

  static int _degreesToQuarterTurns(int degrees) {
    var d = degrees % 360;
    if (d < 0) d += 360;
    return ((d + 45) ~/ 90) % 4;
  }
}

/// The affine transform (scale + centering translation) that fits a source
/// page's visible content onto a target page without distortion.
///
/// The matrix, in PDF `[a b c d e f]` form, is `[scale, 0, 0, scale, offsetX,
/// offsetY]`. A point `(x, y)` in the source's displayed coordinate space maps
/// to `(scale * x + offsetX, scale * y + offsetY)` on the target page.
class FitTransform {
  const FitTransform({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.scaledWidth,
    required this.scaledHeight,
  });

  final double scale;
  final double offsetX;
  final double offsetY;
  final double scaledWidth;
  final double scaledHeight;
}

/// Computes the proportional fit-and-center transform for placing content of
/// size [visibleWidth] x [visibleHeight] onto a [targetWidth] x [targetHeight]
/// page.
///
/// The scale is `min(targetWidth / visibleWidth, targetHeight / visibleHeight)`
/// so the content is never stretched, cropped, or distorted, and the result is
/// centered on both axes.
FitTransform computeFitTransform({
  required double visibleWidth,
  required double visibleHeight,
  required double targetWidth,
  required double targetHeight,
}) {
  // Guard against degenerate inputs so we never divide by zero or produce a
  // non-finite matrix; fall back to no scaling in that case.
  final safeVisibleW = (visibleWidth.isFinite && visibleWidth > 0)
      ? visibleWidth
      : targetWidth;
  final safeVisibleH = (visibleHeight.isFinite && visibleHeight > 0)
      ? visibleHeight
      : targetHeight;

  final scale = math.min(
    targetWidth / safeVisibleW,
    targetHeight / safeVisibleH,
  );
  final scaledWidth = safeVisibleW * scale;
  final scaledHeight = safeVisibleH * scale;
  final offsetX = (targetWidth - scaledWidth) / 2;
  final offsetY = (targetHeight - scaledHeight) / 2;

  return FitTransform(
    scale: scale,
    offsetX: offsetX,
    offsetY: offsetY,
    scaledWidth: scaledWidth,
    scaledHeight: scaledHeight,
  );
}
