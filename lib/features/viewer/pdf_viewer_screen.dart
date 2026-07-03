import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../../core/pdf/pdfrx_initializer.dart';
import '../../core/di/providers.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/app_widgets.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  const PdfViewerScreen({super.key, required this.filePath, this.password});

  final String filePath;
  final String? password;

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  final _controller = PdfViewerController();
  bool _pdfReady = false;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      await PdfrxInitializer.ensureInitialized();
      if (mounted) setState(() => _pdfReady = true);
    } catch (e) {
      if (mounted) setState(() => _initError = e);
    }
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
      await File(widget.filePath).rename(newPath);

      final existing = await recentFiles.findByPath(widget.filePath);
      if (existing != null) {
        await recentFiles.renameRecentFile(
          id: existing.id,
          newName: p.basename(newPath),
        );
      }

      if (mounted) {
        context.replace('/viewer', extra: newPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          p.basename(widget.filePath),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'Zoom in',
            onPressed: () => _controller.zoomUp(),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'Zoom out',
            onPressed: () => _controller.zoomDown(),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () =>
                ref.read(shareServiceProvider).shareFile(widget.filePath),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final shareService = ref.read(shareServiceProvider);
              switch (value) {
                case 'rename':
                  await _rename();
                case 'delete':
                  await _delete();
                case 'external':
                  await shareService.openFile(widget.filePath);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
              PopupMenuItem(
                value: 'external',
                child: Text('Open with another app'),
              ),
            ],
          ),
        ],
      ),
      body: PdfViewer.file(
        widget.filePath,
        passwordProvider: widget.password == null ? null : () => widget.password!,
        controller: _controller,
        params: const PdfViewerParams(
          sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
            minScale: 0.5,
            maxScale: 8,
          ),
          panEnabled: true,
          scaleEnabled: true,
        ),
      ),
    );
  }
}

void openPdfViewer(BuildContext context, String filePath, {String? password}) {
  context.push('/viewer', extra: PdfViewerArgs(filePath: filePath, password: password));
}

class PdfViewerArgs {
  const PdfViewerArgs({required this.filePath, this.password});

  final String filePath;
  final String? password;
}
