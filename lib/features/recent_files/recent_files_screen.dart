import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/recent_files_logic.dart';
import '../../core/widgets/recent_file_tile.dart';
import '../../core/widgets/screen_widgets.dart';
import '../../data/local/app_preferences.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/recent_file.dart';
import '../../features/viewer/pdf_viewer_screen.dart';

enum RecentFilesListState { loading, empty, content, searchEmpty, error }

class RecentFilesScreen extends ConsumerStatefulWidget {
  const RecentFilesScreen({super.key});

  @override
  ConsumerState<RecentFilesScreen> createState() => _RecentFilesScreenState();
}

class _RecentFilesScreenState extends ConsumerState<RecentFilesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  RecentFilesSort _sort = RecentFilesSort.newest;
  bool _actionInProgress = false;
  final _existenceCache = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _loadSortPreference();
    _refreshExistence();
  }

  Future<void> _loadSortPreference() async {
    final prefs = await ref.read(appPreferencesProvider.future);
    if (!mounted) return;
    setState(() => _sort = prefs.recentFilesSort);
  }

  Future<void> _refreshExistence() async {
    final files = await ref.read(recentFilesServiceProvider).getRecentFiles();
    final recentFiles = ref.read(recentFilesServiceProvider);
    final cache = <String, bool>{};
    for (final file in files) {
      cache[file.id] = await recentFiles.fileExists(file.path);
    }
    if (mounted) {
      setState(
        () => _existenceCache
          ..clear()
          ..addAll(cache),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RecentFileItem> _prepareList(List<RecentFileItem> files) {
    final filtered = filterRecentFilesByQuery(files, _query);
    return sortRecentFiles(filtered, _sort);
  }

  RecentFilesListState _listState(List<RecentFileItem> files) {
    if (files.isEmpty) return RecentFilesListState.empty;
    final prepared = _prepareList(files);
    if (prepared.isEmpty && _query.trim().isNotEmpty) {
      return RecentFilesListState.searchEmpty;
    }
    return RecentFilesListState.content;
  }

  Future<void> _setSort(RecentFilesSort sort) async {
    setState(() => _sort = sort);
    final prefs = await ref.read(appPreferencesProvider.future);
    await prefs.setRecentFilesSort(sort);
  }

  Future<void> _openFile(RecentFileItem file) async {
    if (_actionInProgress) return;
    final recentFiles = ref.read(recentFilesServiceProvider);
    if (!await recentFiles.fileExists(file.path)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This file was moved, deleted, or permission is no longer available.',
            ),
          ),
        );
      }
      await _refreshExistence();
      return;
    }

    setState(() => _actionInProgress = true);
    try {
      final processing = ref.read(pdfProcessingServiceProvider);
      try {
        await processing.validatePdfExists(file.path);
      } catch (e) {
        final message = userFriendlyError(e);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }

      if (mounted) openPdfViewer(context, file.path);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _shareFile(RecentFileItem file) async {
    if (_actionInProgress) return;
    final recentFiles = ref.read(recentFilesServiceProvider);
    if (!await recentFiles.fileExists(file.path)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File is no longer available to share.'),
          ),
        );
      }
      return;
    }
    setState(() => _actionInProgress = true);
    try {
      await ref.read(shareServiceProvider).shareFile(file.path);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _renameFile(RecentFileItem file) async {
    final recentFiles = ref.read(recentFilesServiceProvider);
    if (!recentFiles.canRename(file)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Renaming is not supported for this file location.'),
          ),
        );
      }
      return;
    }

    final controller = TextEditingController(
      text: renameInputFromDisplayName(file.displayName),
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            suffixText: '.pdf',
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null) return;
    final validationError = validateRenameFilename(newName);
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationError)));
      }
      return;
    }

    try {
      await recentFiles.renameRecentFile(
        id: file.id,
        newName: ensurePdfExtension(newName),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    }
  }

  Future<void> _confirmRemoveFromRecent(RecentFileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from recent?'),
        content: Text(
          'Remove "${file.displayName}" from your recent list? The file itself will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(recentFilesServiceProvider).removeFromRecent(file.id);
      await _refreshExistence();
    }
  }

  Future<void> _confirmDeleteFile(RecentFileItem file) async {
    final prefs = await ref.read(appPreferencesProvider.future);
    if (!mounted) return;
    if (prefs.confirmBeforeDeletingFiles) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete file?'),
          content: Text(
            'Permanently delete "${file.displayName}"? This removes the actual file from your device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final deleted = await ref
          .read(recentFilesServiceProvider)
          .deleteFileAndRemoveFromRecent(file.id);
      if (!deleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this file.')),
        );
      }
      await _refreshExistence();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _relinkFile(RecentFileItem file) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    try {
      await ref
          .read(recentFilesServiceProvider)
          .relinkRecentFile(id: file.id, newPath: path);
      await _refreshExistence();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    }
  }

  Future<void> _showSortMenu() async {
    final selected = await showModalBottomSheet<RecentFilesSort>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sort by',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final option in RecentFilesSort.values)
              RadioListTile<RecentFilesSort>(
                title: Text(option.label),
                value: option,
                groupValue: _sort,
                onChanged: (value) => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (selected != null) await _setSort(selected);
  }

  @override
  Widget build(BuildContext context) {
    final recentAsync = ref.watch(recentFilesStreamProvider);
    final recentFiles = ref.watch(recentFilesServiceProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenTitle('Recent files'),
            if (_actionInProgress) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(recentFilesStreamProvider);
                  await _refreshExistence();
                  await Future<void>.delayed(const Duration(milliseconds: 200));
                },
                child: recentAsync.when(
                  data: (files) {
                    final state = _listState(files);
                    return switch (state) {
                      RecentFilesListState.empty => ListView(
                        children: [
                          StructuredEmptyState(
                            title: 'No recent files',
                            description:
                                'Files you create or open will appear here.',
                            actionLabel: 'Go to PDF Tools',
                            onAction: () => context.go('/home'),
                          ),
                        ],
                      ),
                      RecentFilesListState.searchEmpty => ListView(
                        children: const [
                          StructuredEmptyState(
                            title: 'No files found',
                            description: 'Try a different file name.',
                            icon: Icons.search_off,
                          ),
                        ],
                      ),
                      RecentFilesListState.content => _buildFileList(
                        _prepareList(files),
                        recentFiles,
                      ),
                      RecentFilesListState.loading ||
                      RecentFilesListState.error => const SizedBox.shrink(),
                    };
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    children: [
                      StructuredEmptyState(
                        title: 'Could not load recent files',
                        description: userFriendlyError(e),
                        icon: Icons.error_outline,
                        actionLabel: 'Retry',
                        onAction: () =>
                            ref.invalidate(recentFilesStreamProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _BottomSearchBar(
              controller: _searchController,
              query: _query,
              sort: _sort,
              onQueryChanged: (value) => setState(() => _query = value),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              onSortTap: _showSortMenu,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(List<RecentFileItem> files, dynamic recentFiles) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final file = files[index];
        final exists = _existenceCache[file.id] ?? true;
        return RecentFileTile(
          key: ValueKey(file.id),
          file: file,
          recentFiles: recentFiles,
          exists: exists,
          onTap: () => _openFile(file),
          onShare: () => _shareFile(file),
          onRename: () => _renameFile(file),
          onFileDetails: () => showRecentFileDetailsDialog(
            context,
            file: file,
            recentFiles: recentFiles,
            exists: exists,
          ),
          onRemoveFromRecent: () => _confirmRemoveFromRecent(file),
          onDeleteFile: () => _confirmDeleteFile(file),
          onRelink: exists ? null : () => _relinkFile(file),
        );
      },
    );
  }
}

class _BottomSearchBar extends StatelessWidget {
  const _BottomSearchBar({
    required this.controller,
    required this.query,
    required this.sort,
    required this.onQueryChanged,
    required this.onClear,
    required this.onSortTap,
  });

  final TextEditingController controller;
  final String query;
  final RecentFilesSort sort;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final VoidCallback onSortTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: TextField(
                controller: controller,
                onChanged: onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search recent files',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: onClear,
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Sort: ${sort.label}',
            onPressed: onSortTap,
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
    );
  }
}
