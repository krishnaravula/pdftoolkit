import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_widgets.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../domain/entities/pdf_job.dart';
import '../../services/pdf/pdf_job_runner.dart';
import '../../services/storage/file_save_service.dart';
import 'save_result_screen.dart';

class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}

mixin PdfJobMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _jobRunning = false;

  bool get isJobRunning => _jobRunning;

  Future<void> runPdfJob({
    required PdfFeatureType feature,
    required Future<dynamic> Function(PdfProgressReporter reporter) task,
    required String suggestedName,
    VoidCallback? onDone,
  }) async {
    if (_jobRunning) return;

    setState(() => _jobRunning = true);
    final notifier = ref.read(pdfJobNotifierProvider.notifier);

    try {
      final result = await notifier.execute((reporter) async {
        final output = await task(reporter);
        if (output is String) {
          reporter.complete(output);
        }
        return output;
      });

      if (!mounted || result == null) return;

      if (result is List<PendingSaveFile>) {
        showSaveResult(
          context,
          feature: feature,
          files: result,
          onDone: onDone,
        );
      } else if (result is String) {
        showSingleSaveResult(
          context,
          feature: feature,
          tempPath: result,
          suggestedName: suggestedName,
          onDone: onDone,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFriendlyError(e))));
    } finally {
      if (mounted) {
        setState(() => _jobRunning = false);
        ref.read(pdfJobNotifierProvider.notifier).reset();
      }
    }
  }

  void cancelJob() {
    ref.read(pdfJobNotifierProvider.notifier).cancel();
  }

  Future<List<String>> pickPdfFiles({bool allowMultiple = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: allowMultiple,
    );
    if (result == null) return [];
    return result.paths.whereType<String>().toList();
  }

  Future<List<String>> pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return [];
    return result.paths.whereType<String>().toList();
  }

  Widget buildJobStatus(PdfJobProgress progress) {
    if (progress.status == PdfJobStatus.idle) {
      return const SizedBox.shrink();
    }

    if (progress.status == PdfJobStatus.running) {
      return JobProgressView(
        progress: progress.fraction,
        message: progress.message,
        onCancel: cancelJob,
      );
    }

    if (progress.status == PdfJobStatus.failure) {
      return Text(
        userFriendlyError(progress.error ?? 'Something went wrong'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    if (progress.status == PdfJobStatus.cancelled) {
      return Text(
        userFriendlyError('Operation cancelled'),
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      );
    }

    return const SizedBox.shrink();
  }
}

Future<String?> promptPassword(BuildContext context) async {
  var password = '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Enter PDF password'),
      content: TextField(
        onChanged: (value) => password = value,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, password),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}
