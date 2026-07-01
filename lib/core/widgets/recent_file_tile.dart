import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/recent_file.dart';
import '../../services/storage/recent_files_service.dart';

class RecentFileTile extends StatelessWidget {
  const RecentFileTile({
    super.key,
    required this.file,
    required this.recentFiles,
    required this.onTap,
    this.onShare,
    this.onDelete,
    this.onRename,
    this.onOpenExternal,
    this.onTogglePin,
    this.compact = false,
    this.showMenu = true,
  });

  final RecentFileItem file;
  final RecentFilesService recentFiles;
  final VoidCallback onTap;
  final VoidCallback? onShare;
  final Future<void> Function()? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onTogglePin;
  final bool compact;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final exists = recentFiles.fileExists(file.path);
    final leading = _buildLeading(exists);

    if (compact) {
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
                  leading,
                  const SizedBox(height: 8),
                  Text(
                    file.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    file.sourceFeature.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final dateFormat = DateFormat.yMMMd().add_jm();

    return Card(
      child: ListTile(
        leading: leading,
        title: Text(file.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${file.sourceFeature.label} • ${recentFiles.formatFileSize(file.sizeBytes)}',
            ),
            if (!compact) ...[
              Text(
                dateFormat.format(file.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${recentFiles.formatLocation(file.path)}${file.exportedUri != null ? ' • Exported' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (!exists)
              Text(
                'File missing',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        isThreeLine: !compact,
        trailing:
            showMenu &&
                (onShare != null || onDelete != null || onTogglePin != null)
            ? PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'open':
                      onTap();
                    case 'share':
                      onShare?.call();
                    case 'rename':
                      onRename?.call();
                    case 'external':
                      onOpenExternal?.call();
                    case 'delete':
                      await onDelete?.call();
                    case 'pin':
                      onTogglePin?.call();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Text('Open in viewer'),
                  ),
                  if (onShare != null)
                    const PopupMenuItem(value: 'share', child: Text('Share')),
                  if (onRename != null)
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  if (onOpenExternal != null)
                    const PopupMenuItem(
                      value: 'external',
                      child: Text('Open with another app'),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  if (onTogglePin != null)
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(file.pinned ? 'Unpin' : 'Pin'),
                    ),
                ],
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildLeading(bool exists) {
    if (compact) {
      if (file.thumbnailPath != null && exists) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(
            File(file.thumbnailPath!),
            width: 48,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.picture_as_pdf, size: 32),
          ),
        );
      }
      return const Icon(Icons.picture_as_pdf, size: 32);
    }

    if (file.thumbnailPath != null && exists) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(file.thumbnailPath!),
          width: 40,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.picture_as_pdf),
        ),
      );
    }
    return const Icon(Icons.picture_as_pdf);
  }
}
