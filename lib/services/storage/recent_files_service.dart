import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/recent_file.dart';
import '../../data/repositories/recent_files_repository.dart';

/// Manages the recent-files list and related file operations.
class RecentFilesService {
  RecentFilesService(this._repository);

  final RecentFilesRepository _repository;
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

  Future<void> deleteRecentFile(String id) => _repository.deleteRecentFile(id);

  Future<void> renameRecentFile({
    required String id,
    required String newName,
  }) async {
    await _repository.renameRecentFile(id: id, newName: newName);
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
      await _repository.deleteRecentFile(item.id);
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String formatLocation(String path) {
    if (path.contains('${Platform.pathSeparator}processed')) {
      return 'App storage/processed';
    }
    return p.dirname(path);
  }

  bool fileExists(String path) => File(path).existsSync();
}
