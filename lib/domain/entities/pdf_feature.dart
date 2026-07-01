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
  pageEditor('Reorder Pages', 'page_editor', 'Reorder or delete PDF pages');

  const PdfFeatureType(this.label, this.routeName, this.description);
  final String label;
  final String routeName;
  final String description;
}
