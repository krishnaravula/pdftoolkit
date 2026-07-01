import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/errors/app_exception.dart';
import 'package:pdf_toolkit/core/utils/error_messages.dart';

void main() {
  test('returns the message of an AppException directly', () {
    expect(
      userFriendlyError(const PdfProcessingException('Custom message')),
      'Custom message',
    );
  });

  test('maps out-of-memory text to a friendly message', () {
    expect(
      userFriendlyError(Exception('Caused by OutOfMemory while rendering')),
      contains('Not enough memory'),
    );
  });

  test('maps permission errors to a storage permission message', () {
    expect(
      userFriendlyError(Exception('Permission denied')),
      contains('permission'),
    );
  });

  test('maps missing-file errors to a not-found message', () {
    expect(
      userFriendlyError(Exception('No such file or directory')),
      contains('File not found'),
    );
  });

  test('maps invalid pdf errors to a friendly message', () {
    expect(
      userFriendlyError(Exception('invalid pdf structure')),
      'The selected file is not a valid PDF.',
    );
  });

  test('falls back to a generic message for unknown errors', () {
    expect(
      userFriendlyError(Exception('totally unexpected gremlin')),
      'Something went wrong. Please try again.',
    );
  });
}
