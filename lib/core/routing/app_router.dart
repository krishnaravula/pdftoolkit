import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/pdf_feature.dart';
import '../../features/compress/compress_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/image_to_pdf/image_to_pdf_screen.dart';
import '../../features/merge/merge_screen.dart';
import '../../features/page_editor/page_editor_screen.dart';
import '../../features/premium/premium_screen.dart';
import '../../features/recent_files/recent_files_screen.dart';
import '../../features/remove_password/remove_password_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/privacy/privacy_policy_screen.dart';
import '../../features/viewer/pdf_viewer_screen.dart';
import '../../features/split/split_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recent',
                builder: (context, state) => const RecentFilesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/merge',
        builder: (context, state) => const MergeScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/split',
        builder: (context, state) => const SplitScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/compress',
        builder: (context, state) => const CompressScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/image-to-pdf',
        builder: (context, state) => const ImageToPdfScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/remove-password',
        builder: (context, state) => const RemovePasswordScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/scan',
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/page-editor',
        builder: (context, state) => const PageEditorScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/premium',
        builder: (context, state) => const PremiumScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/viewer',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is PdfViewerArgs) {
            return PdfViewerScreen(
              filePath: extra.filePath,
              password: extra.password,
            );
          }
          final path = extra as String? ?? '';
          return PdfViewerScreen(filePath: path);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
    ],
  );
});

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adService = ref.watch(adServiceProvider);

    return Scaffold(
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<bool>(
              future: ref.read(adsEnabledProvider.future),
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return adService.buildBannerAd();
              },
            ),
            NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'Recent',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void navigateToFeature(BuildContext context, PdfFeatureType feature) {
  context.push('/${feature.routeName.replaceAll('_', '-')}');
}
