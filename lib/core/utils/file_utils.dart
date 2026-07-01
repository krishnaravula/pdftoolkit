import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class FileUtils {
  FileUtils._();

  static const _uuid = Uuid();

  static String uniqueOutputName(String baseName) {
    final ext = p.extension(baseName);
    final stem = p.basenameWithoutExtension(baseName);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${stem}_$stamp${ext.isEmpty ? '.pdf' : ext}';
  }

  static String uniqueOutputPath(String directory, String baseName) {
    return p.join(directory, uniqueOutputName(baseName));
  }

  static Future<void> ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static Future<int> fileSize(String path) async {
    return File(path).length();
  }

  static String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static String tempFileName({String extension = '.jpg'}) {
    return '${_uuid.v4()}$extension';
  }
}
