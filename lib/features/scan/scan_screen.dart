import 'dart:io';

import 'package:crop_your_image/crop_your_image.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';

import '../../core/utils/error_messages.dart';

import '../../core/widgets/app_widgets.dart';

import '../../domain/entities/pdf_feature.dart';

import '../../domain/entities/pdf_job.dart';

import '../../domain/entities/scan_page.dart';

import '../shared/feature_scaffold.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with PdfJobMixin {
  bool _scanning = false;

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(scanSessionProvider);

    final progress = ref.watch(pdfJobNotifierProvider);

    final isRunning = progress.status == PdfJobStatus.running || isJobRunning;

    if (pages.isNotEmpty) {
      return ScanReviewScreen(onExport: _export, isExporting: isRunning);
    }

    return FeatureScaffold(
      title: PdfFeatureType.scan.label,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            const Text(
              'Scan multi-page documents with your camera. Review, crop, and enhance before exporting to PDF.',
            ),

            const Spacer(),

            AppPrimaryButton(
              label: _scanning ? 'Scanning…' : 'Start scan',

              icon: Icons.document_scanner_outlined,

              isLoading: _scanning,

              onPressed: _scanning ? null : _startScan,
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _scanning ? null : _addMorePages,

              icon: const Icon(Icons.add_a_photo_outlined),

              label: const Text('Add pages to existing scan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startScan() async {
    setState(() => _scanning = true);

    try {
      final paths = await ref.read(scanServiceProvider).capturePages();

      final pages = paths
          .map((path) => ScanPage(id: const Uuid().v4(), imagePath: path))
          .toList();

      ref.read(scanSessionProvider.notifier).setPages(pages);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _addMorePages() async {
    setState(() => _scanning = true);

    try {
      final paths = await ref.read(scanServiceProvider).capturePages();

      final existing = ref.read(scanSessionProvider);

      final newPages = [
        ...existing,

        ...paths.map(
          (path) => ScanPage(id: const Uuid().v4(), imagePath: path),
        ),
      ];

      ref.read(scanSessionProvider.notifier).setPages(newPages);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _export() async {
    final pages = ref.read(scanSessionProvider);

    if (pages.isEmpty) return;

    await runPdfJob(
      feature: PdfFeatureType.scan,

      suggestedName: 'scan.pdf',

      task: (reporter) async {
        final tempDir = await ref.read(fileStorageProvider).tempDirectory;

        final enhancer = ref.read(pageEnhancerProvider);

        final imagePaths = await enhancer.applyEnhancements(pages, tempDir);

        return ref
            .read(pdfProcessingServiceProvider)
            .imagesToPdf(
              imagePaths,

              suggestedName: 'scan.pdf',

              onProgress: (c, t, m) => reporter.update(c, t, m),
              cancellationToken: reporter.cancellationToken,
            );
      },

      onDone: () => ref.read(scanSessionProvider.notifier).clear(),
    );
  }
}

class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({
    super.key,

    required this.onExport,

    required this.isExporting,
  });

  final VoidCallback onExport;

  final bool isExporting;

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  final _cropController = CropController();

  Future<void> _cropPage(int index, ScanPage page) async {
    final bytes = await File(page.imagePath).readAsBytes();

    if (!mounted) return;

    await showDialog<void>(
      context: context,

      builder: (context) => AlertDialog(
        title: const Text('Crop page'),

        content: SizedBox(
          width: 320,

          height: 420,

          child: Crop(
            controller: _cropController,

            image: bytes,

            onCropped: (result) async {
              final cropped = switch (result) {
                CropSuccess(:final croppedImage) => croppedImage,

                CropFailure() => null,
              };

              if (cropped == null) return;

              final tempPath = await ref
                  .read(fileStorageProvider)
                  .createTempPath();

              await File(tempPath).writeAsBytes(cropped);

              ref
                  .read(scanSessionProvider.notifier)
                  .updatePage(index, page.copyWith(imagePath: tempPath));

              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),

          FilledButton(
            onPressed: () => _cropController.crop(),

            child: const Text('Apply crop'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanMore() async {
    try {
      final paths = await ref.read(scanServiceProvider).capturePages();

      final existing = ref.read(scanSessionProvider);

      final newPages = [
        ...existing,

        ...paths.map(
          (path) => ScanPage(id: const Uuid().v4(), imagePath: path),
        ),
      ];

      ref.read(scanSessionProvider.notifier).setPages(newPages);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(scanSessionProvider);

    return FeatureScaffold(
      title: 'Review scan (${pages.length} pages)',

      child: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),

              itemCount: pages.length,

              onReorderItem: ref.read(scanSessionProvider.notifier).reorder,

              itemBuilder: (context, index) {
                final page = pages[index];

                return Card(
                  key: ValueKey(page.id),

                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.drag_handle),

                        title: Text('Page ${index + 1}'),

                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),

                          onPressed: () => ref
                              .read(scanSessionProvider.notifier)
                              .removeAt(index),
                        ),
                      ),

                      AspectRatio(
                        aspectRatio: 3 / 4,

                        child: Image.file(
                          File(page.imagePath),

                          fit: BoxFit.contain,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(8),

                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _cropPage(index, page),

                                child: const Text('Crop'),
                              ),
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: DropdownButton<ScanEnhancementMode>(
                                isExpanded: true,

                                value: page.enhancement,

                                items: const [
                                  DropdownMenuItem(
                                    value: ScanEnhancementMode.color,

                                    child: Text('Color'),
                                  ),

                                  DropdownMenuItem(
                                    value: ScanEnhancementMode.grayscale,

                                    child: Text('Grayscale'),
                                  ),

                                  DropdownMenuItem(
                                    value: ScanEnhancementMode.blackAndWhite,

                                    child: Text('B&W'),
                                  ),
                                ],

                                onChanged: (mode) {
                                  if (mode == null) return;

                                  ref
                                      .read(scanSessionProvider.notifier)
                                      .updatePage(
                                        index,

                                        page.copyWith(enhancement: mode),
                                      );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),

            child: OutlinedButton.icon(
              onPressed: widget.isExporting ? null : _scanMore,

              icon: const Icon(Icons.add_a_photo_outlined),

              label: const Text('Scan more pages'),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),

            child: AppPrimaryButton(
              label: 'Export PDF',

              isLoading: widget.isExporting,

              onPressed: widget.isExporting ? null : widget.onExport,
            ),
          ),
        ],
      ),
    );
  }
}
