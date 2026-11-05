enum PdfFeatureType {
  merge('Merge PDF', 'merge', 'Combine multiple PDFs into one'),
  split('Split PDF', 'split', 'Extract pages into separate files'),
  compress('Compress PDF', 'compress', 'Reduce PDF file size'),
  imageToPdf('Image to PDF', 'image_to_pdf', 'Convert photos to a PDF'),
  removePassword(
    'Remove Password',
    'remove_password',
    'Unlock a password-protected PDF',
  ),
  scan('Scan to PDF', 'scan', 'Camera scan with crop and filters'),
  pageEditor(
    'Organize Pages',
    'page_editor',
    'Reorder, rotate, duplicate, insert, or remove pages',
  ),
  eSign('Sign PDF', 'esign', 'Add a visual signature and date to a PDF');

  const PdfFeatureType(this.label, this.routeName, this.description);
  final String label;
  final String routeName;
  final String description;

  /// Past-tense label shown on recent-file cards.
  String get recentFilesLabel => switch (this) {
    PdfFeatureType.merge => 'Merged PDF',
    PdfFeatureType.split => 'Split PDF',
    PdfFeatureType.compress => 'Compressed PDF',
    PdfFeatureType.imageToPdf => 'Converted PDF',
    PdfFeatureType.removePassword => 'Unlocked PDF',
    PdfFeatureType.scan => 'Scanned PDF',
    PdfFeatureType.pageEditor => 'Organized PDF',
    PdfFeatureType.eSign => 'Signed PDF',
  };
}
