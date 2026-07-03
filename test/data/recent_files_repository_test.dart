import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/data/local/database/app_database.dart';
import 'package:pdf_toolkit/data/local/file_storage_service.dart';
import 'package:pdf_toolkit/data/repositories/recent_files_repository.dart';
import 'package:pdf_toolkit/domain/entities/pdf_feature.dart';
import 'package:pdf_toolkit/services/pdf/pdf_service.dart';
import 'dart:io';

void main() {
  late AppDatabase db;
  late RecentFilesRepository repository;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recent_repo_test');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RecentFilesRepository(
      db,
      FileStorageService(),
      PdfService(),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
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

  test('removeFromRecent deletes history but keeps file', () async {
    final pdf = File('${tempDir.path}/keep.pdf');
    await pdf.writeAsBytes(List<int>.filled(8, 0));

    await db.insertRecentFile(
      RecentFilesCompanion.insert(
        id: 'entry-1',
        displayName: 'keep.pdf',
        path: pdf.path,
        sizeBytes: 8,
        createdAt: DateTime(2026, 1, 1),
        sourceFeature: PdfFeatureType.merge.name,
      ),
    );

    await repository.removeFromRecent('entry-1');

    expect(await pdf.exists(), isTrue);
    expect(await repository.getRecentFiles(), isEmpty);
  });

  test('deleteFileAndRemoveFromRecent deletes file and history', () async {
    final pdf = File('${tempDir.path}/delete-me.pdf');
    await pdf.writeAsBytes(List<int>.filled(8, 0));

    await db.insertRecentFile(
      RecentFilesCompanion.insert(
        id: 'entry-2',
        displayName: 'delete-me.pdf',
        path: pdf.path,
        sizeBytes: 8,
        createdAt: DateTime(2026, 1, 1),
        sourceFeature: PdfFeatureType.merge.name,
      ),
    );

    final deleted = await repository.deleteFileAndRemoveFromRecent('entry-2');

    expect(deleted, isTrue);
    expect(await pdf.exists(), isFalse);
    expect(await repository.getRecentFiles(), isEmpty);
  });

  test('renameRecentFile preserves pdf extension', () async {
    final pdf = File('${tempDir.path}/processed/original.pdf');
    await pdf.parent.create(recursive: true);
    await pdf.writeAsBytes(List<int>.filled(8, 0));

    await db.insertRecentFile(
      RecentFilesCompanion.insert(
        id: 'entry-3',
        displayName: 'original.pdf',
        path: pdf.path,
        sizeBytes: 8,
        createdAt: DateTime(2026, 1, 1),
        sourceFeature: PdfFeatureType.merge.name,
      ),
    );

    await repository.renameRecentFile(id: 'entry-3', newName: 'renamed');

    final rows = await repository.getRecentFiles();
    expect(rows.single.displayName, 'renamed.pdf');
    expect(await File('${tempDir.path}/processed/renamed.pdf').exists(), isTrue);
  });
}
