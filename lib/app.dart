import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/di/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/local/app_preferences.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/viewer/pdf_viewer_screen.dart';
import 'services/platform/android_integration_service.dart';

class PdfToolkitApp extends ConsumerStatefulWidget {
  const PdfToolkitApp({super.key});

  @override
  ConsumerState<PdfToolkitApp> createState() => _PdfToolkitAppState();
}

class _PdfToolkitAppState extends ConsumerState<PdfToolkitApp> {
  bool? _onboardingComplete;
  StreamSubscription<AndroidPdfOpen>? _openPdfSubscription;
  final _pendingOpenPdfs = Queue<AndroidPdfOpen>();
  bool _pdfOpenScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadOnboarding();
    _startAndroidIntegration();
  }

  Future<void> _loadOnboarding() async {
    var complete = await OnboardingService.isComplete();
    if (!complete && _pendingOpenPdfs.isNotEmpty) {
      await OnboardingService.markComplete();
      complete = true;
    }
    if (!mounted) return;
    setState(() => _onboardingComplete = complete);
    if (complete) _openPendingPdfs();
  }

  Future<void> _startAndroidIntegration() async {
    final integration = ref.read(androidIntegrationServiceProvider);
    _openPdfSubscription = integration.openedPdfs.listen(
      _queuePdf,
      onError: (Object error, StackTrace stack) {
        debugPrint('Could not open PDF from Android.');
      },
    );
    try {
      final initialPdf = await integration.start();
      if (initialPdf != null) _queuePdf(initialPdf);
    } catch (_) {
      debugPrint('Could not read initial Android PDF.');
    }
  }

  void _queuePdf(AndroidPdfOpen pdf) {
    if (!mounted) return;
    _pendingOpenPdfs.add(pdf);
    if (_onboardingComplete == false) {
      if (_pendingOpenPdfs.length > 1) return;
      OnboardingService.markComplete().then((_) {
        if (!mounted) return;
        setState(() => _onboardingComplete = true);
        _openPendingPdfs();
      });
    } else if (_onboardingComplete == true) {
      _openPendingPdfs();
    }
  }

  void _openPendingPdfs() {
    if (_pendingOpenPdfs.isEmpty || _pdfOpenScheduled) return;
    _pdfOpenScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _pdfOpenScheduled = false;
      if (!mounted) return;
      final pdf = _pendingOpenPdfs.removeFirst();
      ref
          .read(appRouterProvider)
          .push(
            '/viewer',
            extra: PdfViewerArgs(
              filePath: pdf.path,
              readingPositionKey: pdf.readingPositionKey,
            ),
          );
      _openPendingPdfs();
    });
    binding.ensureVisualUpdate();
  }

  void _completeOnboarding() {
    setState(() => _onboardingComplete = true);
    _openPendingPdfs();
  }

  @override
  void dispose() {
    _openPdfSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(appPreferencesProvider);

    if (_onboardingComplete == null) {
      return MaterialApp(
        title: Env.appName,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (_onboardingComplete == false) {
      return MaterialApp(
        title: Env.appName,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: OnboardingScreen(onComplete: _completeOnboarding),
      );
    }

    final router = ref.watch(appRouterProvider);
    final themeMode = prefsAsync.maybeWhen(
      data: (prefs) => prefs.theme.themeMode,
      orElse: () => ThemeMode.system,
    );

    return MaterialApp.router(
      title: Env.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
