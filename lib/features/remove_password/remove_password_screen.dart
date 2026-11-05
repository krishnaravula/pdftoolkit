import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as p;

import '../../core/di/providers.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_widgets.dart';

import '../../domain/entities/pdf_feature.dart';

import '../../domain/entities/pdf_job.dart';

import '../shared/feature_scaffold.dart';

class RemovePasswordScreen extends ConsumerStatefulWidget {
  const RemovePasswordScreen({super.key});

  @override
  ConsumerState<RemovePasswordScreen> createState() =>
      _RemovePasswordScreenState();
}

class _RemovePasswordScreenState extends ConsumerState<RemovePasswordScreen>
    with PdfJobMixin {
  String? _inputPath;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(pdfJobNotifierProvider);

    final isRunning = progress.status == PdfJobStatus.running || isJobRunning;

    return FeatureScaffold(
      title: PdfFeatureType.removePassword.label,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            const Text(
              'Removes PDF password protection when you provide the correct document password.',
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: isRunning
                  ? null
                  : () async {
                      final paths = await pickPdfFiles();

                      if (paths.isNotEmpty) {
                        setState(() => _inputPath = paths.first);
                      }
                    },

              icon: const Icon(Icons.folder_open),

              label: Text(
                _inputPath == null
                    ? 'Select protected PDF'
                    : p.basename(_inputPath!),
              ),
            ),
            if (_inputPath != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'This PDF requires a password to unlock.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            const Spacer(),

            buildJobStatus(progress),

            const SizedBox(height: 12),

            AppPrimaryButton(
              label: 'Remove password',

              isLoading: isRunning,

              onPressed: _inputPath == null || isRunning ? null : _unlock,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    final password = await promptPassword(context);

    if (password == null || password.isEmpty) return;

    await runPdfJob(
      feature: PdfFeatureType.removePassword,

      suggestedName: 'unlocked.pdf',

      task: (reporter) async {
        try {
          return await ref
              .read(pdfProcessingServiceProvider)
              .removePassword(
                inputPath: _inputPath!,

                password: password,

                suggestedName: 'unlocked.pdf',
                cancellationToken: reporter.cancellationToken,
              );
        } on InvalidPasswordException {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Incorrect password')));
          }
          return null;
        }
      },
    );
  }
}
