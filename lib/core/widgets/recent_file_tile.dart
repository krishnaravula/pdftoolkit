import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/recent_files_logic.dart';
import '../../domain/entities/recent_file.dart';
import '../../services/storage/recent_files_service.dart';

class RecentFileTile extends StatelessWidget {
  const RecentFileTile({
    super.key,
    required this.file,
    required this.recentFiles,
    required this.onTap,
    this.onShare,
    this.onRemoveFromRecent,
    this.onDeleteFile,
    this.onRename,
    this.onFileDetails,
    this.onRelink,
    this.compact = false,
    this.showMenu = true,
    this.exists = true,
  });

  final RecentFileItem file;
  final RecentFilesService recentFiles;
  final VoidCallback onTap;
  final VoidCallback? onShare;
  final VoidCallback? onRemoveFromRecent;
  final Future<void> Function()? onDeleteFile;
  final VoidCallback? onRename;
  final VoidCallback? onFileDetails;
  final VoidCallback? onRelink;
  final bool compact;
  final bool showMenu;
  final bool exists;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactCard(
        file: file,
        recentFiles: recentFiles,
        onTap: onTap,
        exists: exists,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final date = DateFormat.yMMMd().format(file.createdAt);
    final time = DateFormat.jm().format(file.createdAt);
    final accessibility = mapFileAccessibility(exists: exists);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(file: file, exists: exists, width: 44, height: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${file.sourceFeature.recentFilesLabel} · ${recentFiles.formatFileSize(file.sizeBytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$date · $time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (accessibility == RecentFileAccessibility.missing) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: colorScheme.error,
                            semanticLabel: 'File unavailable',
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'This file was moved, deleted, or permission is no longer available.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (onRemoveFromRecent != null || onRelink != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (onRemoveFromRecent != null)
                              TextButton(
                                onPressed: onRemoveFromRecent,
                                child: const Text('Remove from recent'),
                              ),
                            if (onRelink != null)
                              TextButton(
                                onPressed: onRelink,
                                child: const Text('Locate file again'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (showMenu)
                _OverflowMenu(
                  file: file,
                  recentFiles: recentFiles,
                  exists: exists,
                  onOpen: onTap,
                  onShare: onShare,
                  onRename: onRename,
                  onFileDetails: onFileDetails,
                  onRemoveFromRecent: onRemoveFromRecent,
                  onDeleteFile: onDeleteFile,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactCard extends StatelessWidget {
  const _CompactCard({
    required this.file,
    required this.recentFiles,
    required this.onTap,
    required this.exists,
  });

  final RecentFileItem file;
  final RecentFilesService recentFiles;
  final VoidCallback onTap;
  final bool exists;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(file: file, exists: exists, width: 48, height: 64),
                const SizedBox(height: 8),
                Text(
                  file.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  file.sourceFeature.recentFilesLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.file,
    required this.exists,
    required this.width,
    required this.height,
  });

  final RecentFileItem file;
  final bool exists;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.picture_as_pdf,
        size: width * 0.55,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    if (file.thumbnailPath == null || !exists) {
      return Semantics(label: 'PDF file', child: placeholder);
    }

    return Semantics(
      label: 'PDF thumbnail for ${file.displayName}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(file.thumbnailPath!),
          width: width,
          height: height,
          fit: BoxFit.cover,
          cacheWidth: (width * 2).round(),
          cacheHeight: (height * 2).round(),
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.file,
    required this.recentFiles,
    required this.exists,
    required this.onOpen,
    this.onShare,
    this.onRename,
    this.onFileDetails,
    this.onRemoveFromRecent,
    this.onDeleteFile,
  });

  final RecentFileItem file;
  final RecentFilesService recentFiles;
  final bool exists;
  final VoidCallback onOpen;
  final VoidCallback? onShare;
  final VoidCallback? onRename;
  final VoidCallback? onFileDetails;
  final VoidCallback? onRemoveFromRecent;
  final Future<void> Function()? onDeleteFile;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'File actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'open':
            onOpen();
          case 'share':
            onShare?.call();
          case 'rename':
            onRename?.call();
          case 'details':
            onFileDetails?.call();
          case 'remove':
            onRemoveFromRecent?.call();
          case 'delete':
            await onDeleteFile?.call();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'open', child: Text('Open')),
        if (onShare != null && exists)
          const PopupMenuItem(value: 'share', child: Text('Share')),
        if (onRename != null && exists && recentFiles.canRename(file))
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
        if (onFileDetails != null)
          const PopupMenuItem(value: 'details', child: Text('File details')),
        if (onRemoveFromRecent != null)
          const PopupMenuItem(
            value: 'remove',
            child: Text('Remove from recent'),
          ),
        if (onDeleteFile != null && exists)
          const PopupMenuItem(value: 'delete', child: Text('Delete file')),
      ],
    );
  }
}

void showRecentFileDetailsDialog(
  BuildContext context, {
  required RecentFileItem file,
  required RecentFilesService recentFiles,
  required bool exists,
}) {
  final date = DateFormat.yMMMd().add_jm().format(file.createdAt);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('File details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(label: 'Filename', value: file.displayName),
            _DetailRow(
              label: 'Type',
              value: file.sourceFeature.recentFilesLabel,
            ),
            _DetailRow(
              label: 'Size',
              value: recentFiles.formatFileSize(file.sizeBytes),
            ),
            _DetailRow(label: 'Date', value: date),
            _DetailRow(
              label: 'Location',
              value: recentFiles.formatFullLocation(file),
            ),
            _DetailRow(label: 'Accessible', value: exists ? 'Yes' : 'No'),
          ],
        ),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
