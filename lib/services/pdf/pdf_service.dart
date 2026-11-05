import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

import '../../core/errors/app_exception.dart';
import '../../core/pdf/pdfrx_initializer.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/image_processing.dart';
import '../../domain/entities/pdf_job.dart';
import '../../domain/entities/pdf_page_operation.dart';
import '../../domain/entities/pdf_stamp_placement.dart';
import 'pdf_merge_normalizer.dart';
import 'pdf_merge_page_size.dart';
import 'pdf_stamp_embedder.dart';

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
    PdfCancellationToken? cancellationToken,
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
        cancellationToken?.throwIfCancelled();
        sourceDocs.add(await _openFile(path));
      }
      cancellationToken?.throwIfCancelled();

      if (pageSizeMode == MergePageSizeMode.preserveOriginal) {
        // Keep the original per-page sizes: concatenate pages verbatim.
        final mergedPages = <PdfPage>[];
        for (var i = 0; i < sourceDocs.length; i++) {
          cancellationToken?.throwIfCancelled();
          mergedPages.addAll(sourceDocs[i].pages);
          onProgress?.call(
            i + 1,
            inputPaths.length + 1,
            'Merged ${i + 1}/${inputPaths.length}',
          );
          await Future<void>.delayed(Duration.zero);
        }
        outputDoc.pages = mergedPages;
      } else {
        // Normalize every page onto a uniform target size, preserving vector
        // content and text via form XObjects.
        await PdfMergeNormalizer.normalizeInto(
          sourceDocs: sourceDocs,
          outputDoc: outputDoc,
          mode: pageSizeMode,
          cancellationToken: cancellationToken,
        );
        cancellationToken?.throwIfCancelled();
        onProgress?.call(
          inputPaths.length,
          inputPaths.length + 1,
          'Normalizing pages…',
        );
      }

      await _writeDocument(
        outputDoc,
        outputPath,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
      return outputPath;
    } finally {
      for (final d in sourceDocs) {
        await d.dispose();
      }
      await outputDoc?.dispose();
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
    PdfCancellationToken? cancellationToken,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    final doc = await _openFile(inputPath);
    try {
      final totalPages = doc.pages.length;
      if (mode == SplitMode.everyNPages && pagesPerFile < 1) {
        throw const PdfProcessingException(
          'Pages per file must be greater than zero.',
        );
      }
      final ranges = _buildSplitRanges(
        totalPages: totalPages,
        mode: mode,
        selectedPages: selectedPages,
        pagesPerFile: pagesPerFile,
        cancellationToken: cancellationToken,
      );
      final totalParts = switch (mode) {
        SplitMode.singlePages => totalPages,
        SplitMode.everyNPages =>
          (totalPages + pagesPerFile - 1) ~/ pagesPerFile,
        SplitMode.extractSelected => 1,
      };

      final outputs = <String>[];
      try {
        var i = 0;
        for (final range in ranges) {
          cancellationToken?.throwIfCancelled();
          onProgress?.call(
            i,
            totalParts,
            'Splitting part ${i + 1}/$totalParts',
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
          try {
            await _writeDocument(
              partDoc,
              outputPath,
              cancellationToken: cancellationToken,
            );
            outputs.add(outputPath);
          } catch (_) {
            try {
              await File(outputPath).delete();
            } on FileSystemException {
              // The file may not have been created.
            }
            rethrow;
          } finally {
            await partDoc.dispose();
          }
          i++;
        }
        onProgress?.call(totalParts, totalParts, 'Done');
        return outputs;
      } catch (_) {
        for (final output in outputs) {
          try {
            await File(output).delete();
          } on FileSystemException {
            // Best-effort cleanup of partial split outputs.
          }
        }
        rethrow;
      }
    } finally {
      await doc.dispose();
    }
  }

  Future<String> reorderOrDeletePages({
    required String inputPath,
    required List<int> pageOrderOneBased,
    required String outputPath,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    return organizePages(
      operations: [
        for (final pageNumber in pageOrderOneBased)
          PdfPageOperation(sourcePath: inputPath, pageNumber: pageNumber),
      ],
      outputPath: outputPath,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<String> organizePages({
    required List<PdfPageOperation> operations,
    required String outputPath,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    final sourceDocs = <String, PdfDocument>{};
    PdfDocument? outputDoc;
    try {
      final sourcePaths = operations.map((operation) => operation.sourcePath);
      for (final sourcePath in sourcePaths.toSet()) {
        cancellationToken?.throwIfCancelled();
        sourceDocs[sourcePath] = await _openFile(sourcePath);
      }

      onProgress?.call(0, operations.length + 1, 'Applying page changes…');
      outputDoc = await PdfDocument.createNew(sourceName: outputPath);
      final outputPages = <PdfPage>[];
      for (var i = 0; i < operations.length; i++) {
        cancellationToken?.throwIfCancelled();
        final operation = operations[i];
        final sourceDoc = sourceDocs[operation.sourcePath]!;
        if (operation.pageNumber < 1 ||
            operation.pageNumber > sourceDoc.pages.length) {
          throw PdfProcessingException(
            'Page ${operation.pageNumber} is not available in the source PDF.',
          );
        }

        final sourcePage = sourceDoc.pages[operation.pageNumber - 1];
        final outputPage = switch (operation.normalizedQuarterTurns) {
          1 => sourcePage.rotatedCW90(),
          2 => sourcePage.rotated180(),
          3 => sourcePage.rotatedCCW90(),
          _ => sourcePage,
        };
        outputPages.add(outputPage);
        onProgress?.call(
          i + 1,
          operations.length + 1,
          'Preparing page ${i + 1}/${operations.length}',
        );
        await Future<void>.delayed(Duration.zero);
      }

      outputDoc.pages = outputPages;
      await _writeDocument(
        outputDoc,
        outputPath,
        cancellationToken: cancellationToken,
      );
      onProgress?.call(operations.length + 1, operations.length + 1, 'Done');
      return outputPath;
    } finally {
      for (final document in sourceDocs.values) {
        await document.dispose();
      }
      await outputDoc?.dispose();
    }
  }

  Future<String> removePassword({
    required String inputPath,
    required String password,
    required String outputPath,
    PdfCancellationToken? cancellationToken,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    PdfDocument? doc;
    try {
      cancellationToken?.throwIfCancelled();
      String? nextPassword = password;
      doc = await PdfDocument.openFile(
        inputPath,
        passwordProvider: () {
          final attempt = nextPassword;
          nextPassword = null;
          return attempt;
        },
      );
      await _writeDocument(
        doc,
        outputPath,
        removeSecurity: true,
        cancellationToken: cancellationToken,
      );
      return outputPath;
    } on PdfPasswordException {
      throw const InvalidPasswordException();
    } on PdfException {
      throw const PdfProcessingException(
        'Could not process this PDF. Check the file and try again.',
      );
    } finally {
      await doc?.dispose();
    }
  }

  Future<String> imagesToPdf(
    List<String> imagePaths, {
    required String outputPath,
    int jpegQuality = 85,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    PdfDocument? doc;
    final pageDocs = <PdfDocument>[];
    try {
      final pages = <PdfPage>[];
      for (var i = 0; i < imagePaths.length; i++) {
        cancellationToken?.throwIfCancelled();
        onProgress?.call(i, imagePaths.length, 'Processing image ${i + 1}');
        final file = File(imagePaths[i]);
        final rawBytes = await file.readAsBytes();
        final prepared = await prepareImageForPdfInIsolate(
          rawBytes,
          jpegQuality: jpegQuality,
        );

        final pageDoc = await PdfDocument.createFromJpegData(
          prepared.jpegBytes,
          width: prepared.width,
          height: prepared.height,
          sourceName: imagePaths[i],
        );
        pageDocs.add(pageDoc);
        pages.addAll(pageDoc.pages);
        await Future<void>.delayed(Duration.zero);
      }

      doc = await PdfDocument.createNew(sourceName: outputPath);
      doc.pages = pages;
      await _writeDocument(
        doc,
        outputPath,
        cancellationToken: cancellationToken,
      );
      onProgress?.call(imagePaths.length, imagePaths.length, 'Done');
      return outputPath;
    } finally {
      for (final d in pageDocs) {
        await d.dispose();
      }
      await doc?.dispose();
    }
  }

  Future<String> compressPdf({
    required String inputPath,
    required String outputPath,
    required CompressionQuality quality,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
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
        cancellationToken?.throwIfCancelled();
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
      await _writeDocument(
        outputDoc,
        outputPath,
        cancellationToken: cancellationToken,
      );

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
        await d.dispose();
      }
      await doc.dispose();
      await outputDoc?.dispose();
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
      await doc?.dispose();
    }
  }

  Future<int> pageCount(String inputPath) async {
    await PdfrxInitializer.ensureInitialized();
    final doc = await _openFile(inputPath);
    try {
      return doc.pages.length;
    } finally {
      await doc.dispose();
    }
  }

  Future<int> digitalSignatureCount(String inputPath) async {
    await PdfrxInitializer.ensureInitialized();
    final doc = await _openFile(inputPath);
    try {
      return await pdfDigitalSignatureCount(doc);
    } finally {
      await doc.dispose();
    }
  }

  Future<String> applyVisualStamps({
    required String inputPath,
    required String outputPath,
    required List<PdfStampPlacement> placements,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    await PdfrxInitializer.ensureInitialized();
    cancellationToken?.throwIfCancelled();
    final doc = await _openFile(inputPath);
    try {
      for (var i = 0; i < placements.length; i++) {
        cancellationToken?.throwIfCancelled();
        onProgress?.call(i, placements.length + 1, 'Adding mark ${i + 1}');
        await embedPdfStamp(document: doc, placement: placements[i]);
      }
      await doc.reloadPages();
      cancellationToken?.throwIfCancelled();
      onProgress?.call(placements.length, placements.length + 1, 'Saving PDF…');
      final bytes = await doc.encodePdf();
      cancellationToken?.throwIfCancelled();
      await File(outputPath).writeAsBytes(bytes);
      onProgress?.call(placements.length + 1, placements.length + 1, 'Done');
      return outputPath;
    } finally {
      await doc.dispose();
    }
  }

  Future<PdfDocument> _openFile(String path) => PdfDocument.openFile(path);

  Future<void> _writeDocument(
    PdfDocument doc,
    String outputPath, {
    bool removeSecurity = false,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    onProgress?.call(0, 1, 'Saving PDF…');
    final bytes = await doc.encodePdf(removeSecurity: removeSecurity);
    cancellationToken?.throwIfCancelled();
    await File(outputPath).writeAsBytes(bytes);
  }

  Iterable<List<int>> _buildSplitRanges({
    required int totalPages,
    required SplitMode mode,
    List<int>? selectedPages,
    required int pagesPerFile,
    PdfCancellationToken? cancellationToken,
  }) sync* {
    switch (mode) {
      case SplitMode.everyNPages:
        for (var start = 1; start <= totalPages; start += pagesPerFile) {
          cancellationToken?.throwIfCancelled();
          final end = (start + pagesPerFile - 1).clamp(1, totalPages);
          yield [for (var p = start; p <= end; p++) p];
        }
        return;
      case SplitMode.extractSelected:
        if (selectedPages == null || selectedPages.isEmpty) {
          throw const PdfProcessingException('No pages selected.');
        }
        if (selectedPages.any((page) => page < 1 || page > totalPages)) {
          throw const PdfProcessingException(
            'A selected page is not available in the source PDF.',
          );
        }
        yield selectedPages;
        return;
      case SplitMode.singlePages:
        for (var page = 1; page <= totalPages; page++) {
          cancellationToken?.throwIfCancelled();
          yield [page];
        }
        return;
    }
  }
}

enum SplitMode { everyNPages, extractSelected, singlePages }
