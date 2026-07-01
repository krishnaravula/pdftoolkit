import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'startup_error_app.dart';

Future<void> main() async {
  // Simple print that will show up in logcat even if diagnostics fail
  stdout.writeln('PdfToolkit: Starting main()');

  final result = await bootstrap();
  if (!result.isSuccess) {
    runApp(StartupErrorApp(error: result.error!));
    return;
  }
  runApp(const ProviderScope(child: PdfToolkitApp()));
}
