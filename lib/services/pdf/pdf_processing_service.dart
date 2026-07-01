import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_exception.dart';
import '../../core/utils/error_messages.dart';
import '../../domain/entities/pdf_job.dart';
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
  }) async {
    await validatePdfsExist(inputPaths);
    final outputPath = await _fileSave.createTempOutputPath(suggestedName);

    try {
      return await _pdfService.mergePdfs(
        inputPaths,
        outputPath: outputPath,
        onProgress: onProgress,
      );
    } catch (e, st) {
      debugPrint('PdfProcessingService.mergePdfs error: $e\n$st');
      await _fileSave.deleteTempFile(outputPath);
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<List<PendingSaveFile>> splitPdf(
    String inputPath, {
    required SplitMode mode,
    List<int>? selectedPages,
    int pagesPerFile = 1,
    PdfProgressCallback? onProgress,
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
        namePrefix: stem,
      );

      return [
        for (var i = 0; i < outputs.length; i++)
          PendingSaveFile(
            tempPath: outputs[i],
            suggestedName: _splitSuggestedName(stem, mode, i, outputs.length),
          ),
      ];
    } catch (e, st) {
      debugPrint('PdfProcessingService.splitPdf error: $e\n$st');
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<String> compressPdf({
    required String inputPath,
    required String suggestedName,
    required CompressionQuality quality,
    PdfProgressCallback? onProgress,
  }) async {
    await validatePdfExists(inputPath);
    final outputPath = await _fileSave.createTempOutputPath(suggestedName);

    try {
      return await _pdfService.compressPdf(
        inputPath: inputPath,
        outputPath: outputPath,
        quality: quality,
        onProgress: onProgress,
      );
    } catch (e, st) {
      debugPrint('PdfProcessingService.compressPdf error: $e\n$st');
      await _fileSave.deleteTempFile(outputPath);
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<String> imagesToPdf(
    List<String> imagePaths, {
    required String suggestedName,
    PdfProgressCallback? onProgress,
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
        onProgress: onProgress,
      );
    } catch (e, st) {
      debugPrint('PdfProcessingService.imagesToPdf error: $e\n$st');
      await _fileSave.deleteTempFile(outputPath);
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<String> reorderOrDeletePages({
    required String inputPath,
    required List<int> pageOrderOneBased,
    required String suggestedName,
    PdfProgressCallback? onProgress,
  }) async {
    await validatePdfExists(inputPath);
    if (pageOrderOneBased.isEmpty) {
      throw const PdfProcessingException('No pages to save.');
    }

    final outputPath = await _fileSave.createTempOutputPath(suggestedName);

    try {
      return await _pdfService.reorderOrDeletePages(
        inputPath: inputPath,
        pageOrderOneBased: pageOrderOneBased,
        outputPath: outputPath,
        onProgress: onProgress,
      );
    } catch (e, st) {
      debugPrint('PdfProcessingService.reorderOrDeletePages error: $e\n$st');
      await _fileSave.deleteTempFile(outputPath);
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<String> removePassword({
    required String inputPath,
    required String password,
    required String suggestedName,
  }) async {
    _fileSave.validateSourceFile(inputPath);
    final outputPath = await _fileSave.createTempOutputPath(suggestedName);

    try {
      return await _pdfService.removePassword(
        inputPath: inputPath,
        password: password,
        outputPath: outputPath,
      );
    } on InvalidPasswordException {
      await _fileSave.deleteTempFile(outputPath);
      rethrow;
    } catch (e, st) {
      debugPrint('PdfProcessingService.removePassword error: $e\n$st');
      await _fileSave.deleteTempFile(outputPath);
      throw PdfProcessingException(userFriendlyError(e));
    }
  }

  Future<int> pageCount(String inputPath) async {
    await validatePdfExists(inputPath);
    return _pdfService.pageCount(inputPath);
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
