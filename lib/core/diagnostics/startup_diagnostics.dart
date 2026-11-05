import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Structured startup logging to correlate with `adb logcat` on Android 16 crashes.
class StartupDiagnostics {
  StartupDiagnostics._();

  static const _tag = 'PdfToolkitStartup';

  static void log(String phase, {Object? detail, StackTrace? stack}) {
    final safeDetail = detail == null ? null : detail.runtimeType;
    final message = safeDetail == null ? phase : '$phase (${safeDetail})';
    developer.log(message, name: _tag);
    if (kDebugMode) {
      debugPrint('[$_tag] $message');
    }
  }

  static void installErrorHandlers() {
    FlutterError.onError = (details) {
      log(
        'FlutterError',
        detail: details.exceptionAsString(),
        stack: details.stack,
      );
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      log('Uncaught async error', detail: error, stack: stack);
      return false;
    };
  }
}
