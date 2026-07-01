import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/config/env.dart';
import 'package:pdf_toolkit/core/di/providers.dart';
import 'package:pdf_toolkit/domain/entities/pdf_feature.dart';
import 'package:pdf_toolkit/domain/entities/recent_file.dart';
import 'package:pdf_toolkit/services/storage/recent_files_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_toolkit/app.dart';

void main() {
  testWidgets('Home screen shows PDF tools', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentFilesServiceProvider.overrideWithValue(
            _FakeRecentFilesService(),
          ),
          recentFilesStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: const PdfToolkitApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Env.appName), findsOneWidget);
    expect(find.text('Merge PDF'), findsOneWidget);
    expect(find.text('Scan to PDF'), findsOneWidget);
  });
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
      displayName: outputPath,
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
