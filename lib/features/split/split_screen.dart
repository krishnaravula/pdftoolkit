import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/di/providers.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/pdf_job.dart';
import '../../services/pdf/pdf_service.dart';
import '../shared/feature_scaffold.dart';

class SplitScreen extends ConsumerStatefulWidget {
  const SplitScreen({super.key});

  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen> with PdfJobMixin {
  String? _inputPath;
  SplitMode _mode = SplitMode.everyNPages;
  int _pagesPerFile = 1;
  int? _pageCount;

  Future<void> _selectPdf() async {
    final paths = await pickPdfFiles();
    if (paths.isEmpty) return;

    setState(() {
      _inputPath = paths.first;
      _pageCount = null;
    });

    try {
      final count = await ref
          .read(pdfProcessingServiceProvider)
          .pageCount(paths.first);
      if (mounted) setState(() => _pageCount = count);
    } catch (_) {
      if (mounted) setState(() => _pageCount = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(pdfJobNotifierProvider);
    final isRunning = progress.status == PdfJobStatus.running || isJobRunning;

    return FeatureScaffold(
      title: PdfFeatureType.split.label,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: isRunning ? null : _selectPdf,
              icon: const Icon(Icons.folder_open),
              label: Text(
                _inputPath == null ? 'Select PDF' : p.basename(_inputPath!),
              ),
            ),
            if (_pageCount != null) ...[
              const SizedBox(height: 8),
              Text(
                '$_pageCount page(s)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<SplitMode>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Split mode'),
              items: const [
                DropdownMenuItem(
                  value: SplitMode.everyNPages,
                  child: Text('Every N pages'),
                ),
                DropdownMenuItem(
                  value: SplitMode.singlePages,
                  child: Text('One file per page'),
                ),
              ],
              onChanged: isRunning
                  ? null
                  : (v) => setState(() => _mode = v ?? _mode),
            ),
            if (_mode == SplitMode.everyNPages) ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '1',
                decoration: const InputDecoration(labelText: 'Pages per file'),
                keyboardType: TextInputType.number,
                enabled: !isRunning,
                onChanged: (v) =>
                    _pagesPerFile = (int.tryParse(v) ?? 1).clamp(1, 9999),
              ),
            ],
            if (_inputPath == null) ...[
              const SizedBox(height: 24),
              const Expanded(
                child: EmptyState(
                  message: 'Select a PDF to split into smaller files.',
                  icon: Icons.call_split,
                ),
              ),
            ] else
              const Spacer(),
            buildJobStatus(progress),
            const SizedBox(height: 12),
            AppPrimaryButton(
              label: 'Split PDF',
              isLoading: isRunning,
              onPressed: _inputPath == null || isRunning || _pagesPerFile < 1
                  ? null
                  : () => runPdfJob(
                      feature: PdfFeatureType.split,
                      suggestedName: 'split.pdf',
                      task: (reporter) => ref
                          .read(pdfProcessingServiceProvider)
                          .splitPdf(
                            _inputPath!,
                            mode: _mode,
                            pagesPerFile: _pagesPerFile,
                            onProgress: (c, t, m) => reporter.update(c, t, m),
                            cancellationToken: reporter.cancellationToken,
                          ),
                      onDone: () => setState(() {
                        _inputPath = null;
                        _pageCount = null;
                      }),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
