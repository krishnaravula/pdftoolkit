import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/pdf_job.dart';

class PdfJobRunner {
  final PdfCancellationToken _cancellationToken = PdfCancellationToken();

  void cancel() => _cancellationToken.cancel();

  void reset() => _cancellationToken.reset();

  Future<T> run<T>({
    required StreamController<PdfJobProgress> progress,
    required Future<T> Function(PdfProgressReporter reporter) task,
  }) async {
    _cancellationToken.reset();
    progress.add(const PdfJobProgress(status: PdfJobStatus.running));

    final reporter = PdfProgressReporter(
      progress: progress,
      cancellationToken: _cancellationToken,
    );

    try {
      final result = await task(reporter);
      _cancellationToken.throwIfCancelled();
      progress.add(
        PdfJobProgress(status: PdfJobStatus.success, message: 'Complete'),
      );
      return result;
    } on PdfOperationCancelledException {
      progress.add(const PdfJobProgress(status: PdfJobStatus.cancelled));
      rethrow;
    } catch (e) {
      debugPrint('PdfJobRunner failed.');
      progress.add(
        PdfJobProgress(status: PdfJobStatus.failure, error: e.toString()),
      );
      rethrow;
    }
  }
}

class PdfProgressReporter {
  PdfProgressReporter({
    required this.progress,
    required this.cancellationToken,
  });

  final StreamController<PdfJobProgress> progress;
  final PdfCancellationToken cancellationToken;

  void update(int current, int total, String message) {
    if (cancellationToken.isCancelled) return;
    progress.add(
      PdfJobProgress(
        status: PdfJobStatus.running,
        currentStep: current,
        totalSteps: total,
        message: message,
      ),
    );
  }

  void complete(String outputPath) {
    progress.add(
      PdfJobProgress(
        status: PdfJobStatus.success,
        outputPath: outputPath,
        message: 'Complete',
      ),
    );
  }

  void checkCancelled() {
    cancellationToken.throwIfCancelled();
  }
}

typedef PdfProgressCallback =
    void Function(int current, int total, String message);
