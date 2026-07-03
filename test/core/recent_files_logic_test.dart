import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/core/utils/recent_files_logic.dart';
import 'package:pdf_toolkit/domain/entities/app_settings.dart';
import 'package:pdf_toolkit/domain/entities/pdf_feature.dart';
import 'package:pdf_toolkit/domain/entities/recent_file.dart';

RecentFileItem _file({
  required String id,
  required String name,
  required DateTime createdAt,
  int sizeBytes = 1000,
}) {
  return RecentFileItem(
    id: id,
    displayName: name,
    path: '/tmp/$name',
    sizeBytes: sizeBytes,
    createdAt: createdAt,
    sourceFeature: PdfFeatureType.merge,
  );
}

void main() {
  final older = _file(
    id: '1',
    name: 'alpha.pdf',
    createdAt: DateTime(2026, 1, 1),
    sizeBytes: 500,
  );
  final newer = _file(
    id: '2',
    name: 'beta.pdf',
    createdAt: DateTime(2026, 6, 1),
    sizeBytes: 2000,
  );
  final files = [older, newer];

  test('filterRecentFilesByQuery is case-insensitive', () {
    final result = filterRecentFilesByQuery(files, 'BETA');
    expect(result, hasLength(1));
    expect(result.single.displayName, 'beta.pdf');
  });

  test('sortRecentFiles newest first', () {
    final sorted = sortRecentFiles(files, RecentFilesSort.newest);
    expect(sorted.first.id, '2');
  });

  test('sortRecentFiles oldest first', () {
    final sorted = sortRecentFiles(files, RecentFilesSort.oldest);
    expect(sorted.first.id, '1');
  });

  test('sortRecentFiles by filename', () {
    final sorted = sortRecentFiles(files, RecentFilesSort.name);
    expect(sorted.first.displayName, 'alpha.pdf');
  });

  test('sortRecentFiles by file size', () {
    final sorted = sortRecentFiles(files, RecentFilesSort.size);
    expect(sorted.first.sizeBytes, 2000);
  });

  test('mapFileAccessibility missing when file does not exist', () {
    expect(
      mapFileAccessibility(exists: false),
      RecentFileAccessibility.missing,
    );
  });

  test('validateRenameFilename rejects empty names', () {
    expect(validateRenameFilename(''), isNotNull);
    expect(validateRenameFilename('   '), isNotNull);
  });

  test('validateRenameFilename rejects invalid characters', () {
    expect(validateRenameFilename('bad/name'), isNotNull);
  });

  test('ensurePdfExtension preserves and adds extension', () {
    expect(ensurePdfExtension('report'), 'report.pdf');
    expect(ensurePdfExtension('report.PDF'), 'report.PDF');
  });

  test('renameInputFromDisplayName strips pdf extension', () {
    expect(renameInputFromDisplayName('merged.pdf'), 'merged');
  });
}
