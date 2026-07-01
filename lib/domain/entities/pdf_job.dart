enum PdfJobStatus { idle, running, success, failure, cancelled }

class PdfJobProgress {
  const PdfJobProgress({
    required this.status,
    this.currentStep = 0,
    this.totalSteps = 1,
    this.message,
    this.outputPath,
    this.error,
  });

  final PdfJobStatus status;
  final int currentStep;
  final int totalSteps;
  final String? message;
  final String? outputPath;
  final String? error;

  double get fraction =>
      totalSteps == 0 ? 0 : currentStep.clamp(0, totalSteps) / totalSteps;

  PdfJobProgress copyWith({
    PdfJobStatus? status,
    int? currentStep,
    int? totalSteps,
    String? message,
    String? outputPath,
    String? error,
  }) {
    return PdfJobProgress(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      message: message ?? this.message,
      outputPath: outputPath ?? this.outputPath,
      error: error ?? this.error,
    );
  }
}

enum CompressionQuality { low, medium, high }

extension CompressionQualityX on CompressionQuality {
  int get jpegQuality => switch (this) {
    CompressionQuality.low => 40,
    CompressionQuality.medium => 65,
    CompressionQuality.high => 85,
  };

  double get renderDpi => switch (this) {
    CompressionQuality.low => 96,
    CompressionQuality.medium => 120,
    CompressionQuality.high => 150,
  };
}
