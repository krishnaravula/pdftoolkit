import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf_toolkit/core/di/providers.dart';
import 'package:pdf_toolkit/data/local/app_preferences.dart';
import 'package:pdf_toolkit/domain/entities/pdf_feature.dart';
import 'package:pdf_toolkit/domain/entities/recent_file.dart';
import 'package:pdf_toolkit/features/recent_files/recent_files_screen.dart';
import 'package:pdf_toolkit/services/share/share_service.dart';
import 'package:pdf_toolkit/services/storage/recent_files_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Recent files screen shows empty state', (tester) async {
    final fakeRecentFilesService = _FakeRecentFilesService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentFilesServiceProvider.overrideWithValue(fakeRecentFilesService),
          shareServiceProvider.overrideWithValue(_FakeShareService()),
          recentFilesStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          appPreferencesProvider.overrideWith(
            (ref) async => AppPreferences(await SharedPreferences.getInstance()),
          ),
        ],
        child: const MaterialApp(home: RecentFilesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Recent files'), findsOneWidget);
    expect(find.text('No recent files'), findsOneWidget);
    expect(
      find.text('Files you create or open will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('Recent files screen renders streamed file name', (tester) async {
    final fakeRecentFilesService = _FakeRecentFilesService();
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
          shareServiceProvider.overrideWithValue(_FakeShareService()),
          recentFilesStreamProvider.overrideWith((ref) => Stream.value(files)),
          appPreferencesProvider.overrideWith(
            (ref) async => AppPreferences(await SharedPreferences.getInstance()),
          ),
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
  _FakeRecentFilesService();

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
  String formatLocationLabel(RecentFileItem file) => 'Saved in PDF Tools';

  @override
  String formatFullLocation(RecentFileItem file) => file.path;

  @override
  Future<List<RecentFileItem>> getRecentFiles() async => const [];

  @override
  Future<void> renameRecentFile({
    required String id,
    required String newName,
  }) async {}

  @override
  Future<void> relinkRecentFile({
    required String id,
    required String newPath,
  }) async {}

  @override
  Stream<List<RecentFileItem>> watchRecentFiles() => const Stream.empty();

  @override
  Future<void> cleanupOldProcessedFiles({
    Duration maxAge = const Duration(days: 30),
  }) async {}

  @override
  Future<int> calculateTemporaryFilesBytes() async => 0;

  @override
  Future<int> clearTemporaryFiles() async => 0;

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
