import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as p;

import '../../core/di/providers.dart';

import '../../core/widgets/app_widgets.dart';

import '../../domain/entities/pdf_feature.dart';

import '../../domain/entities/pdf_job.dart';

import '../shared/feature_scaffold.dart';

class CompressScreen extends ConsumerStatefulWidget {
  const CompressScreen({super.key});

  @override
  ConsumerState<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends ConsumerState<CompressScreen>
    with PdfJobMixin {
  String? _inputPath;

  CompressionQuality _quality = CompressionQuality.medium;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(pdfJobNotifierProvider);

    final isRunning = progress.status == PdfJobStatus.running || isJobRunning;

    return FeatureScaffold(
      title: PdfFeatureType.compress.label,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            const Text(
              'Compression re-encodes pages as images. "Smaller" reduces size '
              'the most, "Sharper" keeps the best quality. Text-heavy PDFs may '
              'lose sharpness; if compression would enlarge the file, the '
              'original is kept.',
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: isRunning
                  ? null
                  : () async {
                      final paths = await pickPdfFiles();

                      if (paths.isNotEmpty) {
                        setState(() => _inputPath = paths.first);
                      }
                    },

              icon: const Icon(Icons.folder_open),

              label: Text(
                _inputPath == null ? 'Select PDF' : p.basename(_inputPath!),
              ),
            ),

            const SizedBox(height: 16),

            SegmentedButton<CompressionQuality>(
              segments: const [
                ButtonSegment(
                  value: CompressionQuality.low,
                  label: Text('Smaller'),
                ),

                ButtonSegment(
                  value: CompressionQuality.medium,
                  label: Text('Balanced'),
                ),

                ButtonSegment(
                  value: CompressionQuality.high,
                  label: Text('Sharper'),
                ),
              ],

              selected: {_quality},

              onSelectionChanged: isRunning
                  ? null
                  : (values) => setState(() => _quality = values.first),
            ),

            const Spacer(),

            buildJobStatus(progress),

            const SizedBox(height: 12),

            AppPrimaryButton(
              label: 'Compress',

              isLoading: isRunning,

              onPressed: _inputPath == null || isRunning
                  ? null
                  : () => runPdfJob(
                      feature: PdfFeatureType.compress,

                      suggestedName: 'compressed.pdf',

                      task: (reporter) => ref
                          .read(pdfProcessingServiceProvider)
                          .compressPdf(
                            inputPath: _inputPath!,

                            suggestedName: 'compressed.pdf',

                            quality: _quality,

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
