enum ScanEnhancementMode { color, grayscale, blackAndWhite }

class ScanPage {
  ScanPage({
    required this.id,
    required this.imagePath,
    this.enhancement = ScanEnhancementMode.color,
  });

  final String id;
  String imagePath;
  ScanEnhancementMode enhancement;

  ScanPage copyWith({String? imagePath, ScanEnhancementMode? enhancement}) {
    return ScanPage(
      id: id,
      imagePath: imagePath ?? this.imagePath,
      enhancement: enhancement ?? this.enhancement,
    );
  }
}
