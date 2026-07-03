import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/recent_file.dart';
import '../local/database/app_database.dart';
import '../local/file_storage_service.dart';
import '../../services/pdf/pdf_service.dart';

class RecentFilesRepository {
  RecentFilesRepository(this._db, this._storage, this._pdfService);

  final AppDatabase _db;
  final FileStorageService _storage;
  final PdfService _pdfService;
  static const _uuid = Uuid();

  Stream<List<RecentFileItem>> watchRecentFiles() {
    return _db.watchRecentFiles().map((rows) => rows.map(_mapRow).toList());
  }

  Future<List<RecentFileItem>> getRecentFiles() async {
    final rows = await _db.getAllRecentFiles();
    return rows.map(_mapRow).toList();
  }

  Future<RecentFileItem> addFromOutput({
    required String outputPath,
    required PdfFeatureType feature,
    String? exportedUri,
    bool pinned = false,
  }) async {
    final file = File(outputPath);
    if (!await file.exists()) {
      throw StateError('Output file does not exist: $outputPath');
    }

    final size = await file.length();
    final id = _uuid.v4();
    final displayName = p.basename(outputPath);

    final entry = RecentFilesCompanion(
      id: drift.Value(id),
      displayName: drift.Value(displayName),
      path: drift.Value(outputPath),
      sizeBytes: drift.Value(size),
      createdAt: drift.Value(DateTime.now()),
      sourceFeature: drift.Value(feature.name),
      thumbnailPath: const drift.Value(null),
      exportedUri: drift.Value(exportedUri),
      pinned: drift.Value(pinned),
    );

    await _db.insertRecentFile(entry);

    final item = RecentFileItem(
      id: id,
      displayName: displayName,
      path: outputPath,
      sizeBytes: size,
      createdAt: DateTime.now(),
      sourceFeature: feature,
      exportedUri: exportedUri,
      pinned: pinned,
    );

    _generateThumbnailInBackground(id, outputPath);
    return item;
  }

  void _generateThumbnailInBackground(String id, String outputPath) {
    Future(() async {
      try {
        final thumbDir = await _storage.thumbnailsDirectory;
        final thumbnailPath = p.join(thumbDir, '$id.jpg');
        await _pdfService.renderThumbnail(
          outputPath,
          outputPath: thumbnailPath,
        );

        final row = await _db.getRecentFile(id);
        if (row == null) return;

        await _db.insertRecentFile(
          RecentFilesCompanion(
            id: drift.Value(id),
            displayName: drift.Value(row.displayName),
            path: drift.Value(row.path),
            sizeBytes: drift.Value(row.sizeBytes),
            createdAt: drift.Value(row.createdAt),
            sourceFeature: drift.Value(row.sourceFeature),
            thumbnailPath: drift.Value(thumbnailPath),
            exportedUri: drift.Value(row.exportedUri),
            pinned: drift.Value(row.pinned),
          ),
        );
      } catch (e, st) {
        debugPrint('RecentFilesRepository thumbnail error: $e\n$st');
      }
    });
  }

  Future<RecentFileItem?> findByPath(String path) async {
    final rows = await _db.getAllRecentFiles();
    for (final row in rows) {
      if (row.path == path) return _mapRow(row);
    }
    return null;
  }

  Future<void> renameRecentFile({
    required String id,
    required String newName,
  }) async {
    final row = await _db.getRecentFile(id);
    if (row == null) return;

    final sanitized = newName.trim();
    if (sanitized.isEmpty) return;

    final newPath = p.join(p.dirname(row.path), sanitized);
    final file = File(row.path);
    if (await file.exists()) {
      await file.rename(newPath);
    }

    await _db.insertRecentFile(
      RecentFilesCompanion(
        id: drift.Value(id),
        displayName: drift.Value(sanitized),
        path: drift.Value(newPath),
        sizeBytes: drift.Value(row.sizeBytes),
        createdAt: drift.Value(row.createdAt),
        sourceFeature: drift.Value(row.sourceFeature),
        thumbnailPath: drift.Value(row.thumbnailPath),
        exportedUri: drift.Value(row.exportedUri),
        pinned: drift.Value(row.pinned),
      ),
    );
  }

  Future<void> setExportedUri({
    required String id,
    required String exportedUri,
  }) async {
    final row = await _db.getRecentFile(id);
    if (row == null) return;
    await _db.insertRecentFile(
      RecentFilesCompanion(
        id: drift.Value(row.id),
        displayName: drift.Value(row.displayName),
        path: drift.Value(row.path),
        sizeBytes: drift.Value(row.sizeBytes),
        createdAt: drift.Value(row.createdAt),
        sourceFeature: drift.Value(row.sourceFeature),
        thumbnailPath: drift.Value(row.thumbnailPath),
        exportedUri: drift.Value(exportedUri),
        pinned: drift.Value(row.pinned),
      ),
    );
  }

  Future<void> setPinned({required String id, required bool pinned}) async {
    final row = await _db.getRecentFile(id);
    if (row == null) return;
    await _db.insertRecentFile(
      RecentFilesCompanion(
        id: drift.Value(row.id),
        displayName: drift.Value(row.displayName),
        path: drift.Value(row.path),
        sizeBytes: drift.Value(row.sizeBytes),
        createdAt: drift.Value(row.createdAt),
        sourceFeature: drift.Value(row.sourceFeature),
        thumbnailPath: drift.Value(row.thumbnailPath),
        exportedUri: drift.Value(row.exportedUri),
        pinned: drift.Value(pinned),
      ),
    );
  }

  Future<void> deleteRecentFile(String id) async {
    final row = await _db.getRecentFile(id);
    if (row == null) return;

    final file = File(row.path);
    if (await file.exists()) {
      await file.delete();
    }

    if (row.thumbnailPath != null) {
      final thumb = File(row.thumbnailPath!);
      if (await thumb.exists()) {
        await thumb.delete();
      }
    }

    await _db.deleteRecentFile(id);
  }

  RecentFileItem _mapRow(RecentFile row) {
    return RecentFileItem(
      id: row.id,
      displayName: row.displayName,
      path: row.path,
      sizeBytes: row.sizeBytes,
      createdAt: row.createdAt,
      sourceFeature: _parseSourceFeature(row.sourceFeature),
      thumbnailPath: row.thumbnailPath,
      exportedUri: row.exportedUri,
      pinned: row.pinned,
    );
  }

  PdfFeatureType _parseSourceFeature(String value) {
    for (final feature in PdfFeatureType.values) {
      if (feature.name == value) return feature;
    }
    debugPrint('RecentFilesRepository: unknown source feature "$value"');
    return PdfFeatureType.merge;
  }
}
