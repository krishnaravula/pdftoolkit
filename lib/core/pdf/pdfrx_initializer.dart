import 'package:pdfrx/pdfrx.dart';

import '../diagnostics/startup_diagnostics.dart';

/// Lazy, single-flight PDFium initialization — deferred from app launch.
class PdfrxInitializer {
  PdfrxInitializer._();

  static Future<void>? _initFuture;

  static Future<void> ensureInitialized() {
    return _initFuture ??= _initialize();
  }

  static Future<void> _initialize() async {
    StartupDiagnostics.log('pdfrxFlutterInitialize start');
    try {
      await pdfrxFlutterInitialize();
      StartupDiagnostics.log('pdfrxFlutterInitialize complete');
    } catch (e, st) {
      StartupDiagnostics.log(
        'pdfrxFlutterInitialize failed',
        detail: e,
        stack: st,
      );
      _initFuture = null;
      rethrow;
    }
  }
}
