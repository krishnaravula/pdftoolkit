import 'dart:io';

import 'package:image/image.dart' as img;

import '../../core/utils/image_processing.dart';
import '../../domain/entities/scan_page.dart';

class PageEnhancer {
  Future<String> applyEnhancement(
    String inputPath,
    ScanEnhancementMode mode, {
    required String outputPath,
  }) async {
    if (mode == ScanEnhancementMode.color) {
      await File(inputPath).copy(outputPath);
      return outputPath;
    }

    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image');
    }

    img.Image processed;
    switch (mode) {
      case ScanEnhancementMode.grayscale:
        processed = img.grayscale(decoded);
      case ScanEnhancementMode.blackAndWhite:
        final gray = img.grayscale(decoded);
        processed = img.luminanceThreshold(gray, threshold: 0.5);
      case ScanEnhancementMode.color:
        processed = decoded;
    }

    final jpegBytes = await encodeJpegFromImageInIsolate(
      processed,
      quality: 90,
    );
    await File(outputPath).writeAsBytes(jpegBytes);
    return outputPath;
  }

  Future<List<String>> applyEnhancements(
    List<ScanPage> pages,
    String tempDirectory,
  ) async {
    final outputs = <String>[];
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final outPath = '$tempDirectory/enhanced_${page.id}.jpg';
      outputs.add(
        await applyEnhancement(
          page.imagePath,
          page.enhancement,
          outputPath: outPath,
        ),
      );
    }
    return outputs;
  }
}
