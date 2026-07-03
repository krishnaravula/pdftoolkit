import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/config/env.dart';
import '../../core/di/providers.dart';
import '../../core/widgets/screen_widgets.dart';
import '../../data/local/app_preferences.dart';
import '../../domain/entities/app_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PackageInfo? _packageInfo;
  String? _folderLabel;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadFolderLabel();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  Future<void> _loadFolderLabel() async {
    final storage = ref.read(storageRepositoryProvider);
    final uri = await storage.getPreferredExportTreeUri();
    if (!mounted) return;
    if (uri == null) {
      setState(() => _folderLabel = null);
      return;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    setState(
      () => _folderLabel = segments.isEmpty ? 'Selected folder' : segments.last,
    );
  }

  Future<void> _openSupportEmail() async {
    final version = _packageInfo?.version ?? 'unknown';
    final subject = Uri.encodeComponent('PDF Tools support – version $version');
    final body = Uri.encodeComponent(
      'Describe your issue:\n\n\n'
      '---\n'
      'App version: $version\n'
      'Android version: ${Platform.operatingSystemVersion}\n',
    );
    final uri = Uri.parse(
      'mailto:${Env.supportEmail}?subject=$subject&body=$body',
    );
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No email app found. Copy: ${Env.supportEmail}'),
          ),
        );
      }
    }
  }

  Future<void> _pickSaveFolder() async {
    final storage = ref.read(storageRepositoryProvider);
    final treeUri = await storage.pickExportTreeUri();
    if (treeUri == null) return;
    await storage.persistTreeUriPermission(treeUri);
    await storage.setPreferredExportTreeUri(treeUri);
    final prefs = await ref.read(appPreferencesProvider.future);
    await prefs.setDefaultSaveLocation(DefaultSaveLocation.previouslySelected);
    await _loadFolderLabel();
  }

  Future<void> _clearTemporaryFiles() async {
    final recentFiles = ref.read(recentFilesServiceProvider);
    final bytes = await recentFiles.calculateTemporaryFilesBytes();
    final sizeLabel = recentFiles.formatFileSize(bytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear temporary files?'),
        content: Text(
          'Remove cached thumbnails and temporary processing files (~$sizeLabel)? '
          'Your saved PDFs and recent history are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final cleared = await recentFiles.clearTemporaryFiles();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cleared ${recentFiles.formatFileSize(cleared)} of temporary files.',
        ),
      ),
    );
  }

  Future<void> _clearRecentHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear recent history?'),
        content: const Text(
          'This removes all entries from your recent files list. '
          'Your actual PDF files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recentFilesServiceProvider).clearRecentHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recent history cleared.')),
      );
    }
  }

  void _showVersionDetails() {
    final info = _packageInfo;
    if (info == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Version details'),
        content: Text(
          'Version ${info.version}\nBuild ${info.buildNumber}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(appPreferencesProvider);
    final billingEnabled = ref.watch(billingEnabledProvider);

    return Scaffold(
      body: SafeArea(
        child: prefsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load settings: $e')),
          data: (prefs) => ListView(
            children: [
              const ScreenTitle('Settings'),
              const SettingsSectionHeader('Appearance'),
              ListTile(
                title: const Text('Theme'),
                subtitle: Text(prefs.theme.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemePicker(prefs),
              ),
              const SettingsSectionHeader('Files'),
              ListTile(
                title: const Text('Default save location'),
                subtitle: Text(_saveLocationSubtitle(prefs)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSaveLocationPicker(prefs),
              ),
              SwitchListTile(
                title: const Text('Confirm before deleting files'),
                subtitle: const Text(
                  'Ask before permanently deleting a PDF file.',
                ),
                value: prefs.confirmBeforeDeletingFiles,
                onChanged: (value) async {
                  await prefs.setConfirmBeforeDeletingFiles(value);
                  ref.invalidate(appPreferencesProvider);
                },
              ),
              const SettingsSectionHeader('Processing'),
              ListTile(
                title: const Text('Default image quality'),
                subtitle: Text(prefs.imageQuality.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showImageQualityPicker(prefs),
              ),
              ListTile(
                title: const Text('Default compression level'),
                subtitle: Text(prefs.compressionPreset.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCompressionPicker(prefs),
              ),
              const SettingsSectionHeader('Privacy'),
              const ListTile(
                title: Text('Offline processing'),
                subtitle: Text(
                  'All PDF operations run locally on your device.',
                ),
              ),
              ListTile(
                title: const Text('Clear temporary files'),
                subtitle: const Text(
                  'Remove cached thumbnails and processing artifacts.',
                ),
                onTap: _clearTemporaryFiles,
              ),
              ListTile(
                title: const Text('Clear recent history'),
                subtitle: const Text(
                  'Remove recent list entries without deleting PDF files.',
                ),
                onTap: _clearRecentHistory,
              ),
              const SettingsSectionHeader('About'),
              if (AppConfig.enableBilling)
                billingEnabled.when(
                  data: (_) => ListTile(
                    title: const Text('Remove ads'),
                    subtitle: Text(
                      'Support development and use ${Env.appName} ad-free',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/premium'),
                  ),
                  loading: () => const ListTile(
                    title: Text('Remove ads'),
                    subtitle: Text('Loading…'),
                  ),
                  error: (_, _) => const ListTile(
                    title: Text('Remove ads'),
                    subtitle: Text('Billing unavailable on this device'),
                    enabled: false,
                  ),
                ),
              ListTile(
                title: const Text('Privacy policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/privacy-policy'),
              ),
              ListTile(
                title: const Text('Open-source licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: Env.appName,
                  applicationVersion: _packageInfo?.version,
                ),
              ),
              ListTile(
                title: const Text('Contact support'),
                subtitle: Text(Env.supportEmail),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openSupportEmail,
              ),
              ListTile(
                title: const Text('Version'),
                subtitle: Text(
                  _packageInfo == null
                      ? 'Loading…'
                      : 'Version ${_packageInfo!.version}',
                ),
                onTap: _packageInfo == null ? null : _showVersionDetails,
              ),
              if (kDebugMode) ...[
                const Divider(),
                const SettingsSectionHeader('Developer'),
                SwitchListTile(
                  title: const Text('Enable ads (runtime)'),
                  value: AppConfig.enableAds,
                  onChanged: AppConfig.enableAds
                      ? (value) async {
                          await AppConfig.setAdsOverride(value);
                          ref.invalidate(adsEnabledProvider);
                        }
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Enable billing (runtime)'),
                  value: AppConfig.enableBilling,
                  onChanged: AppConfig.enableBilling
                      ? (value) async {
                          await AppConfig.setBillingOverride(value);
                          ref.invalidate(billingEnabledProvider);
                        }
                      : null,
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _saveLocationSubtitle(AppPreferences prefs) {
    return switch (prefs.defaultSaveLocation) {
      DefaultSaveLocation.askEveryTime => DefaultSaveLocation.askEveryTime.label,
      DefaultSaveLocation.documentsPdfTools =>
        DefaultSaveLocation.documentsPdfTools.label,
      DefaultSaveLocation.previouslySelected =>
        _folderLabel ?? 'No folder selected — tap to choose',
    };
  }

  Future<void> _showThemePicker(AppPreferences prefs) async {
    final selected = await showModalBottomSheet<AppThemePreference>(
      context: context,
      builder: (context) => _OptionSheet(
        title: 'Theme',
        options: AppThemePreference.values
            .map((v) => (v, v.label))
            .toList(growable: false),
        selected: prefs.theme,
      ),
    );
    if (selected == null) return;
    await prefs.setTheme(selected);
    ref.invalidate(appPreferencesProvider);
  }

  Future<void> _showSaveLocationPicker(AppPreferences prefs) async {
    final selected = await showModalBottomSheet<DefaultSaveLocation>(
      context: context,
      builder: (context) => _OptionSheet(
        title: 'Default save location',
        options: DefaultSaveLocation.values
            .map((v) => (v, v.label))
            .toList(growable: false),
        selected: prefs.defaultSaveLocation,
      ),
    );
    if (selected == null) return;
    await prefs.setDefaultSaveLocation(selected);
    if (selected == DefaultSaveLocation.previouslySelected) {
      await _pickSaveFolder();
    }
    ref.invalidate(appPreferencesProvider);
  }

  Future<void> _showImageQualityPicker(AppPreferences prefs) async {
    final selected = await showModalBottomSheet<ImageQualityPreset>(
      context: context,
      builder: (context) => _OptionSheet(
        title: 'Default image quality',
        options: ImageQualityPreset.values
            .map((v) => (v, v.label))
            .toList(growable: false),
        selected: prefs.imageQuality,
      ),
    );
    if (selected == null) return;
    await prefs.setImageQuality(selected);
    ref.invalidate(appPreferencesProvider);
  }

  Future<void> _showCompressionPicker(AppPreferences prefs) async {
    final selected = await showModalBottomSheet<CompressionPreset>(
      context: context,
      builder: (context) => _OptionSheet(
        title: 'Default compression level',
        options: CompressionPreset.values
            .map((v) => (v, v.label))
            .toList(growable: false),
        selected: prefs.compressionPreset,
      ),
    );
    if (selected == null) return;
    await prefs.setCompressionPreset(selected);
    ref.invalidate(appPreferencesProvider);
  }
}

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<(T, String)> options;
  final T selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final (value, label) in options)
            RadioListTile<T>(
              title: Text(label),
              value: value,
              groupValue: selected,
              onChanged: (v) => Navigator.pop(context, v),
            ),
        ],
      ),
    );
  }
}
