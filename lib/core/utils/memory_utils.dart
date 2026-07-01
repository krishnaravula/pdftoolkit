import 'dart:io';

class MemoryUtils {
  MemoryUtils._();

  static Future<void> cleanupDirectory(
    String directory, {
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return;

    final cutoff = DateTime.now().subtract(maxAge);
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final modified = await entity.lastModified();
      if (modified.isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }

  static Future<void> cleanupByTotalSize(
    String directory, {
    int maxSizeBytes = 500 * 1024 * 1024, // 500 MB
  }) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return;

    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        files.add(entity);
      }
    }

    // Sort by modification time, oldest first
    files.sort((a, b) {
      final aMod = a.lastModifiedSync();
      final bMod = b.lastModifiedSync();
      return aMod.compareTo(bMod);
    });

    var currentSize = 0;
    for (final file in files) {
      currentSize += await file.length();
    }

    for (final file in files) {
      if (currentSize <= maxSizeBytes) break;
      final size = await file.length();
      await file.delete();
      currentSize -= size;
    }
  }
}
