import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/file_utils.dart';
import '../../domain/entities/pdf_feature.dart';

class StorageRepository {
  static const MethodChannel _channel = MethodChannel('pdf_toolkit/storage');
  static const String _preferredTreeUriKey = 'preferred_export_tree_uri';
  final _reservedOutputPaths = <String>{};

  /// Set [keepSource] when the caller will delete the input after recording
  /// the saved copy. It only applies to [File] inputs.
  Future<File> saveProcessedPdfToAppStorage(
    dynamic inputStreamOrBytes,
    String suggestedFileName, {
    bool keepSource = false,
  }) async {
    final baseRoot = await getApplicationDocumentsDirectory();
    final baseDir = Directory(p.join(baseRoot.path, 'processed'));
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    final sanitized = ensurePdfFileName(suggestedFileName);
    final outputPath = _uniquePath(baseDir.path, sanitized);
    final file = File(outputPath);
    _reservedOutputPaths.add(outputPath);
    try {
      if (inputStreamOrBytes is List<int>) {
        await file.writeAsBytes(inputStreamOrBytes, flush: true);
        return file;
      }

      if (inputStreamOrBytes is Stream<List<int>>) {
        await inputStreamOrBytes.pipe(file.openWrite());
        return file;
      }

      if (inputStreamOrBytes is File) {
        if (keepSource) return await inputStreamOrBytes.copy(outputPath);
        try {
          return await inputStreamOrBytes.rename(outputPath);
        } on FileSystemException {
          await inputStreamOrBytes.copy(outputPath);
          await inputStreamOrBytes.delete();
          return file;
        }
      }

      throw const FileAccessException('Unsupported PDF input payload.');
    } catch (_) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        debugPrint('Could not remove a partial PDF copy.');
      }
      rethrow;
    } finally {
      _reservedOutputPaths.remove(outputPath);
    }
  }

  Future<Uri> exportPdfToTreeUri(
    Uri treeUri,
    File sourceFile,
    String outputFileName,
  ) async {
    try {
      final normalized = ensurePdfFileName(outputFileName);
      final uri = await _channel
          .invokeMethod<String>('exportPdfToTreeUri', <String, dynamic>{
            'treeUri': treeUri.toString(),
            'sourceFilePath': sourceFile.path,
            'outputFileName': normalized,
          });
      if (uri == null || uri.isEmpty) {
        throw const FileAccessException('Folder export failed.');
      }
      return Uri.parse(uri);
    } catch (_) {
      debugPrint('StorageRepository.exportPdfToTreeUri failed.');
      rethrow;
    }
  }

  Future<Uri> exportPdfToDocuments(
    File sourceFile,
    String outputFileName,
  ) async {
    try {
      final normalized = ensurePdfFileName(outputFileName);
      final uri = await _channel.invokeMethod<String>(
        'exportPdfToDocuments',
        <String, dynamic>{
          'sourceFilePath': sourceFile.path,
          'outputFileName': normalized,
        },
      );
      if (uri == null || uri.isEmpty) {
        throw const FileAccessException('Documents export failed.');
      }
      return Uri.parse(uri);
    } catch (_) {
      debugPrint('StorageRepository.exportPdfToDocuments failed.');
      rethrow;
    }
  }

  Future<bool> hasPersistedWritePermission(Uri treeUri) async {
    final value = await _channel.invokeMethod<bool>(
      'hasPersistedWritePermission',
      <String, dynamic>{'treeUri': treeUri.toString()},
    );
    return value ?? false;
  }

  Future<void> persistTreeUriPermission(Uri treeUri) async {
    await _channel.invokeMethod<void>(
      'persistTreeUriPermission',
      <String, dynamic>{'treeUri': treeUri.toString()},
    );
  }

  Future<Uri?> getPreferredExportTreeUri() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_preferredTreeUriKey);
    if (value == null || value.isEmpty) return null;
    return Uri.tryParse(value);
  }

  Future<void> setPreferredExportTreeUri(Uri? uri) async {
    final prefs = await SharedPreferences.getInstance();
    if (uri == null) {
      await prefs.remove(_preferredTreeUriKey);
      return;
    }
    await prefs.setString(_preferredTreeUriKey, uri.toString());
  }

  Future<Uri?> pickExportTreeUri() async {
    final value = await _channel.invokeMethod<String>('pickExportTreeUri');
    if (value == null || value.isEmpty) return null;
    return Uri.parse(value);
  }

  String ensurePdfFileName(String name) {
    final sanitized = FileUtils.sanitizeFileName(name.trim());
    final finalName = sanitized.isEmpty ? 'document' : sanitized;
    if (finalName.toLowerCase().endsWith('.pdf')) {
      return finalName;
    }
    return '$finalName.pdf';
  }

  String defaultFileNameForFeature(PdfFeatureType feature) {
    final ts = _timestamp();
    return switch (feature) {
      PdfFeatureType.merge => 'merged_$ts.pdf',
      PdfFeatureType.compress => 'compressed_$ts.pdf',
      PdfFeatureType.split => 'split_part_001.pdf',
      PdfFeatureType.imageToPdf => 'converted_$ts.pdf',
      PdfFeatureType.scan => 'scan_$ts.pdf',
      PdfFeatureType.pageEditor => 'reordered_$ts.pdf',
      PdfFeatureType.removePassword => 'unlocked_$ts.pdf',
      PdfFeatureType.eSign => 'signed_$ts.pdf',
    };
  }

  String displayNameForTreeUri(Uri uri) {
    if (uri.pathSegments.isEmpty) return 'Selected folder';
    final decoded = Uri.decodeComponent(uri.pathSegments.last);
    final separator = decoded.lastIndexOf(':');
    if (separator >= 0 && separator < decoded.length - 1) {
      return decoded.substring(separator + 1);
    }
    return decoded.isEmpty ? 'Selected folder' : decoded;
  }

  String _timestamp() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }

  String _uniquePath(String directory, String fileName) {
    final stem = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName).isEmpty ? '.pdf' : p.extension(fileName);
    var i = 0;
    while (true) {
      final candidate = i == 0 ? '$stem$ext' : '${stem}_$i$ext';
      final path = p.join(directory, candidate);
      if (!_reservedOutputPaths.contains(path) && !File(path).existsSync()) {
        return path;
      }
      i++;
    }
  }
}
