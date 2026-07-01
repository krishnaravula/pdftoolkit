import 'pdf_feature.dart';

class RecentFileItem {
  const RecentFileItem({
    required this.id,
    required this.displayName,
    required this.path,
    required this.sizeBytes,
    required this.createdAt,
    required this.sourceFeature,
    this.thumbnailPath,
    this.exportedUri,
    this.pinned = false,
  });

  final String id;
  final String displayName;
  final String path;
  final int sizeBytes;
  final DateTime createdAt;
  final PdfFeatureType sourceFeature;
  final String? thumbnailPath;
  final String? exportedUri;
  final bool pinned;
}
