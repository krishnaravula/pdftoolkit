import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/recent_files.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [RecentFiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 3) {
        await migrator.addColumn(recentFiles, recentFiles.exportedUri);
        await migrator.addColumn(recentFiles, recentFiles.pinned);
      }
      if (from < 4) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS recent_files_created_at '
          'ON recent_files (created_at)',
        );
      }
    },
  );

  Future<List<RecentFile>> getAllRecentFiles() {
    return (select(
      recentFiles,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  Stream<List<RecentFile>> watchRecentFiles() {
    return (select(
      recentFiles,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Future<void> insertRecentFile(RecentFilesCompanion entry) {
    return into(recentFiles).insertOnConflictUpdate(entry);
  }

  Future<void> deleteRecentFile(String id) {
    return (delete(recentFiles)..where((t) => t.id.equals(id))).go();
  }

  Future<RecentFile?> getRecentFile(String id) {
    return (select(
      recentFiles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pdf_toolkit.db'));
    return NativeDatabase.createInBackground(file);
  });
}
