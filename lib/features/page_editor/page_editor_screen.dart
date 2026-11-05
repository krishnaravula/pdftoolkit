import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../../core/di/providers.dart';
import '../../core/pdf/pdfrx_initializer.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/pdf_job.dart';
import '../../domain/entities/pdf_page_operation.dart';
import '../shared/feature_scaffold.dart';

class PageEditorScreen extends ConsumerStatefulWidget {
  const PageEditorScreen({super.key, this.initialFilePath});

  final String? initialFilePath;

  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen>
    with PdfJobMixin {
  final Map<String, PdfDocument> _documents = <String, PdfDocument>{};
  final List<List<_OrganizerPage>> _undoHistory = <List<_OrganizerPage>>[];
  final List<List<_OrganizerPage>> _redoHistory = <List<_OrganizerPage>>[];
  final Set<int> _selectedIds = <int>{};

  List<_OrganizerPage> _pages = <_OrganizerPage>[];
  bool _loadingPages = false;
  int _nextId = 1;

  @override
  void initState() {
    super.initState();
    final initialPath = widget.initialFilePath;
    if (initialPath != null && initialPath.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _replaceWithPdf(initialPath);
      });
    }
  }

  @override
  void dispose() {
    for (final document in _documents.values) {
      document.dispose();
    }
    super.dispose();
  }

  Future<PdfDocument> _openDocument(String path) async {
    await PdfrxInitializer.ensureInitialized();
    return PdfDocument.openFile(path);
  }

  Future<void> _choosePrimaryPdf() async {
    final paths = await pickPdfFiles();
    if (paths.isNotEmpty) await _replaceWithPdf(paths.first);
  }

  Future<void> _replaceWithPdf(String path) async {
    setState(() => _loadingPages = true);
    PdfDocument? document;
    try {
      document = await _openDocument(path);
      if (!mounted) {
        document.dispose();
        return;
      }

      for (final current in _documents.values) {
        current.dispose();
      }
      final pages = [
        for (var page = 1; page <= document.pages.length; page++)
          _OrganizerPage(
            id: _nextId++,
            sourcePath: path,
            sourcePageNumber: page,
          ),
      ];
      setState(() {
        _documents
          ..clear()
          ..[path] = document!;
        _pages = pages;
        _selectedIds.clear();
        _undoHistory.clear();
        _redoHistory.clear();
      });
      document = null;
    } catch (e) {
      document?.dispose();
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loadingPages = false);
    }
  }

  Future<void> _appendPdfs() async {
    final paths = await pickPdfFiles(allowMultiple: true);
    if (paths.isEmpty || !mounted) return;

    setState(() => _loadingPages = true);
    final newlyOpened = <String, PdfDocument>{};
    try {
      final appended = <_OrganizerPage>[];
      for (final path in paths) {
        var document = _documents[path] ?? newlyOpened[path];
        if (document == null) {
          document = await _openDocument(path);
          newlyOpened[path] = document;
        }
        for (var page = 1; page <= document.pages.length; page++) {
          appended.add(
            _OrganizerPage(
              id: _nextId++,
              sourcePath: path,
              sourcePageNumber: page,
            ),
          );
        }
      }
      if (!mounted) {
        for (final document in newlyOpened.values) {
          document.dispose();
        }
        return;
      }
      _commit([..._pages, ...appended]);
      _documents.addAll(newlyOpened);
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(appended.map((page) => page.id));
      });
    } catch (e) {
      for (final document in newlyOpened.values) {
        document.dispose();
      }
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loadingPages = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(userFriendlyError(error))));
  }

  void _commit(List<_OrganizerPage> nextPages) {
    setState(() {
      _undoHistory.add(List<_OrganizerPage>.of(_pages));
      if (_undoHistory.length > 50) _undoHistory.removeAt(0);
      _redoHistory.clear();
      _pages = nextPages;
      _selectedIds.removeWhere((id) => !_pages.any((page) => page.id == id));
    });
  }

  void _undo() {
    if (_undoHistory.isEmpty) return;
    setState(() {
      _redoHistory.add(List<_OrganizerPage>.of(_pages));
      _pages = _undoHistory.removeLast();
      _selectedIds.removeWhere((id) => !_pages.any((page) => page.id == id));
    });
  }

  void _redo() {
    if (_redoHistory.isEmpty) return;
    setState(() {
      _undoHistory.add(List<_OrganizerPage>.of(_pages));
      if (_undoHistory.length > 50) _undoHistory.removeAt(0);
      _pages = _redoHistory.removeLast();
      _selectedIds.removeWhere((id) => !_pages.any((page) => page.id == id));
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _pages.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_pages.map((page) => page.id));
      }
    });
  }

  void _rotateSelected() {
    if (_selectedIds.isEmpty) return;
    _commit([
      for (final page in _pages)
        if (_selectedIds.contains(page.id))
          page.copyWith(clockwiseQuarterTurns: page.clockwiseQuarterTurns + 1)
        else
          page,
    ]);
  }

  void _duplicateSelected() {
    if (_selectedIds.isEmpty) return;
    final duplicates = <_OrganizerPage>[];
    final next = <_OrganizerPage>[];
    for (final page in _pages) {
      next.add(page);
      if (_selectedIds.contains(page.id)) {
        final duplicate = page.copyWith(id: _nextId++);
        next.add(duplicate);
        duplicates.add(duplicate);
      }
    }
    _commit(next);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(duplicates.map((page) => page.id));
    });
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    _commit(_pages.where((page) => !_selectedIds.contains(page.id)).toList());
    setState(() => _selectedIds.clear());
  }

  void _keepSelected() {
    if (_selectedIds.isEmpty || _selectedIds.length == _pages.length) return;
    _commit(_pages.where((page) => _selectedIds.contains(page.id)).toList());
  }

  void _reorder(int oldIndex, int newIndex) {
    final next = List<_OrganizerPage>.of(_pages);
    final page = next.removeAt(oldIndex);
    next.insert(newIndex, page);
    _commit(next);
  }

  PdfPageRotation _previewRotation(_OrganizerPage page) {
    var rotation =
        _documents[page.sourcePath]!.pages[page.sourcePageNumber - 1].rotation;
    for (var i = 0; i < page.normalizedQuarterTurns; i++) {
      rotation = rotation.rotateCW90;
    }
    return rotation;
  }

  String get _suggestedName {
    if (_pages.isEmpty) return 'organized.pdf';
    final stem = p.basenameWithoutExtension(_pages.first.sourcePath);
    return '${stem}_organized.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(pdfJobNotifierProvider);
    final isRunning = progress.status == PdfJobStatus.running || isJobRunning;

    return FeatureScaffold(
      title: PdfFeatureType.pageEditor.label,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isRunning || _loadingPages
                        ? null
                        : _choosePrimaryPdf,
                    icon: const Icon(Icons.folder_open),
                    label: Text(_pages.isEmpty ? 'Choose PDF' : 'Replace PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isRunning || _loadingPages || _pages.isEmpty
                        ? null
                        : _appendPdfs,
                    icon: const Icon(Icons.add),
                    label: const Text('Add PDF'),
                  ),
                ),
              ],
            ),
          ),
          if (_loadingPages) const LinearProgressIndicator(),
          if (_pages.isNotEmpty)
            _OrganizerToolbar(
              selectedCount: _selectedIds.length,
              pageCount: _pages.length,
              canUndo: _undoHistory.isNotEmpty && !isRunning,
              canRedo: _redoHistory.isNotEmpty && !isRunning,
              enabled: !isRunning,
              onSelectAll: _toggleSelectAll,
              onRotate: _rotateSelected,
              onDuplicate: _duplicateSelected,
              onKeepOnly: _keepSelected,
              onDelete: _deleteSelected,
              onUndo: _undo,
              onRedo: _redo,
            ),
          Expanded(
            child: _pages.isEmpty
                ? const EmptyState(
                    message:
                        'Choose a PDF, then drag pages to reorder them. You can also rotate, duplicate, insert, or remove pages.',
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    buildDefaultDragHandles: false,
                    itemCount: _pages.length,
                    onReorderItem: isRunning ? (_, _) {} : _reorder,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      final selected = _selectedIds.contains(page.id);
                      return _PageOrganizerTile(
                        key: ValueKey(page.id),
                        page: page,
                        index: index,
                        document: _documents[page.sourcePath],
                        rotation: _previewRotation(page),
                        selected: selected,
                        enabled: !isRunning,
                        showSourceName: _documents.length > 1,
                        onToggleSelection: () => _toggleSelection(page.id),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildJobStatus(progress),
                const SizedBox(height: 8),
                AppPrimaryButton(
                  label: 'Save organized PDF',
                  isLoading: isRunning,
                  onPressed: _pages.isEmpty || isRunning || _loadingPages
                      ? null
                      : () => runPdfJob(
                          feature: PdfFeatureType.pageEditor,
                          suggestedName: _suggestedName,
                          task: (reporter) => ref
                              .read(pdfProcessingServiceProvider)
                              .organizePages(
                                operations: [
                                  for (final page in _pages)
                                    PdfPageOperation(
                                      sourcePath: page.sourcePath,
                                      pageNumber: page.sourcePageNumber,
                                      clockwiseQuarterTurns:
                                          page.clockwiseQuarterTurns,
                                    ),
                                ],
                                suggestedName: _suggestedName,
                                onProgress: (current, total, message) =>
                                    reporter.update(current, total, message),
                                cancellationToken: reporter.cancellationToken,
                              ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizerToolbar extends StatelessWidget {
  const _OrganizerToolbar({
    required this.selectedCount,
    required this.pageCount,
    required this.canUndo,
    required this.canRedo,
    required this.enabled,
    required this.onSelectAll,
    required this.onRotate,
    required this.onDuplicate,
    required this.onKeepOnly,
    required this.onDelete,
    required this.onUndo,
    required this.onRedo,
  });

  final int selectedCount;
  final int pageCount;
  final bool canUndo;
  final bool canRedo;
  final bool enabled;
  final VoidCallback onSelectAll;
  final VoidCallback onRotate;
  final VoidCallback onDuplicate;
  final VoidCallback onKeepOnly;
  final VoidCallback onDelete;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCount > 0;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: enabled ? onSelectAll : null,
                  child: Text(
                    selectedCount == pageCount
                        ? 'Clear selection'
                        : hasSelection
                        ? 'Select all ($selectedCount selected)'
                        : 'Select all',
                  ),
                ),
                const Spacer(),
                Text('$pageCount pages'),
                IconButton(
                  tooltip: 'Undo',
                  onPressed: canUndo ? onUndo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Redo',
                  onPressed: canRedo ? onRedo : null,
                  icon: const Icon(Icons.redo),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Rotate selected',
                  onPressed: enabled && hasSelection ? onRotate : null,
                  icon: const Icon(Icons.rotate_right),
                ),
                IconButton(
                  tooltip: 'Duplicate selected',
                  onPressed: enabled && hasSelection ? onDuplicate : null,
                  icon: const Icon(Icons.control_point_duplicate_outlined),
                ),
                IconButton(
                  tooltip: 'Keep selected pages only',
                  onPressed:
                      enabled && hasSelection && selectedCount < pageCount
                      ? onKeepOnly
                      : null,
                  icon: const Icon(Icons.filter_center_focus),
                ),
                IconButton(
                  tooltip: 'Remove selected',
                  onPressed: enabled && hasSelection ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PageOrganizerTile extends StatelessWidget {
  const _PageOrganizerTile({
    super.key,
    required this.page,
    required this.index,
    required this.document,
    required this.rotation,
    required this.selected,
    required this.enabled,
    required this.showSourceName,
    required this.onToggleSelection,
  });

  final _OrganizerPage page;
  final int index;
  final PdfDocument? document;
  final PdfPageRotation rotation;
  final bool selected;
  final bool enabled;
  final bool showSourceName;
  final VoidCallback onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: selected ? scheme.secondaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onToggleSelection : null,
        child: SizedBox(
          height: 150,
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => onToggleSelection() : null,
              ),
              Container(
                width: 100,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: scheme.surface,
                child: PdfPageView(
                  document: document,
                  pageNumber: page.sourcePageNumber,
                  rotationOverride: rotation,
                  maximumDpi: 96,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page ${page.sourcePageNumber}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('Output position ${index + 1}'),
                    if (page.normalizedQuarterTurns != 0)
                      Text('${page.normalizedQuarterTurns * 90}° clockwise'),
                    if (showSourceName)
                      Text(
                        p.basename(page.sourcePath),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                enabled: enabled,
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizerPage {
  const _OrganizerPage({
    required this.id,
    required this.sourcePath,
    required this.sourcePageNumber,
    this.clockwiseQuarterTurns = 0,
  });

  final int id;
  final String sourcePath;
  final int sourcePageNumber;
  final int clockwiseQuarterTurns;

  int get normalizedQuarterTurns => ((clockwiseQuarterTurns % 4) + 4) % 4;

  _OrganizerPage copyWith({int? id, int? clockwiseQuarterTurns}) {
    return _OrganizerPage(
      id: id ?? this.id,
      sourcePath: sourcePath,
      sourcePageNumber: sourcePageNumber,
      clockwiseQuarterTurns:
          clockwiseQuarterTurns ?? this.clockwiseQuarterTurns,
    );
  }
}
