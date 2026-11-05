/// Describes one output page in the unified page organizer.
///
/// Repeating an operation duplicates a page; changing the order reorders it.
class PdfPageOperation {
  const PdfPageOperation({
    required this.sourcePath,
    required this.pageNumber,
    this.clockwiseQuarterTurns = 0,
  });

  final String sourcePath;
  final int pageNumber;
  final int clockwiseQuarterTurns;

  int get normalizedQuarterTurns => ((clockwiseQuarterTurns % 4) + 4) % 4;
}
