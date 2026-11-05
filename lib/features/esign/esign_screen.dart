import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/image_processing.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/pdf_job.dart';
import '../../domain/entities/pdf_stamp_placement.dart';
import '../shared/feature_scaffold.dart';

class EsignScreen extends ConsumerStatefulWidget {
  const EsignScreen({super.key, this.initialFilePath});

  final String? initialFilePath;

  @override
  ConsumerState<EsignScreen> createState() => _EsignScreenState();
}

class _EsignScreenState extends ConsumerState<EsignScreen> with PdfJobMixin {
  final PdfViewerController _viewerController = PdfViewerController();
  String? _inputPath;
  Uint8List? _savedSignature;
  List<_PlacedStamp> _stamps = [];
  int _pageCount = 0;
  int _currentPage = 1;
  bool _signatureWarningAccepted = false;
  bool _checkingSignatures = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _inputPath = widget.initialFilePath;
    _loadSavedSignature();
    final path = widget.initialFilePath;
    if (path != null) _checkExistingSignatures(path);
  }

  @override
  void didUpdateWidget(covariant EsignScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilePath != widget.initialFilePath &&
        widget.initialFilePath != null) {
      _setInputPath(widget.initialFilePath!);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSavedSignature() async {
    try {
      final signature = await ref
          .read(signatureStorageServiceProvider)
          .loadSignature();
      if (mounted) setState(() => _savedSignature = signature);
    } catch (_) {
      if (mounted) setState(() => _savedSignature = null);
    }
  }

  Future<void> _selectPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path != null) await _setInputPath(path);
  }

  Future<void> _setInputPath(String path) async {
    setState(() {
      _inputPath = path;
      _stamps = [];
      _pageCount = 0;
      _currentPage = 1;
      _signatureWarningAccepted = false;
      _loadError = null;
    });
    await _checkExistingSignatures(path);
  }

  Future<void> _checkExistingSignatures(String path) async {
    setState(() => _checkingSignatures = true);
    try {
      final count = await ref
          .read(pdfProcessingServiceProvider)
          .digitalSignatureCount(path);
      if (!mounted || _inputPath != path || count == 0) return;
      final proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_outlined),
          title: const Text('Existing digital signatures'),
          content: Text(
            'This PDF contains $count cryptographic digital '
            '${count == 1 ? 'signature' : 'signatures'}. Adding a visual mark '
            'to a copy may invalidate their verification. The original file '
            'will remain unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue with a copy'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (proceed == true) {
        setState(() => _signatureWarningAccepted = true);
      } else {
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (mounted && _inputPath == path) {
        setState(() => _loadError = userFriendlyError(error));
      }
    } finally {
      if (mounted && _inputPath == path) {
        setState(() => _checkingSignatures = false);
      }
    }
  }

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    if (!mounted) return;
    setState(() {
      _document = document;
      _pageCount = document.pages.length;
      _currentPage = _pageCount == 0 ? 1 : _currentPage.clamp(1, _pageCount);
    });
  }

  void _onPageChanged(int? page) {
    if (page == null || page < 1 || page == _currentPage) return;
    if (mounted) setState(() => _currentPage = page);
  }

  Future<void> _addSignature() async {
    final choice = await _showSignaturePicker();
    if (!mounted || choice == null) return;
    if (choice.saveForReuse) {
      try {
        await ref
            .read(signatureStorageServiceProvider)
            .saveSignature(choice.pngBytes);
        if (mounted) setState(() => _savedSignature = choice.pngBytes);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(userFriendlyError(error))));
        }
      }
    }
    if (mounted) await _placeNewStamp(choice.pngBytes);
  }

  Future<_SignatureChoice?> _showSignaturePicker() async {
    var saveForReuse = false;
    return showModalBottomSheet<_SignatureChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> choose(Future<Uint8List?> Function() create) async {
            try {
              final bytes = await create();
              if (bytes != null && sheetContext.mounted) {
                Navigator.pop(
                  sheetContext,
                  _SignatureChoice(bytes, saveForReuse),
                );
              }
            } catch (error) {
              if (!sheetContext.mounted) return;
              ScaffoldMessenger.of(
                sheetContext,
              ).showSnackBar(SnackBar(content: Text(userFriendlyError(error))));
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add a signature',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_savedSignature != null)
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Use saved signature'),
                      onTap: () => Navigator.pop(
                        sheetContext,
                        _SignatureChoice(_savedSignature!, false),
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.gesture),
                    title: const Text('Draw signature'),
                    onTap: () => choose(_drawSignature),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Type signature'),
                    onTap: () => choose(_typeSignature),
                  ),
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: const Text('Import signature image'),
                    onTap: () => choose(_importSignature),
                  ),
                  CheckboxListTile(
                    value: saveForReuse,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save this signature on this device'),
                    subtitle: const Text('You can delete it from this menu.'),
                    onChanged: (value) =>
                        setSheetState(() => saveForReuse = value ?? false),
                  ),
                  if (_savedSignature != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await ref
                              .read(signatureStorageServiceProvider)
                              .deleteSignature();
                          if (!sheetContext.mounted) return;
                          setState(() => _savedSignature = null);
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete saved signature'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Uint8List?> _drawSignature() => showDialog<Uint8List>(
    context: context,
    builder: (context) => const _DrawSignatureDialog(),
  );

  Future<Uint8List?> _typeSignature() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Type your signature'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Use signature'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return null;
    return _renderTextStamp(name, italic: true);
  }

  Future<Uint8List?> _importSignature() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) return null;
    return normalizeSignatureImageInIsolate(bytes);
  }

  Future<Uint8List> _renderTextStamp(String text, {bool italic = false}) async {
    const imageWidth = 1200.0;
    const imageHeight = 260.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, imageWidth, imageHeight),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xff183a72),
          fontSize: italic ? 118 : 72,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          fontFamily: italic ? 'cursive' : null,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: imageWidth - 40);
    painter.paint(canvas, Offset(20, (imageHeight - painter.height) / 2));
    final image = await recorder.endRecording().toImage(
      imageWidth.toInt(),
      imageHeight.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw const PdfProcessingException('Could not create the mark.');
    }
    return data.buffer.asUint8List();
  }

  Future<Uint8List> _renderDateStamp() =>
      _renderTextStamp(DateFormat.yMMMd().format(DateTime.now()));

  Future<void> _placeNewStamp(Uint8List bytes) async {
    final page = _currentPage.clamp(1, _pageCount == 0 ? 1 : _pageCount);
    final pageInfo = _documentPage(page);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final aspect = frame.image.width / frame.image.height;
    frame.image.dispose();
    codec.dispose();
    if (!mounted) return;
    const width = 0.34;
    final height = pageInfo == null
        ? 0.09
        : (width * pageInfo.width / pageInfo.height / aspect).clamp(
            0.035,
            0.24,
          );
    setState(() {
      _stamps = [
        ..._stamps,
        _PlacedStamp(
          pageNumber: page,
          left: 0.33,
          top: 0.74,
          width: width,
          height: height.toDouble(),
          pngBytes: bytes,
        ),
      ];
    });
  }

  PdfPage? _documentPage(int pageNumber) => _document?.pages.isEmpty == true
      ? null
      : (_document != null && pageNumber <= _document!.pages.length
            ? _document!.pages[pageNumber - 1]
            : null);

  PdfDocument? _document;

  Future<void> _addDate() async {
    try {
      await _placeNewStamp(await _renderDateStamp());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(error))));
      }
    }
  }

  Future<void> _saveSignedCopy() async {
    final inputPath = _inputPath;
    if (inputPath == null || _stamps.isEmpty) return;
    final stem = p.basenameWithoutExtension(inputPath);
    await runPdfJob(
      feature: PdfFeatureType.eSign,
      suggestedName: '${stem}_signed.pdf',
      task: (reporter) => ref
          .read(pdfProcessingServiceProvider)
          .applyVisualStamps(
            inputPath: inputPath,
            placements: [
              for (final stamp in _stamps)
                PdfStampPlacement(
                  pageNumber: stamp.pageNumber,
                  left: stamp.left,
                  top: stamp.top,
                  width: stamp.width,
                  height: stamp.height,
                  pngBytes: stamp.pngBytes,
                ),
            ],
            suggestedName: '${stem}_signed.pdf',
            acknowledgeExistingSignatures: _signatureWarningAccepted,
            onProgress: reporter.update,
            cancellationToken: reporter.cancellationToken,
          ),
      onDone: () => context.pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(pdfJobNotifierProvider);
    final running = progress.status == PdfJobStatus.running || isJobRunning;
    final path = _inputPath;
    return FeatureScaffold(
      title: PdfFeatureType.eSign.label,
      child: path == null
          ? _buildNoDocument(running)
          : Column(
              children: [
                MaterialBanner(
                  content: const Text(
                    'Visual signature only. This does not create a '
                    'certificate-based digital signature.',
                  ),
                  leading: const Icon(Icons.draw_outlined),
                  actions: [
                    TextButton(
                      onPressed: running ? null : _selectPdf,
                      child: const Text('Change PDF'),
                    ),
                  ],
                ),
                if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _loadError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: PdfViewer.file(
                    path,
                    controller: _viewerController,
                    params: PdfViewerParams(
                      onViewerReady: _onViewerReady,
                      onPageChanged: _onPageChanged,
                      pageOverlaysBuilder: (context, pageRect, page) => [
                        for (var index = 0; index < _stamps.length; index++)
                          if (_stamps[index].pageNumber == page.pageNumber)
                            _buildStampOverlay(index, pageRect),
                      ],
                    ),
                  ),
                ),
                if (_checkingSignatures)
                  const LinearProgressIndicator(minHeight: 2),
                if (_pageCount > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed: _currentPage <= 1
                              ? null
                              : () => _viewerController.goToPage(
                                  pageNumber: _currentPage - 1,
                                ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page $_currentPage of $_pageCount'),
                        IconButton(
                          tooltip: 'Next page',
                          onPressed: _currentPage >= _pageCount
                              ? null
                              : () => _viewerController.goToPage(
                                  pageNumber: _currentPage + 1,
                                ),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: running || _pageCount == 0
                                  ? null
                                  : _addSignature,
                              icon: const Icon(Icons.draw_outlined),
                              label: const Text('Add signature'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: running || _pageCount == 0
                                  ? null
                                  : _addDate,
                              icon: const Icon(Icons.event_outlined),
                              label: const Text('Add date'),
                            ),
                          ),
                        ],
                      ),
                      if (_stamps.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_stamps.length} mark(s). Drag to move; use the corner handle to resize.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (running) ...[
                        const SizedBox(height: 8),
                        buildJobStatus(progress),
                      ],
                      const SizedBox(height: 8),
                      AppPrimaryButton(
                        label: 'Save signed copy',
                        icon: Icons.save_outlined,
                        isLoading: running,
                        onPressed:
                            _stamps.isEmpty ||
                                running ||
                                _checkingSignatures ||
                                _loadError != null
                            ? null
                            : _saveSignedCopy,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNoDocument(bool running) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(
          child: EmptyState(
            icon: Icons.draw_outlined,
            message:
                'Choose a PDF, create or import a signature, and place it on the page.',
          ),
        ),
        AppPrimaryButton(
          label: 'Choose PDF',
          icon: Icons.folder_open,
          isLoading: running,
          onPressed: running ? null : _selectPdf,
        ),
      ],
    ),
  );

  Widget _buildStampOverlay(int index, Rect pageRect) {
    final stamp = _stamps[index];
    return Positioned(
      left: stamp.left * pageRect.width,
      top: stamp.top * pageRect.height,
      width: stamp.width * pageRect.width,
      height: stamp.height * pageRect.height,
      child: GestureDetector(
        onPanUpdate: (details) => setState(() {
          final current = _stamps[index];
          _stamps[index] = current.copyWith(
            left: (current.left + details.delta.dx / pageRect.width)
                .clamp(0.0, 1.0 - current.width)
                .toDouble(),
            top: (current.top + details.delta.dy / pageRect.height)
                .clamp(0.0, 1.0 - current.height)
                .toDouble(),
          );
        }),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(2),
                child: Image.memory(stamp.pngBytes, fit: BoxFit.fill),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  tooltip: 'Remove mark',
                  onPressed: () => setState(() => _stamps.removeAt(index)),
                  icon: const Icon(Icons.close, size: 16),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (details) => setState(() {
                    final current = _stamps[index];
                    final nextWidth =
                        (current.width + details.delta.dx / pageRect.width)
                            .clamp(0.08, 1.0 - current.left)
                            .toDouble();
                    final nextHeight =
                        (current.height + details.delta.dy / pageRect.height)
                            .clamp(0.035, 1.0 - current.top)
                            .toDouble();
                    _stamps[index] = current.copyWith(
                      width: nextWidth,
                      height: nextHeight,
                    );
                  }),
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(Icons.open_in_full, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignatureChoice {
  const _SignatureChoice(this.pngBytes, this.saveForReuse);

  final Uint8List pngBytes;
  final bool saveForReuse;
}

class _PlacedStamp {
  const _PlacedStamp({
    required this.pageNumber,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.pngBytes,
  });

  final int pageNumber;
  final double left;
  final double top;
  final double width;
  final double height;
  final Uint8List pngBytes;

  _PlacedStamp copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) => _PlacedStamp(
    pageNumber: pageNumber,
    left: left ?? this.left,
    top: top ?? this.top,
    width: width ?? this.width,
    height: height ?? this.height,
    pngBytes: pngBytes,
  );
}

class _DrawSignatureDialog extends StatefulWidget {
  const _DrawSignatureDialog();

  @override
  State<_DrawSignatureDialog> createState() => _DrawSignatureDialogState();
}

class _DrawSignatureDialogState extends State<_DrawSignatureDialog> {
  final List<List<Offset>> _strokes = [];

  Future<Uint8List?> _finish() async {
    if (_strokes.isEmpty) return null;
    const size = Size(1000, 320);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1000, 320));
    final paint = Paint()
      ..color = const Color(0xff183a72)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final points in _strokes) {
      if (points.length == 1) {
        canvas.drawCircle(points.single, 4.5, Paint()..color = paint.color);
      } else {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null || !mounted) return null;
    return data.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Draw your signature'),
    content: SizedBox(
      width: 520,
      child: AspectRatio(
        aspectRatio: 3.1,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            onPanStart: (details) => setState(() {
              _strokes.add([
                Offset(
                  details.localPosition.dx * 1000 / constraints.maxWidth,
                  details.localPosition.dy * 320 / constraints.maxHeight,
                ),
              ]);
            }),
            onPanUpdate: (details) => setState(() {
              _strokes.last.add(
                Offset(
                  details.localPosition.dx * 1000 / constraints.maxWidth,
                  details.localPosition.dy * 320 / constraints.maxHeight,
                ),
              );
            }),
            child: CustomPaint(
              painter: _SignaturePainter(_strokes),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => setState(_strokes.clear),
        child: const Text('Clear'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _strokes.isEmpty
            ? null
            : () async {
                final navigator = Navigator.of(context);
                final bytes = await _finish();
                if (mounted) navigator.pop(bytes);
              },
        child: const Text('Use signature'),
      ),
    ],
  );
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff183a72)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()
        ..moveTo(
          stroke.first.dx * size.width / 1000,
          stroke.first.dy * size.height / 320,
        );
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width / 1000, point.dy * size.height / 320);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes);
}
