import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf_toolkit/core/di/providers.dart';
import 'package:pdf_toolkit/domain/entities/pdf_feature.dart';
import 'package:pdf_toolkit/domain/entities/recent_file.dart';
import 'package:pdf_toolkit/features/recent_files/recent_files_screen.dart';
import 'package:pdf_toolkit/services/share/share_service.dart';
import 'package:pdf_toolkit/services/storage/recent_files_service.dart';

void main() {
  testWidgets('Recent files screen shows empty state', (tester) async {
    final fakeRecentFilesService = _FakeRecentFilesService();
    final fakeShareService = _FakeShareService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentFilesServiceProvider.overrideWithValue(fakeRecentFilesService),
          shareServiceProvider.overrideWithValue(fakeShareService),
          recentFilesStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(home: RecentFilesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Recent files'), findsOneWidget);
    expect(find.text('No recent PDFs yet.'), findsOneWidget);
  });

  testWidgets('Recent files screen renders streamed file name', (tester) async {
    final fakeRecentFilesService = _FakeRecentFilesService();
    final fakeShareService = _FakeShareService();
    final files = [
      RecentFileItem(
        id: '1',
        displayName: 'sample.pdf',
        path: '/tmp/sample.pdf',
        sizeBytes: 1024,
        createdAt: DateTime(2026, 1, 1),
        sourceFeature: PdfFeatureType.merge,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentFilesServiceProvider.overrideWithValue(fakeRecentFilesService),
          shareServiceProvider.overrideWithValue(fakeShareService),
          recentFilesStreamProvider.overrideWith((ref) => Stream.value(files)),
        ],
        child: const MaterialApp(home: RecentFilesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('sample.pdf'), findsOneWidget);
  });
}

class _FakeShareService extends ShareService {
  @override
  Future<void> shareFile(String path, {String? subject}) async {}

  @override
  Future<OpenResult> openFile(String path) async {
    return OpenResult(type: ResultType.done, message: 'ok');
  }
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
      id: 'new',
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
