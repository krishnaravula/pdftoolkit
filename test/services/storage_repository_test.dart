import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/domain/entities/pdf_feature.dart';
import 'package:pdf_toolkit/services/storage/storage_repository.dart';

void main() {
  final repo = StorageRepository();

  group('ensurePdfFileName', () {
    test('appends .pdf when missing', () {
      expect(repo.ensurePdfFileName('report'), 'report.pdf');
    });

    test('keeps an existing .pdf extension (case-insensitive)', () {
      expect(repo.ensurePdfFileName('report.PDF'), 'report.PDF');
    });

    test('sanitizes illegal path characters', () {
      expect(repo.ensurePdfFileName('a/b:c'), 'a_b_c.pdf');
    });

    test('falls back to a default for an empty name', () {
      expect(repo.ensurePdfFileName('   '), 'document.pdf');
    });
  });

  group('defaultFileNameForFeature', () {
    test('produces a feature-specific .pdf name', () {
      final name = repo.defaultFileNameForFeature(PdfFeatureType.merge);
      expect(name.startsWith('merged_'), isTrue);
      expect(name.endsWith('.pdf'), isTrue);
    });

    test('split uses a stable numbered name', () {
      expect(
        repo.defaultFileNameForFeature(PdfFeatureType.split),
        'split_part_001.pdf',
      );
    });

    test('visual signing uses a signed output name', () {
      expect(
        repo.defaultFileNameForFeature(PdfFeatureType.eSign),
        startsWith('signed_'),
      );
    });

    test('every feature maps to a non-empty name', () {
      for (final feature in PdfFeatureType.values) {
        expect(repo.defaultFileNameForFeature(feature).isNotEmpty, isTrue);
      }
    });
  });

  group('displayNameForTreeUri', () {
    test('extracts an Android document-tree folder name', () {
      expect(
        repo.displayNameForTreeUri(
          Uri.parse('content://authority/tree/primary%3ADocuments%2FWork'),
        ),
        'Documents/Work',
      );
    });

    test('falls back for a URI without path segments', () {
      expect(
        repo.displayNameForTreeUri(Uri.parse('content://authority')),
        'Selected folder',
      );
    });
  });
}
