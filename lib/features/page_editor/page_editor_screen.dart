import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/di/providers.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/pdf_job.dart';
import '../shared/feature_scaffold.dart';

class PageEditorScreen extends ConsumerStatefulWidget {
  const PageEditorScreen({super.key});

  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen>
    with PdfJobMixin {
  String? _inputPath;

  List<int> _pageOrder = [];

  bool _loadingPages = false;

  Future<void> _loadPages() async {
    if (_inputPath == null) return;

    setState(() => _loadingPages = true);

    try {
      final count = await ref
          .read(pdfProcessingServiceProvider)
          .pageCount(_inputPath!);

      if (mounted) {
        setState(() => _pageOrder = [for (var i = 1; i <= count; i++) i]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _loadingPages = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(pdfJobNotifierProvider);

    final isRunning = progress.status == PdfJobStatus.running || isJobRunning;

    return FeatureScaffold(
      title: PdfFeatureType.pageEditor.label,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            FilledButton.icon(
              onPressed: isRunning || _loadingPages
                  ? null
                  : () async {
                      final paths = await pickPdfFiles();

                      if (paths.isNotEmpty) {
                        setState(() => _inputPath = paths.first);

                        await _loadPages();
                      }
                    },

              icon: const Icon(Icons.folder_open),

              label: Text(
                _inputPath == null ? 'Select PDF' : p.basename(_inputPath!),
              ),
            ),

            const SizedBox(height: 8),

            const Text('Drag to reorder pages. Tap delete to remove a page.'),

            const SizedBox(height: 8),

            if (_loadingPages) const LinearProgressIndicator(),

            Expanded(
              child: _pageOrder.isEmpty
                  ? const EmptyState(message: 'Load a PDF to edit pages.')
                  : ReorderableListView.builder(
                      itemCount: _pageOrder.length,

                      onReorderItem: isRunning
                          ? (_, _) {}
                          : (oldIndex, newIndex) {
                              setState(() {
                                final item = _pageOrder.removeAt(oldIndex);
                                _pageOrder.insert(newIndex, item);
                              });
                            },

                      itemBuilder: (context, index) {
                        final pageNum = _pageOrder[index];

                        return ListTile(
                          key: ValueKey('$pageNum-$index'),

                          leading: const Icon(Icons.drag_handle),

                          title: Text('Page $pageNum'),

                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),

                            onPressed: isRunning
                                ? null
                                : () {
                                    setState(() {
                                      _pageOrder = [..._pageOrder]
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
              label: 'Save PDF',

              isLoading: isRunning,

              onPressed: _inputPath == null || _pageOrder.isEmpty || isRunning
                  ? null
                  : () => runPdfJob(
                      feature: PdfFeatureType.pageEditor,

                      suggestedName: 'edited.pdf',

                      task: (reporter) => ref
                          .read(pdfProcessingServiceProvider)
                          .reorderOrDeletePages(
                            inputPath: _inputPath!,

                            pageOrderOneBased: _pageOrder,

                            suggestedName: 'edited.pdf',

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
