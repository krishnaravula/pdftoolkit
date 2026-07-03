import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/config/env.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/recent_file.dart';
import '../../data/repositories/recent_files_repository.dart';
import '../../data/local/file_storage_service.dart';

/// Manages the recent-files list and related file operations.
class RecentFilesService {
  RecentFilesService(this._repository, this._storage);

  final RecentFilesRepository _repository;
  final FileStorageService _storage;
  final Set<String> _activeResultPaths = <String>{};

  Stream<List<RecentFileItem>> watchRecentFiles() =>
      _repository.watchRecentFiles();

  Future<List<RecentFileItem>> getRecentFiles() => _repository.getRecentFiles();

  Future<RecentFileItem> addFromOutput({
    required String outputPath,
    required PdfFeatureType feature,
    String? exportedUri,
    bool pinned = false,
  }) async {
    try {
      return await _repository.addFromOutput(
        outputPath: outputPath,
        feature: feature,
        exportedUri: exportedUri,
        pinned: pinned,
      );
    } catch (e, st) {
      debugPrint('RecentFilesService.addFromOutput error: $e\n$st');
      rethrow;
    }
  }

  Future<void> addAllFromOutput({
    required List<String> outputPaths,
    required PdfFeatureType feature,
    String? exportedUri,
  }) async {
    for (final path in outputPaths) {
      await addFromOutput(
        outputPath: path,
        feature: feature,
        exportedUri: exportedUri,
      );
    }
  }

  Future<void> removeFromRecent(String id) => _repository.removeFromRecent(id);

  Future<bool> deleteFileAndRemoveFromRecent(String id) =>
      _repository.deleteFileAndRemoveFromRecent(id);

  Future<void> deleteRecentFile(String id) => _repository.deleteRecentFile(id);

  Future<void> clearRecentHistory() => _repository.clearRecentHistory();

  Future<void> renameRecentFile({
    required String id,
    required String newName,
  }) async {
    await _repository.renameRecentFile(id: id, newName: newName);
  }

  Future<void> relinkRecentFile({
    required String id,
    required String newPath,
  }) async {
    await _repository.relinkRecentFile(id: id, newPath: newPath);
  }

  Future<RecentFileItem?> findByPath(String path) =>
      _repository.findByPath(path);

  Future<void> setExportedUri({
    required String id,
    required String exportedUri,
  }) {
    return _repository.setExportedUri(id: id, exportedUri: exportedUri);
  }

  Future<void> setPinned({required String id, required bool pinned}) {
    return _repository.setPinned(id: id, pinned: pinned);
  }

  void markResultScreenActivePaths(List<String> paths) {
    _activeResultPaths.addAll(paths);
  }

  void unmarkResultScreenActivePaths(List<String> paths) {
    for (final path in paths) {
      _activeResultPaths.remove(path);
    }
  }

  Future<void> cleanupOldProcessedFiles({
    Duration maxAge = const Duration(days: 30),
  }) async {
    final all = await _repository.getRecentFiles();
    final cutoff = DateTime.now().subtract(maxAge);
    for (final item in all) {
      if (item.pinned) continue;
      if (_activeResultPaths.contains(item.path)) continue;
      if (item.createdAt.isAfter(cutoff)) continue;
      await _repository.deleteFileAndRemoveFromRecent(item.id);
    }
  }

  Future<int> calculateTemporaryFilesBytes() async {
    var total = 0;
    final tempDir = await _storage.tempDirectory;
    total += await _directorySize(tempDir);

    final thumbDir = await _storage.thumbnailsDirectory;
    total += await _directorySize(thumbDir);

    final cacheDir = Directory(
      p.join((await _storage.tempDirectory), '..', Env.tempDirName),
    );
    if (await cacheDir.exists()) {
      total += await _directorySize(cacheDir.path);
    }

    return total;
  }

  Future<int> clearTemporaryFiles() async {
    var cleared = 0;
    cleared += await _clearDirectory(await _storage.tempDirectory);
    cleared += await _clearDirectory(await _storage.thumbnailsDirectory);
    return cleared;
  }

  Future<int> _directorySize(String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<int> _clearDirectory(String directory) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return 0;
    var cleared = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        cleared += await entity.length();
        await entity.delete();
      }
    }
    return cleared;
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// User-facing location label for list cards (not raw paths).
  String formatLocationLabel(RecentFileItem file) {
    if (file.exportedUri != null) {
      return 'Saved to folder';
    }
    if (_isAppManagedPath(file.path)) {
      return 'Saved in PDF Tools';
    }
    return 'Saved on device';
  }

  /// Full location for file-details dialogs.
  String formatFullLocation(RecentFileItem file) {
    if (file.exportedUri != null) {
      return file.exportedUri!;
    }
    return file.path;
  }

  bool _isAppManagedPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.contains('/processed/') ||
        normalized.endsWith('/processed') ||
        normalized.contains(Env.appFolderName);
  }

  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  bool fileExistsSync(String path) => File(path).existsSync();

  bool canRename(RecentFileItem file) => _isAppManagedPath(file.path);
}
