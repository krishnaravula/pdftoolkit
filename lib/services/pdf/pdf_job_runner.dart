import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/pdf_job.dart';

class PdfJobRunner {
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  void reset() => _cancelled = false;

  Future<T> run<T>({
    required StreamController<PdfJobProgress> progress,
    required Future<T> Function(PdfProgressReporter reporter) task,
  }) async {
    _cancelled = false;
    progress.add(const PdfJobProgress(status: PdfJobStatus.running));

    final reporter = PdfProgressReporter(
      progress: progress,
      isCancelled: () => _cancelled,
    );

    try {
      final result = await task(reporter);
      if (_cancelled) {
        progress.add(const PdfJobProgress(status: PdfJobStatus.cancelled));
      } else {
        progress.add(
          PdfJobProgress(status: PdfJobStatus.success, message: 'Complete'),
        );
      }
      return result;
    } catch (e, st) {
      debugPrint('PdfJobRunner error: $e\n$st');
      progress.add(
        PdfJobProgress(status: PdfJobStatus.failure, error: e.toString()),
      );
      rethrow;
    }
  }
}

class PdfProgressReporter {
  PdfProgressReporter({required this.progress, required this.isCancelled});

  final StreamController<PdfJobProgress> progress;
  final bool Function() isCancelled;

  void update(int current, int total, String message) {
    if (isCancelled()) return;
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
    if (isCancelled()) {
      throw StateError('cancelled');
    }
  }
}

typedef PdfProgressCallback =
    void Function(int current, int total, String message);
