import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Top-level functions for [compute] — must be top-level or static.

Uint8List encodeJpegFromImageBytes(img.Image image, int quality) {
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

class ImageDimensions {
  const ImageDimensions({required this.width, required this.height});

  final double width;
  final double height;
}

Future<Uint8List> encodeJpegFromImageInIsolate(
  img.Image image, {
  int quality = 90,
}) {
  return compute(
    _encodeJpegFromImageWorker,
    _EncodeJpegFromImageArgs(image, quality),
  );
}

Uint8List _encodeJpegFromImageWorker(_EncodeJpegFromImageArgs args) {
  return encodeJpegFromImageBytes(args.image, args.quality);
}

class _EncodeJpegFromImageArgs {
  const _EncodeJpegFromImageArgs(this.image, this.quality);

  final img.Image image;
  final int quality;
}
