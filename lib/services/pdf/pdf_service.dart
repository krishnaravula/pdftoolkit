import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../../core/errors/app_exception.dart';
import '../../core/pdf/pdfrx_initializer.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/image_processing.dart';
import '../../domain/entities/pdf_job.dart';
import 'pdf_merge_normalizer.dart';
import 'pdf_merge_page_size.dart';

typedef PdfProgressCallback =
    void Function(int current, int total, String message);

class PdfService {
  static const maxMergeInputs = 50;
  static const maxCompressPages = 150;

  Future<String> mergePdfs(
    List<String> inputPaths, {
    required String outputPath,
    MergePageSizeMode pageSizeMode = MergePageSizeMode.firstPageOfFirstPdf,
    PdfProgressCallback? onProgress,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    if (inputPaths.length > maxMergeInputs) {
      throw PdfProcessingException(
        'Too many files to merge at once (max $maxMergeInputs).',
      );
    }

    PdfDocument? outputDoc;
    final sourceDocs = <PdfDocument>[];
    try {
      onProgress?.call(0, inputPaths.length + 1, 'Merging files…');
      outputDoc = await PdfDocument.createNew(sourceName: outputPath);

      for (final path in inputPaths) {
        sourceDocs.add(await _openFile(path));
      }

      if (pageSizeMode == MergePageSizeMode.preserveOriginal) {
        // Keep the original per-page sizes: concatenate pages verbatim.
        for (var i = 0; i < sourceDocs.length; i++) {
          outputDoc.pages = [...outputDoc.pages, ...sourceDocs[i].pages];
          onProgress?.call(
            i + 1,
            inputPaths.length + 1,
            'Merged ${i + 1}/${inputPaths.length}',
          );
          await Future<void>.delayed(Duration.zero);
        }
      } else {
        // Normalize every page onto a uniform target size, preserving vector
        // content and text via form XObjects.
        await PdfMergeNormalizer.normalizeInto(
          sourceDocs: sourceDocs,
          outputDoc: outputDoc,
          mode: pageSizeMode,
        );
        onProgress?.call(
          inputPaths.length,
          inputPaths.length + 1,
          'Normalizing pages…',
        );
      }

      await _writeDocument(outputDoc, outputPath, onProgress: onProgress);
      return outputPath;
    } finally {
      for (final d in sourceDocs) {
        d.dispose();
      }
      outputDoc?.dispose();
    }
  }

  Future<List<String>> splitPdf(
    String inputPath, {
    required SplitMode mode,
    required String outputDirectory,
    List<int>? selectedPages,
    int pagesPerFile = 1,
    String namePrefix = 'split',
    PdfProgressCallback? onProgress,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    final doc = await _openFile(inputPath);
    try {
      final totalPages = doc.pages.length;
      final ranges = _buildSplitRanges(
        totalPages: totalPages,
        mode: mode,
        selectedPages: selectedPages,
        pagesPerFile: pagesPerFile,
      );

      final outputs = <String>[];
      for (var i = 0; i < ranges.length; i++) {
        final range = ranges[i];
        onProgress?.call(
          i,
          ranges.length,
          'Splitting part ${i + 1}/${ranges.length}',
        );

        final partDoc = await PdfDocument.createNew(
          sourceName: 'part_${i + 1}.pdf',
        );
        partDoc.pages = [for (final pageNum in range) doc.pages[pageNum - 1]];

        final baseName = switch (mode) {
          SplitMode.singlePages => '${namePrefix}_page_${i + 1}.pdf',
          _ when ranges.length == 1 => '$namePrefix.pdf',
          _ => '${namePrefix}_part_${i + 1}.pdf',
        };
        final outputPath = FileUtils.uniqueOutputPath(
          outputDirectory,
          baseName,
        );
        await _writeDocument(partDoc, outputPath);
        partDoc.dispose();
        outputs.add(outputPath);
      }
      onProgress?.call(ranges.length, ranges.length, 'Done');
      return outputs;
    } finally {
      doc.dispose();
    }
  }

  Future<String> reorderOrDeletePages({
    required String inputPath,
    required List<int> pageOrderOneBased,
    required String outputPath,
    PdfProgressCallback? onProgress,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    final doc = await _openFile(inputPath);
    PdfDocument? outputDoc;
    try {
      onProgress?.call(0, 1, 'Applying changes…');
      outputDoc = await PdfDocument.createNew(sourceName: outputPath);
      outputDoc.pages = [
        for (final pageNum in pageOrderOneBased) doc.pages[pageNum - 1],
      ];
      await _writeDocument(outputDoc, outputPath);
      return outputPath;
    } finally {
      doc.dispose();
      outputDoc?.dispose();
    }
  }

  Future<String> removePassword({
    required String inputPath,
    required String password,
    required String outputPath,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(
        inputPath,
        passwordProvider: () => password,
      );
      await _writeDocument(doc, outputPath, removeSecurity: true);
      return outputPath;
    } on PdfException catch (e) {
      if (e.toString().toLowerCase().contains('password')) {
        throw const InvalidPasswordException();
      }
      throw PdfProcessingException(e.toString());
    } finally {
      doc?.dispose();
    }
  }

  Future<String> imagesToPdf(
    List<String> imagePaths, {
    required String outputPath,
    PdfProgressCallback? onProgress,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    PdfDocument? doc;
    final pageDocs = <PdfDocument>[];
    try {
      final pages = <PdfPage>[];
      for (var i = 0; i < imagePaths.length; i++) {
        onProgress?.call(i, imagePaths.length, 'Processing image ${i + 1}');
        final file = File(imagePaths[i]);
        final rawBytes = await file.readAsBytes();

        // Decode image to check dimensions and resize if necessary
        var image = img.decodeImage(rawBytes);
        if (image == null) {
          throw PdfProcessingException(
            'Failed to decode image ${imagePaths[i]}',
          );
        }

        // Downscale if too large (e.g., > 2000px in any dimension) to save memory and PDF size
        const maxDimension = 2000;
        if (image.width > maxDimension || image.height > maxDimension) {
          image = img.copyResize(
            image,
            width: image.width > image.height ? maxDimension : null,
            height: image.height >= image.width ? maxDimension : null,
            interpolation: img.Interpolation.linear,
          );
        }

        final dimensions = ImageDimensions(
          width: image.width.toDouble(),
          height: image.height.toDouble(),
        );
        final jpegBytes = await encodeJpegFromImageInIsolate(
          image,
          quality: 85,
        );

        final pageDoc = await PdfDocument.createFromJpegData(
          jpegBytes,
          width: dimensions.width,
          height: dimensions.height,
          sourceName: imagePaths[i],
        );
        pageDocs.add(pageDoc);
        pages.addAll(pageDoc.pages);
        await Future<void>.delayed(Duration.zero);
      }

      doc = await PdfDocument.createNew(sourceName: outputPath);
      doc.pages = pages;
      await _writeDocument(doc, outputPath);
      onProgress?.call(imagePaths.length, imagePaths.length, 'Done');
      return outputPath;
    } finally {
      for (final d in pageDocs) {
        d.dispose();
      }
      doc?.dispose();
    }
  }

  Future<String> compressPdf({
    required String inputPath,
    required String outputPath,
    required CompressionQuality quality,
    PdfProgressCallback? onProgress,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    final doc = await _openFile(inputPath);
    PdfDocument? outputDoc;
    // Source documents for each rendered page must stay alive until after the
    // output is encoded, because encodePdf() -> assemble() re-imports pages from
    // these source documents. Disposing them earlier corrupts the output.
    final pageDocs = <PdfDocument>[];
    try {
      if (doc.pages.length > maxCompressPages) {
        throw PdfProcessingException(
          'PDF has too many pages to compress safely (max $maxCompressPages). Try splitting first.',
        );
      }

      final dpi = quality.renderDpi;
      final scale = dpi / 72.0;
      final jpegQuality = quality.jpegQuality;

      outputDoc = await PdfDocument.createNew(sourceName: outputPath);
      final pages = <PdfPage>[];

      for (var i = 0; i < doc.pages.length; i++) {
        onProgress?.call(i, doc.pages.length, 'Compressing page ${i + 1}');
        await Future<void>.delayed(Duration.zero);

        final page = doc.pages[i];
        final rendered = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
        );
        if (rendered == null) {
          throw PdfProcessingException('Failed to render page ${i + 1}');
        }

        final image = rendered.createImageNF();
        rendered.dispose();

        final jpegBytes = await encodeJpegFromImageInIsolate(
          image,
          quality: jpegQuality,
        );

        final pageDoc = await PdfDocument.createFromJpegData(
          jpegBytes,
          width: page.width,
          height: page.height,
          sourceName: 'page_${i + 1}.jpg',
        );
        pageDocs.add(pageDoc);
        pages.addAll(pageDoc.pages);
      }

      outputDoc.pages = pages;
      await _writeDocument(outputDoc, outputPath);

      // Rasterizing text/vector PDFs can produce a file that is larger than the
      // original. In that case, keep the original so "compress" never inflates
      // the file.
      final inputSize = await File(inputPath).length();
      final outputFile = File(outputPath);
      final outputSize = await outputFile.length();
      if (outputSize >= inputSize) {
        await File(inputPath).copy(outputPath);
      }

      onProgress?.call(doc.pages.length, doc.pages.length, 'Done');
      return outputPath;
    } finally {
      for (final d in pageDocs) {
        d.dispose();
      }
      doc.dispose();
      outputDoc?.dispose();
    }
  }

  Future<String?> renderThumbnail(
    String pdfPath, {
    required String outputPath,
    double dpi = 72,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    PdfDocument? doc;
    try {
      doc = await _openFile(pdfPath);
      if (doc.pages.isEmpty) return null;

      final page = doc.pages.first;
      final scale = dpi / 72.0;
      final rendered = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (rendered == null) return null;

      final image = rendered.createImageNF();
      rendered.dispose();
      final jpegBytes = await encodeJpegFromImageInIsolate(image, quality: 70);
      await File(outputPath).writeAsBytes(jpegBytes);
      return outputPath;
    } finally {
      doc?.dispose();
    }
  }

  Future<int> pageCount(String inputPath) async {
    await PdfrxInitializer.ensureInitialized();
    final doc = await _openFile(inputPath);
    try {
      return doc.pages.length;
    } finally {
      doc.dispose();
    }
  }

  Future<PdfDocument> _openFile(String path, {String? password}) {
    return PdfDocument.openFile(
      path,
      passwordProvider: password == null ? null : () => password,
    );
  }

  Future<void> _writeDocument(
    PdfDocument doc,
    String outputPath, {
    bool removeSecurity = false,
    PdfProgressCallback? onProgress,
  }) async {
    onProgress?.call(0, 1, 'Saving PDF…');
    final bytes = await doc.encodePdf(removeSecurity: removeSecurity);
    await File(outputPath).writeAsBytes(bytes);
  }

  List<List<int>> _buildSplitRanges({
    required int totalPages,
    required SplitMode mode,
    List<int>? selectedPages,
    required int pagesPerFile,
  }) {
    switch (mode) {
      case SplitMode.everyNPages:
        final ranges = <List<int>>[];
        for (var start = 1; start <= totalPages; start += pagesPerFile) {
          final end = (start + pagesPerFile - 1).clamp(1, totalPages);
          ranges.add([for (var p = start; p <= end; p++) p]);
        }
        return ranges;
      case SplitMode.extractSelected:
        if (selectedPages == null || selectedPages.isEmpty) {
          throw const PdfProcessingException('No pages selected.');
        }
        return [selectedPages];
      case SplitMode.singlePages:
        return [
          for (var p = 1; p <= totalPages; p++) [p],
        ];
    }
  }
}

enum SplitMode { everyNPages, extractSelected, singlePages }
