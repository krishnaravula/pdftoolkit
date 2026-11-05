import 'dart:typed_data';

/// A visual image stamp placed on a one-based PDF page.
///
/// Position and size are fractions of the page's displayed dimensions, with
/// the origin at the top-left. The image bytes should be PNG so transparency
/// is preserved.
class PdfStampPlacement {
  const PdfStampPlacement({
    required this.pageNumber,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.pngBytes,
  });

  final int pageNumber;
  final double left;
  final double top;
  final double width;
  final double height;
  final Uint8List pngBytes;
}
