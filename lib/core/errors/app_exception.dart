sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class PdfProcessingException extends AppException {
  const PdfProcessingException(super.message);
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
