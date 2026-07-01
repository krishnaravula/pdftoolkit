import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/utils/file_utils.dart';

void main() {
  test('sanitizeFileName removes invalid characters', () {
    expect(FileUtils.sanitizeFileName('a/b:c.pdf'), 'a_b_c.pdf');
  });

  test('uniqueOutputName adds timestamp', () {
    final name = FileUtils.uniqueOutputName('merged.pdf');
    expect(name.startsWith('merged_'), isTrue);
    expect(name.endsWith('.pdf'), isTrue);
  });

  test('uniqueOutputName defaults to .pdf when no extension is given', () {
    expect(FileUtils.uniqueOutputName('merged').endsWith('.pdf'), isTrue);
  });

  test('uniqueOutputPath joins the directory with a unique name', () {
    final path = FileUtils.uniqueOutputPath('/tmp/out', 'merged.pdf');
    expect(path.contains('merged_'), isTrue);
    expect(path.endsWith('.pdf'), isTrue);
  });

  test('tempFileName produces a uuid-based name with the extension', () {
    final name = FileUtils.tempFileName(extension: '.jpg');
    expect(name.endsWith('.jpg'), isTrue);
    expect(name.length, greaterThan('.jpg'.length));
  });
}
