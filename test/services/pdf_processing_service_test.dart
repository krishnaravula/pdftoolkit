import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/errors/app_exception.dart';
import 'package:pdf_toolkit/services/pdf/pdf_processing_service.dart';
import 'package:pdf_toolkit/services/pdf/pdf_service.dart';
import 'package:pdf_toolkit/services/storage/file_save_service.dart';

void main() {
  test(
    'validatePdfsExist throws when less than two files are selected',
    () async {
      final service = PdfProcessingService(
        _FakePdfService(),
        _FakeFileSaveService(),
      );

      await expectLater(
        () => service.validatePdfsExist(['one.pdf']),
        throwsA(isA<PdfProcessingException>()),
      );
    },
  );

  test('imagesToPdf throws when no images are supplied', () async {
    final service = PdfProcessingService(
      _FakePdfService(),
      _FakeFileSaveService(),
    );

    await expectLater(
      () => service.imagesToPdf([], suggestedName: 'out.pdf'),
      throwsA(isA<PdfProcessingException>()),
    );
  });

  test('reorderOrDeletePages throws when no pages are supplied', () async {
    final service = PdfProcessingService(
      _FakePdfService(),
      _FakeFileSaveService(),
    );

    await expectLater(
      () => service.reorderOrDeletePages(
        inputPath: 'sample.pdf',
        pageOrderOneBased: const [],
        suggestedName: 'out.pdf',
      ),
      throwsA(isA<PdfProcessingException>()),
    );
  });

  test('removePassword deletes temp output when password is invalid', () async {
    final fakeSave = _FakeFileSaveService();
    final service = PdfProcessingService(
      _FakePdfService(throwInvalidPassword: true),
      fakeSave,
    );

    await expectLater(
      () => service.removePassword(
        inputPath: 'locked.pdf',
        password: 'bad-pass',
        suggestedName: 'unlocked.pdf',
      ),
      throwsA(isA<InvalidPasswordException>()),
    );

    expect(fakeSave.deletedPaths, contains('/tmp/unlocked.pdf'));
  });
}

class _FakePdfService extends PdfService {
  _FakePdfService({this.throwInvalidPassword = false});

  final bool throwInvalidPassword;

  @override
  Future<String> removePassword({
    required String inputPath,
    required String password,
    required String outputPath,
  }) async {
    if (throwInvalidPassword) throw const InvalidPasswordException();
    return outputPath;
  }
}

class _FakeFileSaveService extends FileSaveService {
  final deletedPaths = <String>[];

  @override
  void validateSourceFile(String path) {}

  @override
  Future<bool> isValidPdf(String path) async => true;

  @override
  Future<String> createTempOutputPath(String baseName) async =>
      '/tmp/$baseName';

  @override
  Future<void> deleteTempFile(String path) async {
    deletedPaths.add(path);
  }
}
