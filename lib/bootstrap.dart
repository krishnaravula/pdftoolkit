import 'package:flutter/material.dart';

import 'core/diagnostics/startup_diagnostics.dart';
import 'data/local/file_storage_service.dart';

class BootstrapResult {
  const BootstrapResult.success() : error = null;
  const BootstrapResult.failure(this.error);

  final Object? error;

  bool get isSuccess => error == null;
}

Future<BootstrapResult> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupDiagnostics.installErrorHandlers();
  StartupDiagnostics.log('bootstrap start');

  try {
    final storage = FileStorageService();
    await storage.cleanupStaleTempFiles();
    StartupDiagnostics.log('temp cleanup complete');

    // Skip redundant monetization init here to avoid potential disposal races.
    // Initialization will happen lazily via ProviderScope in PdfToolkitApp.

    StartupDiagnostics.log('bootstrap complete');
    return const BootstrapResult.success();
  } catch (e, st) {
    StartupDiagnostics.log('bootstrap failed', detail: e, stack: st);
    return BootstrapResult.failure(e);
  }
}
