import '../errors/app_exception.dart';

/// Maps technical errors to user-friendly messages.
String userFriendlyError(Object error) {
  if (error is AppException) return error.message;
  if (error is OutOfMemoryError) {
    return 'Not enough memory for this file. Try a smaller PDF or split it first.';
  }

  final text = error.toString().toLowerCase();
  if (text.contains('outofmemory') || text.contains('out of memory')) {
    return 'Not enough memory for this file. Try a smaller PDF or split it first.';
  }
  if (text.contains('cancelled') || text.contains('canceled')) {
    return 'Operation cancelled.';
  }
  if (text.contains('permission') || text.contains('denied')) {
    return 'Storage permission is required to save files.';
  }
  if (text.contains('no space') || text.contains('disk full')) {
    return 'Not enough storage space to save the file.';
  }
  if (text.contains('password')) {
    return 'Incorrect PDF password.';
  }
  if (text.contains('not found') || text.contains('no such file')) {
    return 'File not found. It may have been moved or deleted.';
  }
  if (text.contains('invalid') && text.contains('pdf')) {
    return 'The selected file is not a valid PDF.';
  }

  return 'Something went wrong. Please try again.';
}
