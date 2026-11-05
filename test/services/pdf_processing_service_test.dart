import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/errors/app_exception.dart';
import 'package:pdf_toolkit/domain/entities/pdf_page_operation.dart';
import 'package:pdf_toolkit/domain/entities/pdf_job.dart';
import 'package:pdf_toolkit/domain/entities/pdf_stamp_placement.dart';
import 'package:pdf_toolkit/services/pdf/pdf_processing_service.dart';
import 'package:pdf_toolkit/services/pdf/pdf_service.dart' as pdf;
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

  test('organizePages validates every unique source PDF', () async {
    final fakeSave = _FakeFileSaveService();
    final service = PdfProcessingService(_FakePdfService(), fakeSave);

    await service.organizePages(
      operations: const [
        PdfPageOperation(sourcePath: 'first.pdf', pageNumber: 1),
        PdfPageOperation(sourcePath: 'first.pdf', pageNumber: 2),
        PdfPageOperation(sourcePath: 'second.pdf', pageNumber: 1),
      ],
      suggestedName: 'organized.pdf',
    );

    expect(
      fakeSave.validatedPaths,
      unorderedEquals(['first.pdf', 'second.pdf']),
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

  test(
    'visual signing requires acknowledgement for existing signatures',
    () async {
      final fakeService = _FakePdfService(signatureCount: 1);
      final fakeSave = _FakeFileSaveService();
      final service = PdfProcessingService(fakeService, fakeSave);

      await expectLater(
        () => service.applyVisualStamps(
          inputPath: 'signed.pdf',
          placements: [_validPlacement()],
          suggestedName: 'signed_copy.pdf',
        ),
        throwsA(isA<ExistingPdfSignaturesException>()),
      );
      expect(fakeService.stampCallCount, 0);
      expect(fakeSave.createdPaths, isEmpty);
    },
  );

  test('visual signing cleans its temp output after cancellation', () async {
    final fakeService = _FakePdfService(cancelDuringStamp: true);
    final fakeSave = _FakeFileSaveService();
    final service = PdfProcessingService(fakeService, fakeSave);

    await expectLater(
      () => service.applyVisualStamps(
        inputPath: 'source.pdf',
        placements: [_validPlacement()],
        suggestedName: 'signed_copy.pdf',
        cancellationToken: PdfCancellationToken(),
      ),
      throwsA(isA<PdfOperationCancelledException>()),
    );
    expect(fakeSave.deletedPaths, contains('/tmp/signed_copy.pdf'));
  });
}

PdfStampPlacement _validPlacement() => PdfStampPlacement(
  pageNumber: 1,
  left: 0.1,
  top: 0.1,
  width: 0.3,
  height: 0.1,
  pngBytes: Uint8List.fromList(const [1, 2, 3]),
);

class _FakePdfService extends pdf.PdfService {
  _FakePdfService({
    this.throwInvalidPassword = false,
    this.signatureCount = 0,
    this.cancelDuringStamp = false,
  });

  final bool throwInvalidPassword;
  final int signatureCount;
  final bool cancelDuringStamp;
  int stampCallCount = 0;

  @override
  Future<String> organizePages({
    required List<PdfPageOperation> operations,
    required String outputPath,
    pdf.PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async => outputPath;

  @override
  Future<String> removePassword({
    required String inputPath,
    required String password,
    required String outputPath,
    PdfCancellationToken? cancellationToken,
  }) async {
    if (throwInvalidPassword) throw const InvalidPasswordException();
    return outputPath;
  }

  @override
  Future<int> digitalSignatureCount(String inputPath) async => signatureCount;

  @override
  Future<String> applyVisualStamps({
    required String inputPath,
    required String outputPath,
    required List<PdfStampPlacement> placements,
    pdf.PdfProgressCallback? onProgress,
    PdfCancellationToken? cancellationToken,
  }) async {
    stampCallCount++;
    if (cancelDuringStamp) {
      cancellationToken?.cancel();
      cancellationToken?.throwIfCancelled();
    }
    return outputPath;
  }
}

class _FakeFileSaveService extends FileSaveService {
  final deletedPaths = <String>[];
  final validatedPaths = <String>[];
  final createdPaths = <String>[];

  @override
  void validateSourceFile(String path) => validatedPaths.add(path);

  @override
  Future<bool> isValidPdf(String path) async => true;

  @override
  Future<String> createTempOutputPath(String baseName) async {
    final path = '/tmp/$baseName';
    createdPaths.add(path);
    return path;
  }

  @override
  Future<void> deleteTempFile(String path) async {
    deletedPaths.add(path);
  }
}
