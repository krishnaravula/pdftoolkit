import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as p;

import '../../core/di/providers.dart';

import '../../core/widgets/app_widgets.dart';

import '../../domain/entities/pdf_feature.dart';

import '../../domain/entities/pdf_job.dart';

import '../shared/feature_scaffold.dart';

class ImageToPdfScreen extends ConsumerStatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  ConsumerState<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends ConsumerState<ImageToPdfScreen>
    with PdfJobMixin {
  List<String> _imagePaths = [];

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(pdfJobNotifierProvider);

    final isRunning = progress.status == PdfJobStatus.running || isJobRunning;

    return FeatureScaffold(
      title: PdfFeatureType.imageToPdf.label,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            FilledButton.icon(
              onPressed: isRunning
                  ? null
                  : () async {
                      final paths = await pickImages();

                      if (paths.isNotEmpty) setState(() => _imagePaths = paths);
                    },

              icon: const Icon(Icons.photo_library_outlined),

              label: const Text('Select images'),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _imagePaths.isEmpty
                  ? const EmptyState(
                      message:
                          'Add images, then drag to reorder before creating the PDF.',
                      icon: Icons.image_outlined,
                    )
                  : ReorderableListView.builder(
                      itemCount: _imagePaths.length,

                      onReorderItem: isRunning
                          ? (_, _) {}
                          : (oldIndex, newIndex) {
                              setState(() {
                                final item = _imagePaths.removeAt(oldIndex);
                                _imagePaths.insert(newIndex, item);
                              });
                            },

                      itemBuilder: (context, index) {
                        return ListTile(
                          key: ValueKey(_imagePaths[index]),

                          leading: const Icon(Icons.drag_handle),

                          title: Text(p.basename(_imagePaths[index])),

                          trailing: IconButton(
                            icon: const Icon(Icons.close),

                            onPressed: isRunning
                                ? null
                                : () {
                                    setState(() {
                                      _imagePaths = [..._imagePaths]
                                        ..removeAt(index);
                                    });
                                  },
                          ),
                        );
                      },
                    ),
            ),

            buildJobStatus(progress),

            const SizedBox(height: 12),

            AppPrimaryButton(
              label: 'Create PDF',

              isLoading: isRunning,

              onPressed: _imagePaths.isEmpty || isRunning
                  ? null
                  : () => runPdfJob(
                      feature: PdfFeatureType.imageToPdf,

                      suggestedName: 'images.pdf',

                      task: (reporter) => ref
                          .read(pdfProcessingServiceProvider)
                          .imagesToPdf(
                            _imagePaths,

                            suggestedName: 'images.pdf',

                            onProgress: (c, t, m) => reporter.update(c, t, m),
                          ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
