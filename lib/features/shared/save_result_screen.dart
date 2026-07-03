import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/providers.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../services/storage/file_save_service.dart';
import '../../services/storage/recent_files_service.dart';
import '../../services/storage/storage_repository.dart';

/// Unified save-result screen shown after every PDF operation.
class SaveResultScreen extends ConsumerStatefulWidget {
  const SaveResultScreen({
    super.key,
    required this.feature,
    required this.pendingFiles,
    this.onDone,
  });

  final PdfFeatureType feature;
  final List<PendingSaveFile> pendingFiles;
  final VoidCallback? onDone;

  @override
  ConsumerState<SaveResultScreen> createState() => _SaveResultScreenState();
}

class _SaveResultScreenState extends ConsumerState<SaveResultScreen> {
  late List<TextEditingController> _nameControllers;
  late final StorageRepository _storage;
  late final RecentFilesService _recentFilesService;
  bool _saving = true;
  List<String> _savedPaths = <String>[];
  List<String?> _exportedUris = <String?>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageRepositoryProvider);
    _recentFilesService = ref.read(recentFilesServiceProvider);
    final storage = _storage;
    _nameControllers = widget.pendingFiles
        .map(
          (f) => TextEditingController(
            text: _resolveInitialName(storage, f.suggestedName),
          ),
        )
        .toList();
    _saveToAppStorageAndMaybeExport();
  }

  String _resolveInitialName(dynamic storage, String suggestedName) {
    const legacyDefaults = <String>{
      'merged.pdf',
      'compressed.pdf',
      'split.pdf',
    };
    if (legacyDefaults.contains(suggestedName.toLowerCase())) {
      return storage.defaultFileNameForFeature(widget.feature);
    }
    return storage.ensurePdfFileName(suggestedName);
  }

  Future<void> _saveToAppStorageAndMaybeExport() async {
    try {
      final storage = ref.read(storageRepositoryProvider);
      final recentFiles = ref.read(recentFilesServiceProvider);
      final appSaved = <String>[];
      final exported = <String?>[];

      for (var i = 0; i < widget.pendingFiles.length; i++) {
        final pending = widget.pendingFiles[i];
        final source = File(pending.tempPath);
        final file = await storage.saveProcessedPdfToAppStorage(
          source,
          _nameControllers[i].text.trim(),
        );
        appSaved.add(file.path);
        exported.add(null);
      }

      for (var i = 0; i < widget.pendingFiles.length; i++) {
        await ref
            .read(fileSaveServiceProvider)
            .deleteTempFile(widget.pendingFiles[i].tempPath);
      }

      for (var i = 0; i < appSaved.length; i++) {
        await recentFiles.addFromOutput(
          outputPath: appSaved[i],
          feature: widget.feature,
          exportedUri: null,
        );
      }

      recentFiles.markResultScreenActivePaths(appSaved);
      _savedPaths = appSaved;
      _exportedUris = exported;

      await _autoExportIfPreferred();

      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFriendlyError(e);
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_savedPaths.isNotEmpty) {
      _recentFilesService.unmarkResultScreenActivePaths(_savedPaths);
    }
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _autoExportIfPreferred() async {
    final storage = ref.read(storageRepositoryProvider);
    final treeUri = await storage.getPreferredExportTreeUri();
    if (treeUri == null) return;
    final hasPermission = await storage.hasPersistedWritePermission(treeUri);
    if (!hasPermission) {
      await storage.setPreferredExportTreeUri(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Folder permission expired. Please choose a folder again.',
          ),
        ),
      );
      return;
    }
    try {
      for (var i = 0; i < _savedPaths.length; i++) {
        final exported = await storage.exportPdfToTreeUri(
          treeUri,
          File(_savedPaths[i]),
          _nameControllers[i].text.trim(),
        );
        _exportedUris[i] = exported.toString();
        final recent = await ref
            .read(recentFilesServiceProvider)
            .findByPath(_savedPaths[i]);
        if (recent != null) {
          await ref
              .read(recentFilesServiceProvider)
              .setExportedUri(id: recent.id, exportedUri: exported.toString());
        }
      }
      if (!mounted) return;
      final folderLabel = p.basename(treeUri.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $folderLabel'),
          action: SnackBarAction(
            label: 'Change Folder',
            onPressed: _saveToFolder,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Auto-export failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PDF saved in app. Could not export to selected folder.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveToFolder() async {
    final storage = ref.read(storageRepositoryProvider);
    var treeUri = await storage.getPreferredExportTreeUri();
    if (treeUri == null ||
        !await storage.hasPersistedWritePermission(treeUri)) {
      treeUri = await storage.pickExportTreeUri();
      if (treeUri == null) return;
      await storage.persistTreeUriPermission(treeUri);
      await storage.setPreferredExportTreeUri(treeUri);
    }
    try {
      for (var i = 0; i < _savedPaths.length; i++) {
        final exported = await storage.exportPdfToTreeUri(
          treeUri,
          File(_savedPaths[i]),
          _nameControllers[i].text.trim(),
        );
        _exportedUris[i] = exported.toString();
        final recent = await ref
            .read(recentFilesServiceProvider)
            .findByPath(_savedPaths[i]);
        if (recent != null) {
          await ref
              .read(recentFilesServiceProvider)
              .setExportedUri(id: recent.id, exportedUri: exported.toString());
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${p.basename(treeUri.path)}'),
          action: SnackBarAction(label: 'Open', onPressed: _openBestAvailable),
        ),
      );
    } catch (e, st) {
      debugPrint('Manual folder export failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PDF saved in app. Could not export to selected folder.',
          ),
        ),
      );
    }
  }

  void _openInViewer(String path) {
    context.push('/viewer', extra: path);
  }

  Future<void> _openBestAvailable() async {
    final shareService = ref.read(shareServiceProvider);
    final firstExported = _exportedUris.firstWhere(
      (u) => u != null,
      orElse: () => null,
    );
    if (firstExported != null) {
      final uri = Uri.parse(firstExported);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    await shareService.openFile(_savedPaths.first);
  }

  Future<void> _renameFirstFile() async {
    if (_savedPaths.isEmpty) return;
    final oldPath = _savedPaths.first;
    final oldName = p.basenameWithoutExtension(oldPath);
    final controller = TextEditingController(text: oldName);
    final newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File name',
            suffixText: '.pdf',
          ),
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
    if (newValue == null || newValue.isEmpty) return;
    final file = File(oldPath);
    if (!await file.exists()) return;
    final newName = _storage.ensurePdfFileName(newValue);
    final newPath = p.join(p.dirname(oldPath), newName);
    if (newPath != oldPath && await File(newPath).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A file with that name already exists.')),
      );
      return;
    }
    final renamed = await file.rename(newPath);
    final recent = await ref
        .read(recentFilesServiceProvider)
        .findByPath(oldPath);
    if (recent != null) {
      await ref
          .read(recentFilesServiceProvider)
          .renameRecentFile(id: recent.id, newName: newName);
    }
    if (!mounted) return;
    setState(() {
      _savedPaths[0] = renamed.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shareService = ref.read(shareServiceProvider);
    final recentFiles = ref.read(recentFilesServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_saving ? 'Save result' : 'Saved'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            widget.onDone?.call();
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _saving ? Icons.save_outlined : Icons.check_circle_outline,
                size: 48,
                color: !_saving
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                _saving
                    ? 'Saving your file(s) to app storage'
                    : '${_savedPaths.length} file(s) saved successfully',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_saving)
                const Center(child: CircularProgressIndicator())
              else
                const SizedBox.shrink(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _savedPaths.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              p.basename(_savedPaths[index]),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              recentFiles.formatLocation(_savedPaths[index]),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _openInViewer(_savedPaths[index]),
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('Open'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => shareService.shareFile(
                                    _savedPaths[index],
                                  ),
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _saveToFolder,
                                  icon: const Icon(Icons.folder_open),
                                  label: const Text('Save to Folder'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              AppPrimaryButton(
                label: 'Rename',
                icon: Icons.drive_file_rename_outline,
                isLoading: false,
                onPressed: _savedPaths.isEmpty ? null : _renameFirstFile,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  widget.onDone?.call();
                  if (context.canPop()) context.pop();
                },
                icon: const Icon(Icons.done),
                label: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigates to the save-result screen for one or more pending files.
void showSaveResult(
  BuildContext context, {
  required PdfFeatureType feature,
  required List<PendingSaveFile> files,
  VoidCallback? onDone,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => SaveResultScreen(
        feature: feature,
        pendingFiles: files,
        onDone: onDone,
      ),
    ),
  );
}

/// Shows save result for a single temp output file.
void showSingleSaveResult(
  BuildContext context, {
  required PdfFeatureType feature,
  required String tempPath,
  required String suggestedName,
  VoidCallback? onDone,
}) {
  showSaveResult(
    context,
    feature: feature,
    files: [PendingSaveFile(tempPath: tempPath, suggestedName: suggestedName)],
    onDone: onDone,
  );
}
