import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class AndroidPdfOpen {
  const AndroidPdfOpen(this.path, {this.readingPositionKey});

  final String path;
  final String? readingPositionKey;
}

/// Bridges Android PDF intents and system settings into Flutter.
class AndroidIntegrationService {
  AndroidIntegrationService({bool? isAndroid})
    : _isAndroid = isAndroid ?? Platform.isAndroid;

  static const MethodChannel _channel = MethodChannel('pdf_toolkit/android');
  final bool _isAndroid;

  final _openedPdfController = StreamController<AndroidPdfOpen>.broadcast();
  bool _started = false;

  Stream<AndroidPdfOpen> get openedPdfs => _openedPdfController.stream;

  Future<AndroidPdfOpen?> start() async {
    if (!_isAndroid || _started) return null;
    _started = true;
    _channel.setMethodCallHandler(_handleNativeCall);
    return _readPdf(await _channel.invokeMethod<Object>('consumeInitialPdf'));
  }

  Future<void> openDefaultPdfSettings() async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('openDefaultPdfSettings');
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'openPdf') {
      final pdf = _readPdf(call.arguments);
      if (pdf != null) _openedPdfController.add(pdf);
    }
    if (call.method == 'openPdfError') {
      _openedPdfController.addError(
        PlatformException(
          code: 'open_pdf_failed',
          message: call.arguments?.toString() ?? 'Unable to open PDF.',
        ),
      );
    }
  }

  AndroidPdfOpen? _readPdf(Object? message) {
    if (message is String && message.isNotEmpty) return AndroidPdfOpen(message);
    if (message is! Map<Object?, Object?>) return null;
    final path = message['path'];
    final key = message['readingPositionKey'];
    if (path is! String || path.isEmpty) return null;
    return AndroidPdfOpen(path, readingPositionKey: key is String ? key : null);
  }

  void dispose() {
    if (_started) _channel.setMethodCallHandler(null);
    _openedPdfController.close();
  }
}
