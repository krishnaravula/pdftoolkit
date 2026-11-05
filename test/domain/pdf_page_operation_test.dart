import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_toolkit/domain/entities/pdf_page_operation.dart';

void main() {
  test('quarter turns are normalized for PDF rotation', () {
    expect(
      const PdfPageOperation(
        sourcePath: 'source.pdf',
        pageNumber: 1,
        clockwiseQuarterTurns: 5,
      ).normalizedQuarterTurns,
      1,
    );
    expect(
      const PdfPageOperation(
        sourcePath: 'source.pdf',
        pageNumber: 1,
        clockwiseQuarterTurns: -1,
      ).normalizedQuarterTurns,
      3,
    );
  });
}
