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

Future<ImageToPdfPayload> prepareImageForPdfInIsolate(
  Uint8List bytes, {
  int jpegQuality = 85,
  int maxDimension = 2000,
}) {
  return compute(
    _prepareImageForPdfWorker,
    _PrepareImageForPdfArgs(bytes, jpegQuality, maxDimension),
  );
}

ImageToPdfPayload _prepareImageForPdfWorker(_PrepareImageForPdfArgs args) {
  var image = img.decodeImage(args.bytes);
  if (image == null) throw const FormatException('Image could not be decoded.');

  if (image.width > args.maxDimension || image.height > args.maxDimension) {
    image = img.copyResize(
      image,
      width: image.width > image.height ? args.maxDimension : null,
      height: image.height >= image.width ? args.maxDimension : null,
      interpolation: img.Interpolation.linear,
    );
  }

  return ImageToPdfPayload(
    jpegBytes: Uint8List.fromList(img.encodeJpg(image, quality: args.quality)),
    width: image.width.toDouble(),
    height: image.height.toDouble(),
  );
}

Future<Uint8List> normalizeSignatureImageInIsolate(
  Uint8List bytes, {
  int maxDimension = 1600,
}) {
  return compute(
    _normalizeSignatureImageWorker,
    _NormalizeImageArgs(bytes, maxDimension),
  );
}

Uint8List _normalizeSignatureImageWorker(_NormalizeImageArgs args) {
  var image = img.decodeImage(args.bytes);
  if (image == null) throw const FormatException('Image could not be decoded.');
  if (image.width > args.maxDimension || image.height > args.maxDimension) {
    image = img.copyResize(
      image,
      width: image.width > image.height ? args.maxDimension : null,
      height: image.height >= image.width ? args.maxDimension : null,
      interpolation: img.Interpolation.linear,
    );
  }
  return Uint8List.fromList(img.encodePng(image));
}

class ImageToPdfPayload {
  const ImageToPdfPayload({
    required this.jpegBytes,
    required this.width,
    required this.height,
  });

  final Uint8List jpegBytes;
  final double width;
  final double height;
}

Uint8List _encodeJpegFromImageWorker(_EncodeJpegFromImageArgs args) {
  return encodeJpegFromImageBytes(args.image, args.quality);
}

class _EncodeJpegFromImageArgs {
  const _EncodeJpegFromImageArgs(this.image, this.quality);

  final img.Image image;
  final int quality;
}

class _PrepareImageForPdfArgs {
  const _PrepareImageForPdfArgs(this.bytes, this.quality, this.maxDimension);

  final Uint8List bytes;
  final int quality;
  final int maxDimension;
}

class _NormalizeImageArgs {
  const _NormalizeImageArgs(this.bytes, this.maxDimension);

  final Uint8List bytes;
  final int maxDimension;
}
