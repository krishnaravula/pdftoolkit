import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_exception.dart';
import '../../core/utils/error_messages.dart';
import '../../domain/entities/pdf_job.dart';
import '../../domain/entities/pdf_page_operation.dart';
import '../../domain/entities/pdf_stamp_placement.dart';
import '../storage/file_save_service.dart';
import 'pdf_service.dart';

export 'pdf_service.dart' show SplitMode;

typedef PdfProgressCallback =
    void Function(int current, int total, String message);

/// Facade over [PdfService] with validation, temp outputs, and error handling.
class PdfProcessingService {
  PdfProcessingService(this._pdfService, this._fileSave);

  final PdfService _pdfService;
  final FileSaveService _fileSave;

  Future<void> validatePdfExists(String path) async {
    _fileSave.validateSourceFile(path);
    if (!await _fileSave.isValidPdf(path)) {
      throw const PdfProcessingException(
        'The selected file is not a valid PDF.',
      );
    }
  }

  Future<void> validatePdfsExist(List<String> paths) async {
    if (paths.length < 2) {
      throw const PdfProcessingException('Select at least two PDF files.');
    }
    for (final path in paths) {
      await validatePdfExists(path);
    }
  }

  Future<String> mergePdfs(
    List<String> inputPaths, {
    required String suggestedName,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    await validatePdfsExist(inputPaths);
    final outputPath = await _fileSave.createTempOutputPath(suggestedName);

    try {
      return await _pdfService.mergePdfs(
        inputPaths,
        outputPath: outputPath,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
    } catch (e) {
      debugPrint('PdfProcessingService.mergePdfs failed.');
      await _fileSave.deleteTempFile(outputPath);
      if (e is PdfOperationCancelledException) rethrow;
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<List<PendingSaveFile>> splitPdf(
    String inputPath, {
    required SplitMode mode,
    List<int>? selectedPages,
    int pagesPerFile = 1,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    await validatePdfExists(inputPath);

    final tempDir = p.dirname(
      await _fileSave.createTempOutputPath('split.pdf'),
    );
    final stem = p.basenameWithoutExtension(inputPath);

    try {
      final outputs = await _pdfService.splitPdf(
        inputPath,
        mode: mode,
        outputDirectory: tempDir,
        selectedPages: selectedPages,
        pagesPerFile: pagesPerFile,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
        namePrefix: stem,
      );

      return [
        for (var i = 0; i < outputs.length; i++)
          PendingSaveFile(
            tempPath: outputs[i],
            suggestedName: _splitSuggestedName(stem, mode, i, outputs.length),
          ),
      ];
    } catch (e) {
      debugPrint('PdfProcessingService.splitPdf failed.');
      if (e is PdfOperationCancelledException) rethrow;
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<String> compressPdf({
    required String inputPath,
    required String suggestedName,
    required CompressionQuality quality,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    await validatePdfExists(inputPath);
    final outputPath = await _fileSave.createTempOutputPath(suggestedName);

    try {
      return await _pdfService.compressPdf(
        inputPath: inputPath,
        outputPath: outputPath,
        quality: quality,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
    } catch (e) {
      debugPrint('PdfProcessingService.compressPdf failed.');
      await _fileSave.deleteTempFile(outputPath);
      if (e is PdfOperationCancelledException) rethrow;
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<String> imagesToPdf(
    List<String> imagePaths, {
    required String suggestedName,
    int jpegQuality = 85,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    if (imagePaths.isEmpty) {
      throw const PdfProcessingException('Select at least one image.');
    }
    for (final path in imagePaths) {
      _fileSave.validateSourceFile(path);
    }

    final outputPath = await _fileSave.createTempOutputPath(suggestedName);

    try {
      return await _pdfService.imagesToPdf(
        imagePaths,
        outputPath: outputPath,
        jpegQuality: jpegQuality,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
    } catch (e) {
      debugPrint('PdfProcessingService.imagesToPdf failed.');
      await _fileSave.deleteTempFile(outputPath);
      if (e is PdfOperationCancelledException) rethrow;
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<String> reorderOrDeletePages({
    required String inputPath,
    required List<int> pageOrderOneBased,
    required String suggestedName,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    return organizePages(
      operations: [
        for (final pageNumber in pageOrderOneBased)
          PdfPageOperation(sourcePath: inputPath, pageNumber: pageNumber),
      ],
      suggestedName: suggestedName,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<String> organizePages({
    required List<PdfPageOperation> operations,
    required String suggestedName,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    if (operations.isEmpty) {
      throw const PdfProcessingException('No pages to save.');
    }
    for (final sourcePath
        in operations.map((operation) => operation.sourcePath).toSet()) {
      await validatePdfExists(sourcePath);
    }

    final outputPath = await _fileSave.createTempOutputPath(suggestedName);

    try {
      return await _pdfService.organizePages(
        operations: operations,
        outputPath: outputPath,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
    } catch (e) {
      debugPrint('PdfProcessingService.organizePages failed.');
      await _fileSave.deleteTempFile(outputPath);
      if (e is PdfOperationCancelledException) rethrow;
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<String> removePassword({
    required String inputPath,
    required String password,
    required String suggestedName,
    PdfCancellationToken? cancellationToken,
  }) async {
    _fileSave.validateSourceFile(inputPath);
    final outputPath = await _fileSave.createTempOutputPath(suggestedName);

    try {
      return await _pdfService.removePassword(
        inputPath: inputPath,
        password: password,
        outputPath: outputPath,
        cancellationToken: cancellationToken,
      );
    } on InvalidPasswordException {
      await _fileSave.deleteTempFile(outputPath);
      rethrow;
    } catch (e) {
      debugPrint('PdfProcessingService.removePassword failed.');
      await _fileSave.deleteTempFile(outputPath);
      if (e is PdfOperationCancelledException) rethrow;
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<int> pageCount(String inputPath) async {
    await validatePdfExists(inputPath);
    return _pdfService.pageCount(inputPath);
  }

  Future<int> digitalSignatureCount(String inputPath) async {
    await validatePdfExists(inputPath);
    return _pdfService.digitalSignatureCount(inputPath);
  }

  Future<String> applyVisualStamps({
    required String inputPath,
    required List<PdfStampPlacement> placements,
    required String suggestedName,
    bool acknowledgeExistingSignatures = false,
    PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    await validatePdfExists(inputPath);
    if (placements.isEmpty) {
      throw const PdfProcessingException('Add a signature or date first.');
    }
    for (final placement in placements) {
      if (placement.pageNumber < 1 ||
          placement.left < 0 ||
          placement.top < 0 ||
          placement.width <= 0 ||
          placement.height <= 0 ||
          placement.left + placement.width > 1 ||
          placement.top + placement.height > 1 ||
          placement.pngBytes.isEmpty) {
        throw const PdfProcessingException('A signature placement is invalid.');
      }
    }

    cancellationToken?.throwIfCancelled();
    final signatureCount = await _pdfService.digitalSignatureCount(inputPath);
    if (signatureCount > 0 && !acknowledgeExistingSignatures) {
      throw ExistingPdfSignaturesException(signatureCount);
    }

    final outputPath = await _fileSave.createTempOutputPath(suggestedName);
    try {
      return await _pdfService.applyVisualStamps(
        inputPath: inputPath,
        outputPath: outputPath,
        placements: placements,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
    } catch (e) {
      debugPrint('PdfProcessingService.applyVisualStamps failed.');
      await _fileSave.deleteTempFile(outputPath);
      if (e is PdfOperationCancelledException) rethrow;
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  String _splitSuggestedName(
    String stem,
    SplitMode mode,
    int index,
    int total,
  ) {
    if (mode == SplitMode.singlePages) {
      return '${stem}_page_${index + 1}.pdf';
    }
    if (total == 1) return '$stem.pdf';
    return '${stem}_part_${index + 1}.pdf';
  }
}
