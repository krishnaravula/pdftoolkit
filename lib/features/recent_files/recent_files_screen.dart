import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/recent_file_tile.dart';
import '../../domain/entities/recent_file.dart';

class RecentFilesScreen extends ConsumerStatefulWidget {
  const RecentFilesScreen({super.key});

  @override
  ConsumerState<RecentFilesScreen> createState() => _RecentFilesScreenState();
}

class _RecentFilesScreenState extends ConsumerState<RecentFilesScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future<void>(
      () => ref.read(recentFilesServiceProvider).cleanupOldProcessedFiles(),
    );
  }

  List<RecentFileItem> _filter(List<RecentFileItem> files) {
    if (_query.trim().isEmpty) return files;
    final q = _query.toLowerCase();
    return files.where((f) => f.displayName.toLowerCase().contains(q)).toList();
  }

  Future<void> _renameFile(RecentFileItem file) async {
    final controller = TextEditingController(
      text: file.displayName.replaceAll('.pdf', ''),
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

    if (newName == null || newName.isEmpty) return;

    try {
      await ref
          .read(recentFilesServiceProvider)
          .renameRecentFile(
            id: file.id,
            newName: newName.endsWith('.pdf') ? newName : '$newName.pdf',
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    }
  }

  Future<void> _confirmDelete(RecentFileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Remove "${file.displayName}" from recent files?'),
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
    if (confirmed == true) {
      await ref.read(recentFilesServiceProvider).deleteRecentFile(file.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentAsync = ref.watch(recentFilesStreamProvider);
    final shareService = ref.watch(shareServiceProvider);
    final recentFiles = ref.watch(recentFilesServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recent files')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by file name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(recentFilesStreamProvider);
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: recentAsync.when(
                data: (files) {
                  final filtered = _filter(files);
                  if (files.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 120),
                        EmptyState(message: 'No recent PDFs yet.'),
                      ],
                    );
                  }
                  if (filtered.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 120),
                        EmptyState(
                          message: 'No files match your search.',
                          icon: Icons.search_off,
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final file = filtered[index];
                      return Dismissible(
                        key: ValueKey(file.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Icon(
                            Icons.delete_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                        confirmDismiss: (_) async {
                          await _confirmDelete(file);
                          return false;
                        },
                        child: RecentFileTile(
                          file: file,
                          recentFiles: recentFiles,
                          onTap: () =>
                              context.push('/viewer', extra: file.path),
                          onShare: () => shareService.shareFile(file.path),
                          onDelete: () => recentFiles.deleteRecentFile(file.id),
                          onRename: () => _renameFile(file),
                          onOpenExternal: () =>
                              shareService.openFile(file.path),
                          onTogglePin: () => recentFiles.setPinned(
                            id: file.id,
                            pinned: !file.pinned,
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(userFriendlyError(e))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
