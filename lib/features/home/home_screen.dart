import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/di/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/recent_file_tile.dart';
import '../../domain/entities/pdf_feature.dart';
import '../viewer/pdf_viewer_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _tools = [
    (PdfFeatureType.merge, Icons.merge_type),
    (PdfFeatureType.split, Icons.call_split),
    (PdfFeatureType.compress, Icons.compress),
    (PdfFeatureType.imageToPdf, Icons.image_outlined),
    (PdfFeatureType.removePassword, Icons.lock_open_outlined),
    (PdfFeatureType.scan, Icons.document_scanner_outlined),
    (PdfFeatureType.pageEditor, Icons.swap_vert),
    (PdfFeatureType.eSign, Icons.draw_outlined),
  ];

  Future<void> _choosePdf(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path != null && context.mounted) openPdfViewer(context, path);
  }

  Future<void> _showDefaultViewerHelp(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.picture_as_pdf_outlined),
        title: const Text('Use PDF Tools by default'),
        content: const Text(
          'Open a PDF in Android Files, choose PDF Tools, then tap Always. '
          'You can review or reset that choice in Android settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      try {
        await ref
            .read(androidIntegrationServiceProvider)
            .openDefaultPdfSettings();
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Android settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentFilesStreamProvider);
    final recentFiles = ref.watch(recentFilesServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(Env.appName),
        actions: [
          IconButton(
            tooltip: 'Open a PDF',
            onPressed: () => _choosePdf(context),
            icon: const Icon(Icons.file_open_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OpenPdfCard(
            onOpen: () => _choosePdf(context),
            onSetDefault: () => _showDefaultViewerHelp(context, ref),
          ),
          const SizedBox(height: 24),
          Text('PDF tools', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Private, fast, and fully offline',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 840
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 3
                  : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: switch (columns) {
                  2 => 0.86,
                  3 => 0.96,
                  _ => 1.05,
                },
                children: [
                  for (final tool in _tools)
                    ToolCard(
                      icon: tool.$2,
                      label: tool.$1.label,
                      subtitle: tool.$1.description,
                      onTap: () => navigateToFeature(context, tool.$1),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent files',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () => context.go('/recent'),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          recentAsync.when(
            data: (files) {
              if (files.isEmpty) {
                return const EmptyState(
                  message: 'Processed PDFs will appear here.',
                );
              }
              return SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: files.take(6).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return RecentFileTile(
                      file: file,
                      recentFiles: recentFiles,
                      compact: true,
                      showMenu: false,
                      onTap: () => openPdfViewer(context, file.path),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(userFriendlyError(e)),
          ),
        ],
      ),
    );
  }
}

class _OpenPdfCard extends StatelessWidget {
  const _OpenPdfCard({required this.onOpen, required this.onSetDefault});

  final VoidCallback onOpen;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.picture_as_pdf, size: 36, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'Open and read any PDF',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Use PDF Tools as your everyday viewer, then edit or share when needed.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choose PDF'),
                ),
                TextButton.icon(
                  onPressed: onSetDefault,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Set as default'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
