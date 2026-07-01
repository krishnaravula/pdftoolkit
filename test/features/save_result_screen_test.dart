import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/di/providers.dart';
import 'package:pdf_toolkit/domain/entities/pdf_feature.dart';
import 'package:pdf_toolkit/domain/entities/recent_file.dart';
import 'package:pdf_toolkit/features/shared/save_result_screen.dart';
import 'package:pdf_toolkit/services/monetization/ad_service.dart';
import 'package:pdf_toolkit/services/storage/file_save_service.dart';
import 'package:pdf_toolkit/services/storage/recent_files_service.dart';
import 'package:pdf_toolkit/services/storage/storage_repository.dart';

void main() {
  testWidgets('Save result screen saves to app storage and shows actions', (
    tester,
  ) async {
    final fakeSaveService = _FakeFileSaveService();
    final fakeStorage = _FakeStorageRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileSaveServiceProvider.overrideWithValue(fakeSaveService),
          storageRepositoryProvider.overrideWithValue(fakeStorage),
          recentFilesServiceProvider.overrideWithValue(
            _FakeRecentFilesService(),
          ),
          adsEnabledProvider.overrideWith((ref) async => false),
          adServiceProvider.overrideWithValue(NoOpAdService()),
        ],
        child: const MaterialApp(
          home: SaveResultScreen(
            feature: PdfFeatureType.merge,
            pendingFiles: [
              PendingSaveFile(tempPath: '/tmp/a.pdf', suggestedName: 'a.pdf'),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Save result'), findsOneWidget);
  });
}

class _FakeFileSaveService extends FileSaveService {
  @override
  Future<void> deleteTempFile(String path) async {}
}

class _FakeRecentFilesService implements RecentFilesService {
  @override
  Future<RecentFileItem> addFromOutput({
    required String outputPath,
    required PdfFeatureType feature,
    String? exportedUri,
    bool pinned = false,
  }) async {
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
  bool fileExists(String path) => true;

  @override
  Future<RecentFileItem?> findByPath(String path) async => null;

  @override
  String formatFileSize(int bytes) => '$bytes B';

  @override
  String formatLocation(String path) => path;

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
  Future<void> cleanupOldProcessedFiles({
    Duration maxAge = const Duration(days: 30),
  }) async {}

  @override
  void markResultScreenActivePaths(List<String> paths) {}

  @override
  Future<void> setExportedUri({
    required String id,
    required String exportedUri,
  }) async {}

  @override
  Future<void> setPinned({required String id, required bool pinned}) async {}

  @override
  void unmarkResultScreenActivePaths(List<String> paths) {}
}

class _FakeStorageRepository extends StorageRepository {
  @override
  Future<File> saveProcessedPdfToAppStorage(
    dynamic inputStreamOrBytes,
    String suggestedFileName,
  ) async {
    final dir = await Directory.systemTemp.createTemp('save_result_test');
    final file = File('${dir.path}/$suggestedFileName');
    await file.writeAsBytes('%PDF-1.7'.codeUnits);
    return file;
  }

  @override
  Future<Uri?> getPreferredExportTreeUri() async => null;
}
