import 'package:drift/drift.dart';

@TableIndex(name: 'recent_files_created_at', columns: {#createdAt})
class RecentFiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get path => text()();
  IntColumn get sizeBytes => integer()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get sourceFeature => text()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get exportedUri => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
