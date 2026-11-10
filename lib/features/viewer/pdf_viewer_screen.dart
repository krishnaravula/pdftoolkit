import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../../core/di/providers.dart';
import '../../core/pdf/pdfrx_initializer.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/local/app_preferences.dart';
import '../shared/feature_scaffold.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.filePath,
    this.password,
    this.readingPositionKey,
  });

  final String filePath;
  final String? password;
  final String? readingPositionKey;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  final PdfViewerController _controller = PdfViewerController();
  final _viewerSession = Object();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pageController = TextEditingController();
  PdfTextSearcher? _textSearcher;

  Timer? _searchDebounce;
  Timer? _positionDebounce;
  PdfDocument? _document;
  List<PdfOutlineNode> _outline = const [];
  bool _pdfReady = false;
  bool _viewerReady = false;
  bool _searchMode = false;
  bool _loadingOutline = false;
  int _initialPageNumber = 1;
  int _currentPageNumber = 1;
  int _pageCount = 0;
  Object? _initError;
  AppPreferences? _readingPreferences;
  String? _nextPassword;
  bool _passwordAttempted = false;
  bool _requestingPassword = false;

  String get _documentKey =>
      widget.readingPositionKey ?? File(widget.filePath).absolute.path;

  bool get _isTemporaryExternalPdf {
    final normalized = widget.filePath.replaceAll('\\', '/');
    return normalized.contains('/cache/opened_pdfs/');
  }

  @override
  void initState() {
    super.initState();
    _nextPassword = widget.password;
    _initPdf();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _positionDebounce?.cancel();
    unawaited(_saveReadingPosition());
    final searcher = _textSearcher;
    if (searcher != null) {
      searcher
        ..removeListener(_onSearchUpdated)
        ..dispose();
    }
    _searchController.dispose();
    _pageController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initPdf() async {
    try {
      await PdfrxInitializer.ensureInitialized();
      var initialPage = 1;
      try {
        final prefs = await ref.read(appPreferencesProvider.future);
        _readingPreferences = prefs;
        initialPage = prefs.readingPageFor(_documentKey);
      } catch (_) {
        // A preferences failure should never prevent the document from opening.
      }
      if (mounted) {
        setState(() {
          _initialPageNumber = initialPage;
          _currentPageNumber = initialPage;
          _pdfReady = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _initError = e);
    }
  }

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    if (!mounted) return;
    _textSearcher ??= PdfTextSearcher(controller)
      ..addListener(_onSearchUpdated);
    final safePage = document.pages.isEmpty
        ? 1
        : _initialPageNumber.clamp(1, document.pages.length).toInt();
    setState(() {
      _document = document;
      _viewerReady = true;
      _pageCount = document.pages.length;
      _currentPageNumber = safePage;
    });
    if (safePage != _initialPageNumber) {
      unawaited(controller.goToPage(pageNumber: safePage));
    }
    unawaited(_loadOutline(document));
  }

  Future<void> _loadOutline(PdfDocument document) async {
    setState(() => _loadingOutline = true);
    try {
      final outline = await document.loadOutline();
      if (mounted && identical(_document, document)) {
        setState(() => _outline = outline);
      }
    } catch (_) {
      if (mounted && identical(_document, document)) {
        setState(() => _outline = const []);
      }
    } finally {
      if (mounted && identical(_document, document)) {
        setState(() => _loadingOutline = false);
      }
    }
  }

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null || pageNumber < 1) return;
    if (mounted && pageNumber != _currentPageNumber) {
      setState(() => _currentPageNumber = pageNumber);
    }
    _positionDebounce?.cancel();
    _positionDebounce = Timer(
      const Duration(milliseconds: 500),
      _saveReadingPosition,
    );
  }

  Future<void> _saveReadingPosition() async {
    final prefs = _readingPreferences;
    if (!_viewerReady || prefs == null || _currentPageNumber < 1) return;
    try {
      await prefs.setReadingPage(_documentKey, _currentPageNumber);
    } catch (_) {
      // Reading-position persistence is helpful, but never reading-critical.
    }
  }

  void _onSearchUpdated() {
    if (mounted) setState(() {});
  }

  void _setSearchMode(bool enabled) {
    _searchDebounce?.cancel();
    setState(() => _searchMode = enabled);
    if (enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_searchFocusNode);
      });
    } else {
      _searchController.clear();
      _textSearcher?.resetTextSearch();
    }
  }

  final FocusNode _searchFocusNode = FocusNode();

  void _search(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _textSearcher?.resetTextSearch();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _textSearcher?.startTextSearch(
        query,
        caseInsensitive: true,
        goToFirstMatch: true,
        searchImmediately: true,
      );
    });
  }

  String get _searchStatus {
    if (_searchController.text.trim().isEmpty) return 'Enter text to search';
    final searcher = _textSearcher;
    if (searcher == null) return 'Opening PDF…';
    final matches = searcher.matches.length;
    final current = searcher.currentIndex;
    if (matches == 0) {
      return searcher.isSearching ? 'Searching…' : 'No matches';
    }
    final position = current == null ? 1 : current + 1;
    return searcher.isSearching
        ? '$position of $matches+'
        : '$position of $matches';
  }

  Future<void> _showDocumentNavigation() async {
    final document = _document;
    if (document == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.78,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.grid_view), text: 'Pages'),
                  Tab(icon: Icon(Icons.format_list_bulleted), text: 'Outline'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ThumbnailGrid(
                      document: document,
                      currentPage: _currentPageNumber,
                      onPageSelected: (pageNumber) {
                        Navigator.pop(sheetContext);
                        _controller.goToPage(pageNumber: pageNumber);
                      },
                    ),
                    _OutlineList(
                      outline: _outline,
                      loading: _loadingOutline,
                      onSelected: (destination) {
                        Navigator.pop(sheetContext);
                        _controller.goToDest(destination);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPageJump() async {
    if (!_viewerReady || _pageCount < 1) return;
    _pageController.text = _currentPageNumber.toString();
    final selectedPage = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: _pageController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1–$_pageCount'),
          onSubmitted: (value) {
            final page = int.tryParse(value);
            if (page != null) Navigator.pop(dialogContext, page);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(_pageController.text),
            ),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (selectedPage == null || !mounted) return;
    if (selectedPage < 1 || selectedPage > _pageCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a page from 1 to $_pageCount.')),
      );
      return;
    }
    await _controller.goToPage(pageNumber: selectedPage);
  }

  Future<void> _rename() async {
    final currentName = p.basename(widget.filePath);
    final controller = TextEditingController(
      text: p.basenameWithoutExtension(currentName),
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            suffixText: '.pdf',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || !mounted) return;

    try {
      final recentFiles = ref.read(recentFilesServiceProvider);
      final sanitized = FileUtils.sanitizeFileName(newName);
      if (sanitized.isEmpty) return;
      final newFileName = sanitized.toLowerCase().endsWith('.pdf')
          ? sanitized
          : '$sanitized.pdf';
      final newPath = p.join(p.dirname(widget.filePath), newFileName);
      if (newPath != widget.filePath && File(newPath).existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A file with that name already exists.'),
            ),
          );
        }
        return;
      }
      final existing = await recentFiles.findByPath(widget.filePath);
      if (existing != null) {
        await recentFiles.renameRecentFile(
          id: existing.id,
          newName: p.basename(newPath),
        );
      } else {
        await File(widget.filePath).rename(newPath);
      }

      final prefs = await ref.read(appPreferencesProvider.future);
      await prefs.setReadingPage(
        File(newPath).absolute.path,
        _currentPageNumber,
      );

      if (mounted) context.replace('/viewer', extra: newPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    }
  }

  Future<void> _delete() async {
    final prefs = await ref.read(appPreferencesProvider.future);
    final confirmed = !prefs.confirmBeforeDeletingFiles
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete file?'),
              content: const Text('This will permanently delete the PDF file.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );

    if (confirmed != true || !mounted) return;

    try {
      final recentFiles = ref.read(recentFilesServiceProvider);
      final existing = await recentFiles.findByPath(widget.filePath);
      if (existing != null) {
        await recentFiles.deleteRecentFile(existing.id);
      } else {
        final file = File(widget.filePath);
        if (await file.exists()) await file.delete();
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    }
  }

  Future<void> _saveCopyToDocuments() async {
    try {
      await ref
          .read(storageRepositoryProvider)
          .exportPdfToDocuments(
            File(widget.filePath),
            p.basename(widget.filePath),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copy saved to Documents/PDF Tools')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
    }
  }

  Future<void> _retryDocument(PdfDocumentRef documentRef) async {
    try {
      await documentRef.resolveListenable().load(forceReload: true);
    } catch (_) {
      // PdfViewer rebuilds its error banner from the listenable's error state.
    }
  }

  String? _providePassword() {
    final password = _nextPassword;
    _nextPassword = null;
    if (password != null) _passwordAttempted = true;
    return password;
  }

  Future<void> _retryWithPassword(PdfDocumentRef documentRef) async {
    if (_requestingPassword) return;
    _requestingPassword = true;
    try {
      final password = await promptPassword(context);
      if (!mounted || password == null || password.isEmpty) return;
      _nextPassword = password;
      await _retryDocument(documentRef);
    } finally {
      _nextPassword = null;
      _requestingPassword = false;
    }
  }

  Widget _buildDocumentError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
    PdfDocumentRef documentRef,
  ) {
    final needsPassword = error is PdfPasswordException;
    final message = needsPassword
        ? (_passwordAttempted
              ? 'Incorrect PDF password.'
              : 'This PDF is password-protected.')
        : userFriendlyError(error);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to display this PDF',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: needsPassword
                    ? () => _retryWithPassword(documentRef)
                    : () => _retryDocument(documentRef),
                icon: Icon(needsPassword ? Icons.lock_open : Icons.refresh),
                label: Text(needsPassword ? 'Enter password' : 'Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_searchMode) {
      return [
        IconButton(
          tooltip: 'Previous match',
          onPressed: _textSearcher?.hasMatches == true
              ? _textSearcher!.goToPrevMatch
              : null,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: 'Next match',
          onPressed: _textSearcher?.hasMatches == true
              ? _textSearcher!.goToNextMatch
              : null,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        IconButton(
          tooltip: 'Close search',
          onPressed: () => _setSearchMode(false),
          icon: const Icon(Icons.close),
        ),
      ];
    }

    return [
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Search text',
        onPressed: _viewerReady ? () => _setSearchMode(true) : null,
      ),
      IconButton(
        icon: const Icon(Icons.view_sidebar_outlined),
        tooltip: 'Pages and outline',
        onPressed: _viewerReady ? _showDocumentNavigation : null,
      ),
      if (_isTemporaryExternalPdf)
        IconButton(
          icon: const Icon(Icons.save_alt),
          tooltip: 'Save a copy',
          onPressed: _saveCopyToDocuments,
        ),
      PopupMenuButton<String>(
        onSelected: (value) async {
          final shareService = ref.read(shareServiceProvider);
          switch (value) {
            case 'organize':
              await _saveReadingPosition();
              if (mounted) context.push('/page-editor', extra: widget.filePath);
            case 'esign':
              if (mounted) context.push('/esign', extra: widget.filePath);
            case 'share':
              await shareService.shareFile(widget.filePath);
            case 'save_copy':
              await _saveCopyToDocuments();
            case 'rename':
              await _rename();
            case 'delete':
              await _delete();
            case 'external':
              await shareService.openFile(widget.filePath);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'organize',
            child: ListTile(
              leading: Icon(Icons.dashboard_customize_outlined),
              title: Text('Organize pages'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'esign',
            child: ListTile(
              leading: Icon(Icons.draw_outlined),
              title: Text('Sign PDF'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'share',
            child: ListTile(
              leading: Icon(Icons.share_outlined),
              title: Text('Share'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (!_isTemporaryExternalPdf)
            const PopupMenuItem(
              value: 'save_copy',
              child: Text('Save copy to Documents'),
            ),
          if (!_isTemporaryExternalPdf)
            const PopupMenuItem(value: 'rename', child: Text('Rename')),
          if (!_isTemporaryExternalPdf)
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          const PopupMenuItem(
            value: 'external',
            child: Text('Open with another app'),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(p.basename(widget.filePath))),
        body: EmptyState(message: userFriendlyError(_initError!)),
      );
    }

    if (!_pdfReady) {
      return Scaffold(
        appBar: AppBar(title: Text(p.basename(widget.filePath))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final file = File(widget.filePath);
    if (!file.existsSync()) {
      return Scaffold(
        appBar: AppBar(title: Text(p.basename(widget.filePath))),
        body: const EmptyState(
          message: 'File not found. It may have been moved or deleted.',
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: _searchMode
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: const InputDecoration(
                  hintText: 'Search this PDF',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onChanged: _search,
                onSubmitted: _search,
              )
            : Text(
                p.basename(widget.filePath),
                overflow: TextOverflow.ellipsis,
              ),
        actions: _buildAppBarActions(),
      ),
      body: PdfViewer(
        PdfDocumentRefFile(
          widget.filePath,
          key: PdfDocumentRefKey(widget.filePath, [_viewerSession]),
          passwordProvider: _providePassword,
        ),
        controller: _controller,
        params: PdfViewerParams(
          sizeDelegateProvider: const PdfViewerSizeDelegateProviderLegacy(
            minScale: 0.5,
            maxScale: 8,
          ),
          panEnabled: true,
          scaleEnabled: true,
          limitRenderingCache: true,
          enableKeyboardNavigation: true,
          textSelectionParams: const PdfTextSelectionParams(
            enabled: true,
            enableSelectionHandles: true,
            showContextMenuAutomatically: true,
          ),
          matchTextColor: scheme.tertiaryContainer.withValues(alpha: 0.75),
          activeMatchTextColor: scheme.primaryContainer.withValues(alpha: 0.9),
          pagePaintCallbacks: [
            if (_textSearcher != null)
              _textSearcher!.pageTextMatchPaintCallback,
          ],
          calculateInitialPageNumber: (document, _) => document.pages.isEmpty
              ? 1
              : _initialPageNumber.clamp(1, document.pages.length).toInt(),
          onViewerReady: _onViewerReady,
          onPageChanged: _onPageChanged,
          errorBannerBuilder: _buildDocumentError,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          color: scheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (_searchMode) ...[
                  if (_textSearcher?.isSearching == true)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.zoom_out),
                    tooltip: 'Zoom out',
                    onPressed: _viewerReady ? _controller.zoomDown : null,
                  ),
                  Expanded(
                    child: Center(
                      heightFactor: 1,
                      child: TextButton.icon(
                        onPressed: _showPageJump,
                        icon: const Icon(Icons.find_in_page_outlined),
                        label: Text(
                          _pageCount == 0
                              ? 'Loading pages…'
                              : 'Page $_currentPageNumber of $_pageCount',
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in),
                    tooltip: 'Zoom in',
                    onPressed: _viewerReady ? _controller.zoomUp : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailGrid extends StatelessWidget {
  const _ThumbnailGrid({
    required this.document,
    required this.currentPage,
    required this.onPageSelected,
  });

  final PdfDocument document;
  final int currentPage;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        childAspectRatio: 0.72,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: document.pages.length,
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        final selected = pageNumber == currentPage;
        return Card(
          color: selected ? scheme.primaryContainer : null,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onPageSelected(pageNumber),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  Expanded(
                    child: PdfPageView(
                      document: document,
                      pageNumber: pageNumber,
                      maximumDpi: 96,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$pageNumber',
                    style: selected
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OutlineList extends StatelessWidget {
  const _OutlineList({
    required this.outline,
    required this.loading,
    required this.onSelected,
  });

  final List<PdfOutlineNode> outline;
  final bool loading;
  final ValueChanged<PdfDest?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final entries = _flatten(outline);
    if (entries.isEmpty) {
      return const EmptyState(
        message: 'This PDF does not contain a document outline.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          contentPadding: EdgeInsetsDirectional.only(
            start: 16.0 + entry.depth * 20.0,
            end: 16,
          ),
          leading: Icon(
            entry.depth == 0
                ? Icons.bookmark_outline
                : Icons.subdirectory_arrow_right,
          ),
          title: Text(
            entry.node.title.trim().isEmpty
                ? 'Untitled section'
                : entry.node.title,
          ),
          enabled: entry.node.dest != null,
          onTap: entry.node.dest == null
              ? null
              : () => onSelected(entry.node.dest),
        );
      },
    );
  }

  static List<_OutlineEntry> _flatten(
    List<PdfOutlineNode> nodes, [
    int depth = 0,
  ]) {
    final entries = <_OutlineEntry>[];
    for (final node in nodes) {
      entries.add(_OutlineEntry(node, depth));
      entries.addAll(_flatten(node.children, depth + 1));
    }
    return entries;
  }
}

class _OutlineEntry {
  const _OutlineEntry(this.node, this.depth);

  final PdfOutlineNode node;
  final int depth;
}

void openPdfViewer(BuildContext context, String filePath, {String? password}) {
  context.push(
    '/viewer',
    extra: PdfViewerArgs(filePath: filePath, password: password),
  );
}

class PdfViewerArgs {
  const PdfViewerArgs({
    required this.filePath,
    this.password,
    this.readingPositionKey,
  });

  final String filePath;
  final String? password;
  final String? readingPositionKey;
}
