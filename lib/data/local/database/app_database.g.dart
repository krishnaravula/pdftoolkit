// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RecentFilesTable extends RecentFiles
    with TableInfo<$RecentFilesTable, RecentFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceFeatureMeta = const VerificationMeta(
    'sourceFeature',
  );
  @override
  late final GeneratedColumn<String> sourceFeature = GeneratedColumn<String>(
    'source_feature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exportedUriMeta = const VerificationMeta(
    'exportedUri',
  );
  @override
  late final GeneratedColumn<String> exportedUri = GeneratedColumn<String>(
    'exported_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    path,
    sizeBytes,
    createdAt,
    sourceFeature,
    thumbnailPath,
    exportedUri,
    pinned,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('source_feature')) {
      context.handle(
        _sourceFeatureMeta,
        sourceFeature.isAcceptableOrUnknown(
          data['source_feature']!,
          _sourceFeatureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceFeatureMeta);
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('exported_uri')) {
      context.handle(
        _exportedUriMeta,
        exportedUri.isAcceptableOrUnknown(
          data['exported_uri']!,
          _exportedUriMeta,
        ),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecentFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentFile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      sourceFeature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_feature'],
      )!,
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      exportedUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exported_uri'],
      ),
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
    );
  }

  @override
  $RecentFilesTable createAlias(String alias) {
    return $RecentFilesTable(attachedDatabase, alias);
  }
}

class RecentFile extends DataClass implements Insertable<RecentFile> {
  final String id;
  final String displayName;
  final String path;
  final int sizeBytes;
  final DateTime createdAt;
  final String sourceFeature;
  final String? thumbnailPath;
  final String? exportedUri;
  final bool pinned;
  const RecentFile({
    required this.id,
    required this.displayName,
    required this.path,
    required this.sizeBytes,
    required this.createdAt,
    required this.sourceFeature,
    this.thumbnailPath,
    this.exportedUri,
    required this.pinned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['path'] = Variable<String>(path);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['source_feature'] = Variable<String>(sourceFeature);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || exportedUri != null) {
      map['exported_uri'] = Variable<String>(exportedUri);
    }
    map['pinned'] = Variable<bool>(pinned);
    return map;
  }

