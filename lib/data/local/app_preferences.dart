import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';

/// Local user preferences backed by SharedPreferences.
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'pref_theme';
  static const _saveLocationKey = 'pref_save_location';
  static const _confirmDeleteKey = 'pref_confirm_delete';
  static const _imageQualityKey = 'pref_image_quality';
  static const _compressionKey = 'pref_compression';
  static const _recentSortKey = 'pref_recent_sort';
  static const _readingPositionsKey = 'pref_reading_positions';
  static const _maxReadingPositions = 100;

  AppThemePreference get theme =>
      AppThemePreference.fromKey(_prefs.getString(_themeKey));

  Future<void> setTheme(AppThemePreference value) =>
      _prefs.setString(_themeKey, value.name);

  DefaultSaveLocation get defaultSaveLocation =>
      DefaultSaveLocation.fromKey(_prefs.getString(_saveLocationKey));

  Future<void> setDefaultSaveLocation(DefaultSaveLocation value) =>
      _prefs.setString(_saveLocationKey, value.name);

  bool get confirmBeforeDeletingFiles =>
      _prefs.getBool(_confirmDeleteKey) ?? true;

  Future<void> setConfirmBeforeDeletingFiles(bool value) =>
      _prefs.setBool(_confirmDeleteKey, value);

  ImageQualityPreset get imageQuality =>
      ImageQualityPreset.fromKey(_prefs.getString(_imageQualityKey));

  Future<void> setImageQuality(ImageQualityPreset value) =>
      _prefs.setString(_imageQualityKey, value.name);

  CompressionPreset get compressionPreset =>
      CompressionPreset.fromKey(_prefs.getString(_compressionKey));

  Future<void> setCompressionPreset(CompressionPreset value) =>
      _prefs.setString(_compressionKey, value.name);

  RecentFilesSort get recentFilesSort =>
      RecentFilesSort.fromKey(_prefs.getString(_recentSortKey));

  Future<void> setRecentFilesSort(RecentFilesSort value) =>
      _prefs.setString(_recentSortKey, value.name);

  /// Returns the last page read for [documentKey], or page 1 for a new file.
  int readingPageFor(String documentKey) {
    final value = _readingPositions()[documentKey];
    return value is int && value > 0 ? value : 1;
  }

  /// Saves a bounded, local-only reading history so the viewer can resume.
  Future<void> setReadingPage(String documentKey, int pageNumber) async {
    if (documentKey.isEmpty || pageNumber < 1) return;

    final positions = _readingPositions();
    // Reinsert existing keys so the map remains ordered from oldest to newest.
    positions.remove(documentKey);
    positions[documentKey] = pageNumber;
    while (positions.length > _maxReadingPositions) {
      positions.remove(positions.keys.first);
    }
    await _prefs.setString(_readingPositionsKey, jsonEncode(positions));
  }

  Map<String, int> _readingPositions() {
    final encoded = _prefs.getString(_readingPositionsKey);
    if (encoded == null || encoded.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return <String, int>{};
      return {
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key: (entry.value as num).toInt(),
      };
    } on FormatException {
      return <String, int>{};
    }
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final appPreferencesProvider = FutureProvider<AppPreferences>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return AppPreferences(prefs);
});

/// Synchronous access after preferences are loaded (used by notifiers).
class AppPreferencesNotifier extends Notifier<AppPreferences?> {
  @override
  AppPreferences? build() => null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppPreferences(prefs);
  }

  Future<void> reload() => load();
}

final appPreferencesNotifierProvider =
    NotifierProvider<AppPreferencesNotifier, AppPreferences?>(
      AppPreferencesNotifier.new,
    );
