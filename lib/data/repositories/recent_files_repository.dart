import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/utils/file_utils.dart';
import '../../core/utils/recent_files_logic.dart';
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
      } catch (_) {
        debugPrint('RecentFilesRepository thumbnail generation failed.');
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
    if (row == null) {
      throw StateError('Recent file entry not found.');
    }

    final validationError = validateRenameFilename(newName);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final sanitized = ensurePdfExtension(FileUtils.sanitizeFileName(newName));
    final newPath = p.join(p.dirname(row.path), sanitized);
    final file = File(row.path);

    if (!await file.exists()) {
      throw StateError(
        'This file was moved, deleted, or is no longer available.',
      );
    }

    if (!_isAppManagedPath(row.path)) {
      throw UnsupportedError(
        'Renaming is not supported for files saved outside app storage.',
      );
    }

    if (newPath != row.path && await File(newPath).exists()) {
      throw StateError('A file with that name already exists.');
    }

    if (newPath != row.path) {
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

  Future<void> relinkRecentFile({
    required String id,
    required String newPath,
  }) async {
    final row = await _db.getRecentFile(id);
    if (row == null) return;

    final file = File(newPath);
    if (!await file.exists()) {
      throw StateError('Selected file does not exist.');
    }

    final size = await file.length();
    await _db.insertRecentFile(
      RecentFilesCompanion(
        id: drift.Value(id),
        displayName: drift.Value(p.basename(newPath)),
        path: drift.Value(newPath),
        sizeBytes: drift.Value(size),
        createdAt: drift.Value(row.createdAt),
        sourceFeature: drift.Value(row.sourceFeature),
        thumbnailPath: const drift.Value(null),
        exportedUri: drift.Value(row.exportedUri),
        pinned: drift.Value(row.pinned),
      ),
    );
    _generateThumbnailInBackground(id, newPath);
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

  /// Removes the history entry and thumbnail only; does not delete the PDF.
  Future<void> removeFromRecent(String id) async {
    final row = await _db.getRecentFile(id);
    if (row == null) return;
    await _deleteThumbnail(row.thumbnailPath);
    await _db.deleteRecentFile(id);
  }

  /// Deletes the actual PDF file, thumbnail, and history entry.
  Future<bool> deleteFileAndRemoveFromRecent(String id) async {
    final row = await _db.getRecentFile(id);
    if (row == null) return false;

    var deleted = false;
    final file = File(row.path);
    if (await file.exists()) {
      await file.delete();
      deleted = true;
    } else {
      deleted = true;
    }

    await _deleteThumbnail(row.thumbnailPath);
    await _db.deleteRecentFile(id);
    return deleted;
  }

  /// Backward-compatible alias for [deleteFileAndRemoveFromRecent].
  Future<void> deleteRecentFile(String id) async {
    await deleteFileAndRemoveFromRecent(id);
  }

  /// Clears recent-history entries and thumbnails without deleting PDF files.
  Future<void> clearRecentHistory() async {
    final rows = await _db.getAllRecentFiles();
    for (final row in rows) {
      await _deleteThumbnail(row.thumbnailPath);
      await _db.deleteRecentFile(row.id);
    }
  }

  Future<void> _deleteThumbnail(String? thumbnailPath) async {
    if (thumbnailPath == null) return;
    final thumb = File(thumbnailPath);
    if (await thumb.exists()) {
      await thumb.delete();
    }
  }

  bool _isAppManagedPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.contains('/processed/') ||
        normalized.endsWith('/processed') ||
        normalized.contains('PDF Tools');
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
