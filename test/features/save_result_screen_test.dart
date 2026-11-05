import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/di/providers.dart';
import 'package:pdf_toolkit/domain/entities/pdf_feature.dart';
import 'package:pdf_toolkit/domain/entities/recent_file.dart';
import 'package:pdf_toolkit/features/shared/save_result_screen.dart';
import 'package:pdf_toolkit/services/storage/file_save_service.dart';
import 'package:pdf_toolkit/services/storage/recent_files_service.dart';
import 'package:pdf_toolkit/services/storage/storage_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Save result screen saves to app storage and shows actions', (
    tester,
  ) async {
    await _pumpSaveResult(
      tester,
      files: const [
        PendingSaveFile(tempPath: '/tmp/a.pdf', suggestedName: 'a.pdf'),
      ],
      fileSave: _FakeFileSaveService(),
      storage: _FakeStorageRepository(),
      recentFiles: _FakeRecentFilesService(),
    );

    await tester.pumpAndSettle();
    expect(find.text('Where should this PDF be saved?'), findsOneWidget);
    await tester.tap(find.text('Keep in PDF Tools only'));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Your PDF is ready'), findsOneWidget);
    expect(find.text('Open PDF'), findsOneWidget);
  });

  testWidgets(
    'Retry resumes after a partial save and preserves the pending input',
    (tester) async {
      final fileSave = _FakeFileSaveService();
      final storage = _FakeStorageRepository();
      final recentFiles = _FakeRecentFilesService()
        ..failOnceFor = '/saved/b.pdf';
      await _pumpSaveResult(
        tester,
        files: const [
          PendingSaveFile(tempPath: '/tmp/a.pdf', suggestedName: 'a.pdf'),
          PendingSaveFile(tempPath: '/tmp/b.pdf', suggestedName: 'b.pdf'),
        ],
        fileSave: fileSave,
        storage: storage,
        recentFiles: recentFiles,
      );
      await tester.pumpAndSettle();

      expect(find.text('Saved 1 of 2 PDFs'), findsOneWidget);
      expect(recentFiles.recorded, ['/saved/a.pdf']);
      expect(storage.discarded, ['/saved/b.pdf']);
      expect(fileSave.deleted, ['/tmp/a.pdf']);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep in PDF Tools only'));
      await tester.pumpAndSettle();

      expect(find.text('2 PDFs are ready'), findsOneWidget);
      expect(storage.copied, ['/tmp/a.pdf', '/tmp/b.pdf', '/tmp/b.pdf']);
      expect(recentFiles.recorded, ['/saved/a.pdf', '/saved/b.pdf']);
      expect(fileSave.deleted, ['/tmp/a.pdf', '/tmp/b.pdf']);
    },
  );
}

Future<void> _pumpSaveResult(
  WidgetTester tester, {
  required List<PendingSaveFile> files,
  required _FakeFileSaveService fileSave,
  required _FakeStorageRepository storage,
  required _FakeRecentFilesService recentFiles,
}) {
  SharedPreferences.setMockInitialValues({
    'pref_save_location': 'askEveryTime',
  });
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        fileSaveServiceProvider.overrideWithValue(fileSave),
        storageRepositoryProvider.overrideWithValue(storage),
        recentFilesServiceProvider.overrideWithValue(recentFiles),
      ],
      child: MaterialApp(
        home: SaveResultScreen(
          feature: PdfFeatureType.split,
          pendingFiles: files,
        ),
      ),
    ),
  );
}

class _FakeFileSaveService extends FileSaveService {
  final deleted = <String>[];

  @override
  Future<void> deleteTempFile(String path) async => deleted.add(path);
}

class _FakeRecentFilesService implements RecentFilesService {
  final recorded = <String>[];
  String? failOnceFor;

  @override
  Future<RecentFileItem> addFromOutput({
    required String outputPath,
    required PdfFeatureType feature,
    String? exportedUri,
    bool pinned = false,
  }) async {
    if (outputPath == failOnceFor) {
      failOnceFor = null;
      throw StateError('Recent write failed');
    }
    recorded.add(outputPath);
    return RecentFileItem(
      id: '1',
      displayName: outputPath.split('/').last,
      path: outputPath,
      sizeBytes: 0,
      createdAt: DateTime.now(),
      sourceFeature: feature,
    );
  }

  @override
  Future<void> addAllFromOutput({
    required List<String> outputPaths,
    required PdfFeatureType feature,
    String? exportedUri,
  }) async {}

  @override
  Future<void> deleteRecentFile(String id) async {}

  @override
  Future<bool> deleteFileAndRemoveFromRecent(String id) async => true;

  @override
  Future<void> removeFromRecent(String id) async {}

  @override
  Future<void> clearRecentHistory() async {}

  @override
  bool canRename(RecentFileItem file) => true;

  @override
  Future<bool> fileExists(String path) async => true;

  @override
  bool fileExistsSync(String path) => true;

  @override
  Future<RecentFileItem?> findByPath(String path) async => null;

  @override
  String formatFileSize(int bytes) => '$bytes B';

  @override
  String formatLocationLabel(RecentFileItem file) => file.path;

  @override
  String formatFullLocation(RecentFileItem file) => file.path;

  @override
  Future<void> relinkRecentFile({
    required String id,
    required String newPath,
  }) async {}

  @override
  Future<int> calculateTemporaryFilesBytes() async => 0;

  @override
  Future<int> clearTemporaryFiles() async => 0;

  @override
  Future<List<RecentFileItem>> getRecentFiles() async => const [];

  @override
  Future<void> renameRecentFile({
    required String id,
    required String newName,
  }) async {}

  @override
  Stream<List<RecentFileItem>> watchRecentFiles() => const Stream.empty();

  @override
  Future<void> setExportedUri({
    required String id,
    required String exportedUri,
  }) async {}

  @override
  Future<void> setPinned({required String id, required bool pinned}) async {}
}

class _FakeStorageRepository extends StorageRepository {
  final copied = <String>[];
  final discarded = <String>[];

  @override
  Future<File> saveProcessedPdfToAppStorage(
    dynamic inputStreamOrBytes,
    String suggestedFileName, {
    bool keepSource = false,
  }) async {
    expect(keepSource, isTrue);
    copied.add((inputStreamOrBytes as File).path);
    return _FakeSavedFile('/saved/$suggestedFileName', discarded);
  }

  @override
  Future<Uri?> getPreferredExportTreeUri() async => null;
}

class _FakeSavedFile implements File {
  _FakeSavedFile(this.path, this.discarded);

  @override
  final String path;
  final List<String> discarded;

  @override
  Future<File> delete({bool recursive = false}) async {
    discarded.add(path);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
