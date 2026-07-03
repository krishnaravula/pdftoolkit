import 'package:flutter/material.dart';

import 'pdf_job.dart';

/// User-facing theme preference stored in SharedPreferences.
enum AppThemePreference {
  system('System default'),
  light('Light'),
  dark('Dark');

  const AppThemePreference(this.label);
  final String label;

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  static AppThemePreference fromKey(String? key) {
    return AppThemePreference.values.firstWhere(
      (v) => v.name == key,
      orElse: () => AppThemePreference.system,
    );
  }
}

/// Where generated PDFs are saved by default.
enum DefaultSaveLocation {
  askEveryTime('Ask every time'),
  documentsPdfTools('Documents/PDF Tools'),
  previouslySelected('Previously selected folder');

  const DefaultSaveLocation(this.label);
  final String label;

  static DefaultSaveLocation fromKey(String? key) {
    return DefaultSaveLocation.values.firstWhere(
      (v) => v.name == key,
      orElse: () => DefaultSaveLocation.askEveryTime,
    );
  }
}

/// Image encoding preset for image-to-PDF and scan flows.
enum ImageQualityPreset {
  small('Small', 70),
  recommended('Recommended', 85),
  high('High quality', 95);

  const ImageQualityPreset(this.label, this.jpegQuality);
  final String label;
  final int jpegQuality;

  static ImageQualityPreset fromKey(String? key) {
    return ImageQualityPreset.values.firstWhere(
      (v) => v.name == key,
      orElse: () => ImageQualityPreset.recommended,
    );
  }
}

/// PDF compression preset mapped to [CompressionQuality].
enum CompressionPreset {
  smallFile('Small file', CompressionQuality.low),
  balanced('Balanced', CompressionQuality.medium),
  highQuality('High quality', CompressionQuality.high);

  const CompressionPreset(this.label, this.quality);
  final String label;
  final CompressionQuality quality;

  static CompressionPreset fromKey(String? key) {
    return CompressionPreset.values.firstWhere(
      (v) => v.name == key,
      orElse: () => CompressionPreset.balanced,
    );
  }
}

/// Sort order for the recent-files list.
enum RecentFilesSort {
  newest('Newest first'),
  oldest('Oldest first'),
  name('Name'),
  size('File size');

  const RecentFilesSort(this.label);
  final String label;

  static RecentFilesSort fromKey(String? key) {
    return RecentFilesSort.values.firstWhere(
      (v) => v.name == key,
      orElse: () => RecentFilesSort.newest,
    );
  }
}
