import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/config/env.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/file_utils.dart';

/// A file awaiting user confirmation before final save.
class PendingSaveFile {
  const PendingSaveFile({required this.tempPath, required this.suggestedName});

  final String tempPath;
  final String suggestedName;
}

/// Centralized temp-output and validation logic for all PDF tools.
class FileSaveService {
  Future<String> createTempOutputPath(String baseName) async {
    final tempRoot = await _tempDirectory();
    final sanitized = FileUtils.sanitizeFileName(baseName);
    final finalName = sanitized.toLowerCase().endsWith('.pdf')
        ? sanitized
        : '$sanitized.pdf';

    return FileUtils.uniqueOutputPath(tempRoot, finalName);
  }

  Future<void> deleteTempFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, st) {
      debugPrint('FileSaveService.deleteTempFile error: $e\n$st');
    }
  }

  void validateSourceFile(String path) {
    if (path.trim().isEmpty) {
      throw const FileAccessException('Invalid file path.');
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw FileAccessException('File not found: ${p.basename(path)}');
    }
  }

  void validateDirectory(String path) {
    if (path.trim().isEmpty) {
      throw const FileAccessException('Invalid save location.');
    }
  }

  Future<bool> isValidPdf(String path) async {
    try {
      validateSourceFile(path);
      final file = File(path);
      if (await file.length() < 5) return false;
      final header = await file.openRead(0, 5).first;
      return String.fromCharCodes(header).startsWith('%PDF');
    } catch (e, st) {
      debugPrint('FileSaveService.isValidPdf error: $e\n$st');
      return false;
    }
  }

  Future<String> _tempDirectory() async {
    final temp = await getTemporaryDirectory();
    final dir = p.join(temp.path, Env.tempDirName);
    await FileUtils.ensureDir(dir);
    return dir;
  }
}
