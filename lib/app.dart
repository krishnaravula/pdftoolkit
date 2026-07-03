import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/local/app_preferences.dart';
import 'features/onboarding/onboarding_screen.dart';

class PdfToolkitApp extends ConsumerStatefulWidget {
  const PdfToolkitApp({super.key});

  @override
  ConsumerState<PdfToolkitApp> createState() => _PdfToolkitAppState();
}

class _PdfToolkitAppState extends ConsumerState<PdfToolkitApp> {
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _loadOnboarding();
  }

  Future<void> _loadOnboarding() async {
    final complete = await OnboardingService.isComplete();
    if (mounted) setState(() => _onboardingComplete = complete);
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
        home: OnboardingScreen(
          onComplete: () => setState(() => _onboardingComplete = true),
        ),
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
