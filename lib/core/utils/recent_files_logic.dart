import '../../domain/entities/app_settings.dart';
import '../../domain/entities/recent_file.dart';

/// Whether a recent-file entry points to an accessible document.
enum RecentFileAccessibility {
  accessible,
  missing,
}

/// Filters recent files by filename (case-insensitive).
List<RecentFileItem> filterRecentFilesByQuery(
  List<RecentFileItem> files,
  String query,
) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return files;
  final q = trimmed.toLowerCase();
  return files
      .where((f) => f.displayName.toLowerCase().contains(q))
      .toList(growable: false);
}

/// Sorts recent files using the selected option.
List<RecentFileItem> sortRecentFiles(
  List<RecentFileItem> files,
  RecentFilesSort sort,
) {
  final sorted = [...files];
  switch (sort) {
    case RecentFilesSort.newest:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case RecentFilesSort.oldest:
      sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case RecentFilesSort.name:
      sorted.sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      );
    case RecentFilesSort.size:
      sorted.sort((a, b) {
        final bySize = b.sizeBytes.compareTo(a.sizeBytes);
        return bySize != 0 ? bySize : b.createdAt.compareTo(a.createdAt);
      });
  }
  return sorted;
}

/// Maps file existence to a UI accessibility state.
RecentFileAccessibility mapFileAccessibility({required bool exists}) {
  return exists ? RecentFileAccessibility.accessible : RecentFileAccessibility.missing;
}

/// Ensures a filename ends with `.pdf` (case-insensitive check).
String ensurePdfExtension(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.toLowerCase().endsWith('.pdf') ? trimmed : '$trimmed.pdf';
}

/// Validates a rename input. Returns an error message or `null` if valid.
String? validateRenameFilename(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return 'Filename cannot be empty.';
  }
  if (RegExp(r'[\\/:*?"<>|]').hasMatch(trimmed)) {
    return 'Filename contains invalid characters.';
  }
  final withoutExt = trimmed.toLowerCase().endsWith('.pdf')
      ? trimmed.substring(0, trimmed.length - 4)
      : trimmed;
  if (withoutExt.trim().isEmpty) {
    return 'Filename cannot be only an extension.';
  }
  return null;
}

/// Strips `.pdf` for editing while preserving the extension on save.
String renameInputFromDisplayName(String displayName) {
  return displayName.toLowerCase().endsWith('.pdf')
      ? displayName.substring(0, displayName.length - 4)
      : displayName;
}