  RecentFilesCompanion toCompanion(bool nullToAbsent) {
    return RecentFilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      path: Value(path),
      sizeBytes: Value(sizeBytes),
      createdAt: Value(createdAt),
      sourceFeature: Value(sourceFeature),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      exportedUri: exportedUri == null && nullToAbsent
          ? const Value.absent()
          : Value(exportedUri),
      pinned: Value(pinned),
    );
  }

  factory RecentFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentFile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      path: serializer.fromJson<String>(json['path']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      sourceFeature: serializer.fromJson<String>(json['sourceFeature']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      exportedUri: serializer.fromJson<String?>(json['exportedUri']),
      pinned: serializer.fromJson<bool>(json['pinned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'path': serializer.toJson<String>(path),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'sourceFeature': serializer.toJson<String>(sourceFeature),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'exportedUri': serializer.toJson<String?>(exportedUri),
      'pinned': serializer.toJson<bool>(pinned),
    };
  }

  RecentFile copyWith({
    String? id,
    String? displayName,
    String? path,
    int? sizeBytes,
    DateTime? createdAt,
    String? sourceFeature,
    Value<String?> thumbnailPath = const Value.absent(),
    Value<String?> exportedUri = const Value.absent(),
    bool? pinned,
  }) => RecentFile(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    path: path ?? this.path,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    createdAt: createdAt ?? this.createdAt,
    sourceFeature: sourceFeature ?? this.sourceFeature,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    exportedUri: exportedUri.present ? exportedUri.value : this.exportedUri,
    pinned: pinned ?? this.pinned,
  );
  RecentFile copyWithCompanion(RecentFilesCompanion data) {
    return RecentFile(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      path: data.path.present ? data.path.value : this.path,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sourceFeature: data.sourceFeature.present
          ? data.sourceFeature.value
          : this.sourceFeature,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      exportedUri: data.exportedUri.present
          ? data.exportedUri.value
          : this.exportedUri,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentFile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('path: $path, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('sourceFeature: $sourceFeature, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('exportedUri: $exportedUri, ')
          ..write('pinned: $pinned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    path,
    sizeBytes,
    createdAt,
    sourceFeature,
    thumbnailPath,
    exportedUri,
    pinned,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentFile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.path == this.path &&
          other.sizeBytes == this.sizeBytes &&
          other.createdAt == this.createdAt &&
          other.sourceFeature == this.sourceFeature &&
          other.thumbnailPath == this.thumbnailPath &&
          other.exportedUri == this.exportedUri &&
          other.pinned == this.pinned);
}

class RecentFilesCompanion extends UpdateCompanion<RecentFile> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> path;
  final Value<int> sizeBytes;
  final Value<DateTime> createdAt;
  final Value<String> sourceFeature;
  final Value<String?> thumbnailPath;
  final Value<String?> exportedUri;
  final Value<bool> pinned;
  final Value<int> rowid;
  const RecentFilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.path = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sourceFeature = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.exportedUri = const Value.absent(),
    this.pinned = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentFilesCompanion.insert({
    required String id,
    required String displayName,
    required String path,
    required int sizeBytes,
    required DateTime createdAt,
    required String sourceFeature,
    this.thumbnailPath = const Value.absent(),
    this.exportedUri = const Value.absent(),
    this.pinned = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       path = Value(path),
       sizeBytes = Value(sizeBytes),
       createdAt = Value(createdAt),
       sourceFeature = Value(sourceFeature);
  static Insertable<RecentFile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? path,
    Expression<int>? sizeBytes,
    Expression<DateTime>? createdAt,
    Expression<String>? sourceFeature,
    Expression<String>? thumbnailPath,
    Expression<String>? exportedUri,
    Expression<bool>? pinned,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (path != null) 'path': path,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (createdAt != null) 'created_at': createdAt,
      if (sourceFeature != null) 'source_feature': sourceFeature,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (exportedUri != null) 'exported_uri': exportedUri,
      if (pinned != null) 'pinned': pinned,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentFilesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? path,
    Value<int>? sizeBytes,
    Value<DateTime>? createdAt,
    Value<String>? sourceFeature,
    Value<String?>? thumbnailPath,
    Value<String?>? exportedUri,
    Value<bool>? pinned,
    Value<int>? rowid,
  }) {
    return RecentFilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      path: path ?? this.path,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      sourceFeature: sourceFeature ?? this.sourceFeature,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      exportedUri: exportedUri ?? this.exportedUri,
      pinned: pinned ?? this.pinned,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (sourceFeature.present) {
      map['source_feature'] = Variable<String>(sourceFeature.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (exportedUri.present) {
      map['exported_uri'] = Variable<String>(exportedUri.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentFilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('path: $path, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('sourceFeature: $sourceFeature, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('exportedUri: $exportedUri, ')
          ..write('pinned: $pinned, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RecentFilesTable recentFiles = $RecentFilesTable(this);
  late final Index recentFilesCreatedAt = Index(
    'recent_files_created_at',
    'CREATE INDEX recent_files_created_at ON recent_files (created_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recentFiles,
    recentFilesCreatedAt,
  ];
}

typedef $$RecentFilesTableCreateCompanionBuilder =
    RecentFilesCompanion Function({
      required String id,
      required String displayName,
      required String path,
      required int sizeBytes,
      required DateTime createdAt,
      required String sourceFeature,
      Value<String?> thumbnailPath,
      Value<String?> exportedUri,
      Value<bool> pinned,
      Value<int> rowid,
    });
typedef $$RecentFilesTableUpdateCompanionBuilder =
    RecentFilesCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> path,
      Value<int> sizeBytes,
      Value<DateTime> createdAt,
      Value<String> sourceFeature,
      Value<String?> thumbnailPath,
      Value<String?> exportedUri,
      Value<bool> pinned,
      Value<int> rowid,
    });

class $$RecentFilesTableFilterComposer
    extends Composer<_$AppDatabase, $RecentFilesTable> {
  $$RecentFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceFeature => $composableBuilder(
    column: $table.sourceFeature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exportedUri => $composableBuilder(
    column: $table.exportedUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentFilesTable> {
  $$RecentFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceFeature => $composableBuilder(
    column: $table.sourceFeature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exportedUri => $composableBuilder(
    column: $table.exportedUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentFilesTable> {
  $$RecentFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get sourceFeature => $composableBuilder(
    column: $table.sourceFeature,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exportedUri => $composableBuilder(
    column: $table.exportedUri,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);
}

class $$RecentFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentFilesTable,
          RecentFile,
          $$RecentFilesTableFilterComposer,
          $$RecentFilesTableOrderingComposer,
          $$RecentFilesTableAnnotationComposer,
          $$RecentFilesTableCreateCompanionBuilder,
          $$RecentFilesTableUpdateCompanionBuilder,
          (
            RecentFile,
            BaseReferences<_$AppDatabase, $RecentFilesTable, RecentFile>,
          ),
          RecentFile,
          PrefetchHooks Function()
        > {
  $$RecentFilesTableTableManager(_$AppDatabase db, $RecentFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> sourceFeature = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String?> exportedUri = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentFilesCompanion(
                id: id,
                displayName: displayName,
                path: path,
                sizeBytes: sizeBytes,
                createdAt: createdAt,
                sourceFeature: sourceFeature,
                thumbnailPath: thumbnailPath,
                exportedUri: exportedUri,
                pinned: pinned,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String path,
                required int sizeBytes,
                required DateTime createdAt,
                required String sourceFeature,
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String?> exportedUri = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentFilesCompanion.insert(
                id: id,
                displayName: displayName,
                path: path,
                sizeBytes: sizeBytes,
                createdAt: createdAt,
                sourceFeature: sourceFeature,
                thumbnailPath: thumbnailPath,
                exportedUri: exportedUri,
                pinned: pinned,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentFilesTable,
      RecentFile,
      $$RecentFilesTableFilterComposer,
      $$RecentFilesTableOrderingComposer,
      $$RecentFilesTableAnnotationComposer,
      $$RecentFilesTableCreateCompanionBuilder,
      $$RecentFilesTableUpdateCompanionBuilder,
      (
        RecentFile,
        BaseReferences<_$AppDatabase, $RecentFilesTable, RecentFile>,
      ),
      RecentFile,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RecentFilesTableTableManager get recentFiles =>
      $$RecentFilesTableTableManager(_db, _db.recentFiles);
}
