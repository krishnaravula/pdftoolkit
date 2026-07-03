import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/data/local/database/app_database.dart';
import 'package:pdf_toolkit/data/local/file_storage_service.dart';
import 'package:pdf_toolkit/data/repositories/recent_files_repository.dart';
import 'package:pdf_toolkit/domain/entities/pdf_feature.dart';
import 'package:pdf_toolkit/services/pdf/pdf_service.dart';

void main() {
  late AppDatabase db;
  late RecentFilesRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RecentFilesRepository(
      db,
      FileStorageService(),
      PdfService(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('watchRecentFiles tolerates unknown source_feature values', () async {
    await db.insertRecentFile(
      RecentFilesCompanion.insert(
        id: 'legacy-row',
        displayName: 'legacy.pdf',
        path: '/tmp/legacy.pdf',
        sizeBytes: 12,
        createdAt: DateTime(2024, 1, 1),
        sourceFeature: 'unknown_feature',
      ),
    );

    final items = await repository.watchRecentFiles().first;
    expect(items, hasLength(1));
    expect(items.single.sourceFeature, PdfFeatureType.merge);
  });
}
