import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/providers.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/local/app_preferences.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/recent_file.dart';
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
  bool _saving = false;
  final _savedPaths = <String>[];
  final _exportedUris = <String?>[];
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
    if (_saving) return;
    final fileSave = ref.read(fileSaveServiceProvider);
    final pendingFiles = widget.pendingFiles;
    final feature = widget.feature;
    final names = _nameControllers.map((c) => c.text.trim()).toList();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      for (var i = _savedPaths.length; i < pendingFiles.length; i++) {
        final tempPath = pendingFiles[i].tempPath;
        final file = await _storage.saveProcessedPdfToAppStorage(
          File(tempPath),
          names[i],
          keepSource: true,
        );
        try {
          await _recentFilesService.addFromOutput(
            outputPath: file.path,
            feature: feature,
          );
        } catch (_) {
          try {
            await file.delete();
          } on FileSystemException {
            debugPrint('Could not remove an unregistered PDF result.');
          }
          rethrow;
        }
        _savedPaths.add(file.path);
        _exportedUris.add(null);
        await fileSave.deleteTempFile(tempPath);
      }

      if (!mounted) return;
      setState(() => _saving = false);

      await _autoExportIfPreferred();
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
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _autoExportIfPreferred() async {
    final prefs = await ref.read(appPreferencesProvider.future);
    switch (prefs.defaultSaveLocation) {
      case DefaultSaveLocation.askEveryTime:
        await _askWhereToSave();
        return;
      case DefaultSaveLocation.documentsPdfTools:
        await _exportToDocuments();
        return;
      case DefaultSaveLocation.previouslySelected:
        await _exportToPreferredFolder();
    }
  }

  Future<void> _askWhereToSave() async {
    if (!mounted) return;
    final choice = await showModalBottomSheet<_ExportChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Where should this PDF be saved?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Documents/PDF Tools'),
                subtitle: const Text('Easy to find in the Android Files app'),
                onTap: () => Navigator.pop(context, _ExportChoice.documents),
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('Choose another folder'),
                subtitle: const Text('Select a folder and remember access'),
                onTap: () => Navigator.pop(context, _ExportChoice.folder),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Keep in PDF Tools only'),
                subtitle: const Text('Available from the Recent tab'),
                onTap: () => Navigator.pop(context, _ExportChoice.appOnly),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    switch (choice) {
      case _ExportChoice.documents:
        await _exportToDocuments();
      case _ExportChoice.folder:
        await _saveToFolder(forcePick: true);
      case _ExportChoice.appOnly:
      case null:
        return;
    }
  }

  Future<void> _exportToDocuments() async {
    final storage = ref.read(storageRepositoryProvider);
    try {
      for (var i = 0; i < _savedPaths.length; i++) {
        if (_exportedUris[i] != null) continue;
        final exported = await storage.exportPdfToDocuments(
          File(_savedPaths[i]),
          _nameControllers[i].text.trim(),
        );
        await _recordExport(i, exported);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Documents/PDF Tools')),
      );
    } catch (_) {
      debugPrint('Documents export failed.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PDF saved securely in the app. Documents export failed.',
          ),
        ),
      );
    }
  }

  Future<void> _exportToPreferredFolder() async {
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
        if (_exportedUris[i] != null) continue;
        final exported = await storage.exportPdfToTreeUri(
          treeUri,
          File(_savedPaths[i]),
          _nameControllers[i].text.trim(),
        );
        await _recordExport(i, exported);
      }
      if (!mounted) return;
      final folderLabel = storage.displayNameForTreeUri(treeUri);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $folderLabel'),
          action: SnackBarAction(
            label: 'Change Folder',
            onPressed: () => _saveToFolder(forcePick: true),
          ),
        ),
      );
    } catch (_) {
      debugPrint('Auto-export failed.');
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

  Future<void> _recordExport(int index, Uri exported) async {
    if (mounted) {
      setState(() => _exportedUris[index] = exported.toString());
    } else {
      _exportedUris[index] = exported.toString();
    }
    final recent = await _recentFilesService.findByPath(_savedPaths[index]);
    if (recent != null) {
      await _recentFilesService.setExportedUri(
        id: recent.id,
        exportedUri: exported.toString(),
      );
    }
  }

  Future<void> _saveToFolder({bool forcePick = false, int? onlyIndex}) async {
    final storage = ref.read(storageRepositoryProvider);
    var treeUri = forcePick ? null : await storage.getPreferredExportTreeUri();
    if (treeUri == null ||
        !await storage.hasPersistedWritePermission(treeUri)) {
      treeUri = await storage.pickExportTreeUri();
      if (treeUri == null) return;
      await storage.persistTreeUriPermission(treeUri);
      await storage.setPreferredExportTreeUri(treeUri);
    }
    try {
      final indices = onlyIndex == null
          ? List<int>.generate(_savedPaths.length, (index) => index)
          : <int>[onlyIndex];
      for (final i in indices) {
        final exported = await storage.exportPdfToTreeUri(
          treeUri,
          File(_savedPaths[i]),
          _nameControllers[i].text.trim(),
        );
        await _recordExport(i, exported);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${storage.displayNameForTreeUri(treeUri)}'),
          action: SnackBarAction(label: 'Open', onPressed: _openBestAvailable),
        ),
      );
    } catch (_) {
      debugPrint('Manual folder export failed.');
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

  Future<void> _renameFile(int index) async {
    if (index < 0 || index >= _savedPaths.length) return;
    final oldPath = _savedPaths[index];
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
    final recent = await ref
        .read(recentFilesServiceProvider)
        .findByPath(oldPath);
    if (recent != null) {
      await ref
          .read(recentFilesServiceProvider)
          .renameRecentFile(id: recent.id, newName: newName);
    } else {
      await file.rename(newPath);
    }
    if (!mounted) return;
    setState(() {
      _savedPaths[index] = newPath;
      _nameControllers[index].text = newName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shareService = ref.read(shareServiceProvider);
    final recentFiles = ref.read(recentFilesServiceProvider);

    final incomplete = _savedPaths.length < widget.pendingFiles.length;
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(_saving || incomplete ? 'Save result' : 'Saved'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving
              ? null
              : () {
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
                _saving || incomplete
                    ? Icons.save_outlined
                    : Icons.check_circle_outline,
                size: 48,
                color: !_saving
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                _saving
                    ? 'Saving your PDF${widget.pendingFiles.length == 1 ? '' : 's'}…'
                    : incomplete
                    ? 'Saved ${_savedPaths.length} of ${widget.pendingFiles.length} PDFs'
                    : _savedPaths.length == 1
                    ? 'Your PDF is ready'
                    : '${_savedPaths.length} PDFs are ready',
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
                  itemCount: _saving ? 0 : _savedPaths.length,
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
                              recentFiles.formatLocationLabel(
                                RecentFileItem(
                                  id: '',
                                  displayName: p.basename(_savedPaths[index]),
                                  path: _savedPaths[index],
                                  sizeBytes: 0,
                                  createdAt: DateTime.now(),
                                  sourceFeature: widget.feature,
                                  exportedUri: _exportedUris[index],
                                ),
                              ),
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
                                  onPressed: () =>
                                      _saveToFolder(onlyIndex: index),
                                  icon: const Icon(Icons.folder_open),
                                  label: Text(
                                    _exportedUris[index] == null
                                        ? 'Choose folder'
                                        : 'Save another copy',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _renameFile(index),
                                  icon: const Icon(
                                    Icons.drive_file_rename_outline,
                                  ),
                                  label: const Text('Rename'),
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
              if (!_saving && incomplete)
                AppPrimaryButton(
                  label: 'Try again',
                  icon: Icons.refresh,
                  onPressed: _saveToAppStorageAndMaybeExport,
                )
              else if (!_saving && _savedPaths.length == 1)
                AppPrimaryButton(
                  label: 'Open PDF',
                  icon: Icons.visibility_outlined,
                  onPressed: () => _openInViewer(_savedPaths.first),
                )
              else if (!_saving)
                AppPrimaryButton(
                  label: 'Done',
                  icon: Icons.done,
                  onPressed: () {
                    widget.onDone?.call();
                    if (context.canPop()) context.pop();
                  },
                ),
              if (!_saving && !incomplete && _savedPaths.length == 1) ...[
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
            ],
          ),
        ),
      ),
    );
    return PopScope(canPop: !_saving, child: scaffold);
  }
}

enum _ExportChoice { documents, folder, appOnly }

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
