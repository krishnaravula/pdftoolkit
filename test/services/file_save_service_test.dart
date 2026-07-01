import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/errors/app_exception.dart';
import 'package:pdf_toolkit/services/storage/file_save_service.dart';

void main() {
  test('validateDirectory rejects empty path', () {
    final service = FileSaveService();
    expect(
      () => service.validateDirectory('   '),
      throwsA(isA<FileAccessException>()),
    );
  });

  test('validateSourceFile rejects missing file', () {
    final service = FileSaveService();
    expect(
      () => service.validateSourceFile('missing.pdf'),
      throwsA(isA<FileAccessException>()),
    );
  });

  test('isValidPdf returns true for a valid pdf header', () async {
    final service = FileSaveService();
    final tempDir = await Directory.systemTemp.createTemp('pdf_toolkit_test');
    final file = File('${tempDir.path}/valid.pdf');
    await file.writeAsBytes('%PDF-1.7'.codeUnits);

    final result = await service.isValidPdf(file.path);

    expect(result, isTrue);
    await tempDir.delete(recursive: true);
  });

  test('isValidPdf returns false for non-pdf content', () async {
    final service = FileSaveService();
    final tempDir = await Directory.systemTemp.createTemp('pdf_toolkit_test');
    final file = File('${tempDir.path}/invalid.pdf');
    await file.writeAsBytes('HELLO'.codeUnits);

    final result = await service.isValidPdf(file.path);

    expect(result, isFalse);
    await tempDir.delete(recursive: true);
  });
}
