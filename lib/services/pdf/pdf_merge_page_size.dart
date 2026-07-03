/// Target page-size policy for PDF merge normalization.
///
/// Kept deliberately small and extensible so that additional strategies (custom
/// sizes, fit-to-largest, etc.) can be added without touching the merge engine.

/// How merged pages should be sized.
enum MergePageSizeMode {
  /// Use the size of the first page of the first input PDF (default).
  firstPageOfFirstPdf,

  /// Force US Letter (612 x 792 points).
  letter,

  /// Force ISO A4 (595.28 x 841.89 points).
  a4,

  /// Keep every page at its original size (no normalization).
  preserveOriginal,
}

/// A concrete target page size in PDF points.
class TargetPageSize {
  const TargetPageSize(this.width, this.height);

  final double width;
  final double height;

  /// US Letter.
  static const TargetPageSize letter = TargetPageSize(612, 792);

  /// ISO A4.
  static const TargetPageSize a4 = TargetPageSize(595.28, 841.89);

  @override
  String toString() => 'TargetPageSize(${width}x$height)';
}

/// Resolves the concrete output size for [mode].
///
/// [firstPageSize] is the size of the first page of the first input PDF, used
/// when [mode] is [MergePageSizeMode.firstPageOfFirstPdf].
///
/// Returns `null` for [MergePageSizeMode.preserveOriginal], signalling that no
/// normalization should be applied.
TargetPageSize? resolveTargetPageSize(
  MergePageSizeMode mode,
  TargetPageSize firstPageSize,
) {
  switch (mode) {
    case MergePageSizeMode.firstPageOfFirstPdf:
      return firstPageSize;
    case MergePageSizeMode.letter:
      return TargetPageSize.letter;
    case MergePageSizeMode.a4:
      return TargetPageSize.a4;
    case MergePageSizeMode.preserveOriginal:
      return null;
  }
}
