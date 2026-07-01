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
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentFilesStreamProvider);
    final recentFiles = ref.watch(recentFilesServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(Env.appName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tools', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              for (final tool in _tools)
                ToolCard(
                  icon: tool.$2,
                  label: tool.$1.label,
                  subtitle: tool.$1.description,
                  onTap: () => navigateToFeature(context, tool.$1),
                ),
            ],
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
