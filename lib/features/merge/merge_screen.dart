import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/di/providers.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/pdf_job.dart';
import '../shared/feature_scaffold.dart';

class MergeScreen extends ConsumerStatefulWidget {
  const MergeScreen({super.key});

  @override
  ConsumerState<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends ConsumerState<MergeScreen> with PdfJobMixin {
  List<String> _selectedPaths = [];

  int get _totalBytes {
    var total = 0;
    for (final path in _selectedPaths) {
      total += _fileSize(path);
    }
    return total;
  }

  int _fileSize(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(pdfJobNotifierProvider);
    final isRunning = progress.status == PdfJobStatus.running || isJobRunning;

    return FeatureScaffold(
      title: PdfFeatureType.merge.label,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: isRunning
                  ? null
                  : () async {
                      final paths = await pickPdfFiles(allowMultiple: true);
                      if (paths.isNotEmpty) {
                        setState(() => _selectedPaths = paths);
                      }
                    },
              icon: const Icon(Icons.folder_open),
              label: const Text('Select PDF files'),
            ),
            if (_selectedPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_selectedPaths.length} file(s) • ${(_totalBytes / 1024).toStringAsFixed(1)} KB total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _selectedPaths.isEmpty
                  ? const EmptyState(
                      message: 'Select two or more PDF files to merge.',
                      icon: Icons.merge_type,
                    )
                  : ListView.builder(
                      itemCount: _selectedPaths.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(p.basename(_selectedPaths[index])),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: isRunning
                                ? null
                                : () {
                                    setState(() {
                                      _selectedPaths = [..._selectedPaths]
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
              label: 'Merge',
              isLoading: isRunning,
              onPressed: _selectedPaths.length < 2 || isRunning
                  ? null
                  : () => runPdfJob(
                      feature: PdfFeatureType.merge,
                      suggestedName: 'merged.pdf',
                      task: (reporter) => ref
                          .read(pdfProcessingServiceProvider)
                          .mergePdfs(
                            _selectedPaths,
                            suggestedName: 'merged.pdf',
                            onProgress: (c, t, m) => reporter.update(c, t, m),
                          ),
                      onDone: () => setState(() => _selectedPaths = []),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
