sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class PdfProcessingException extends AppException {
  const PdfProcessingException(super.message);
}

final class PdfOperationCancelledException extends AppException {
  const PdfOperationCancelledException() : super('Operation cancelled.');
}

final class ExistingPdfSignaturesException extends AppException {
  const ExistingPdfSignaturesException(this.signatureCount)
    : super('This PDF already has digital signatures.');

  final int signatureCount;
}

final class InvalidPasswordException extends AppException {
  const InvalidPasswordException() : super('Incorrect password.');
}

final class ScanException extends AppException {
  const ScanException(super.message);
}

final class FileAccessException extends AppException {
  const FileAccessException(super.message);
}
