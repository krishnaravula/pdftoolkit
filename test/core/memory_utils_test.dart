import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/utils/memory_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('memory_utils_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('cleanupDirectory deletes files older than the cutoff', () async {
    final oldFile = File('${tempDir.path}/old.tmp')..writeAsStringSync('x');
    final newFile = File('${tempDir.path}/new.tmp')..writeAsStringSync('y');
    oldFile.setLastModifiedSync(
      DateTime.now().subtract(const Duration(days: 2)),
    );

    await MemoryUtils.cleanupDirectory(
      tempDir.path,
      maxAge: const Duration(days: 1),
    );

    expect(oldFile.existsSync(), isFalse);
    expect(newFile.existsSync(), isTrue);
  });

  test(
    'cleanupByTotalSize removes oldest files until under the limit',
    () async {
      for (var i = 0; i < 3; i++) {
        final file = File('${tempDir.path}/file_$i.bin')
          ..writeAsBytesSync(List<int>.filled(1000, 0));
        file.setLastModifiedSync(DateTime(2026, 1, 1 + i));
      }

      await MemoryUtils.cleanupByTotalSize(tempDir.path, maxSizeBytes: 1500);

      final remaining = tempDir.listSync().whereType<File>().toList();
      // Only the newest file fits under the 1500-byte cap.
      expect(remaining.length, 1);
      expect(remaining.single.path.endsWith('file_2.bin'), isTrue);
    },
  );

  test('cleanupDirectory is a no-op for a missing directory', () async {
    await MemoryUtils.cleanupDirectory('${tempDir.path}/does_not_exist');
  });
}
