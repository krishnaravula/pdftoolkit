import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/config/env.dart';
import '../../core/di/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingEnabled = ref.watch(billingEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Offline processing'),
            subtitle: Text('All PDF operations run locally on your device.'),
          ),
          const ListTile(
            title: Text('Minimum Android version'),
            subtitle: Text('Android 10 (API 29) or newer'),
          ),
          if (AppConfig.enableBilling)
            billingEnabled.when(
              data: (_) => ListTile(
                title: const Text('Remove ads'),
                subtitle: Text(
                  'Support development and use ${Env.appName} ad-free',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/premium'),
              ),
              loading: () => const ListTile(
                title: Text('Remove ads'),
                subtitle: Text('Loading…'),
                trailing: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => const ListTile(
                title: Text('Remove ads'),
                subtitle: Text('Billing unavailable on this device'),
                enabled: false,
              ),
            ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            onTap: () => _openUrl(context, Env.privacyPolicyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Support'),
            subtitle: Text(Env.supportEmail),
            onTap: () => _openUrl(context, 'mailto:${Env.supportEmail}'),
          ),
          if (kDebugMode) ...[
            const Divider(),
            const ListTile(title: Text('Developer toggles')),
            SwitchListTile(
              title: const Text('Enable ads (runtime)'),
              value: AppConfig.enableAds,
              onChanged: AppConfig.enableAds
                  ? (value) async {
                      await AppConfig.setAdsOverride(value);
                      ref.invalidate(adsEnabledProvider);
                    }
                  : null,
            ),
            SwitchListTile(
              title: const Text('Enable billing (runtime)'),
              value: AppConfig.enableBilling,
              onChanged: AppConfig.enableBilling
                  ? (value) async {
                      await AppConfig.setBillingOverride(value);
                      ref.invalidate(billingEnabledProvider);
                    }
                  : null,
            ),
          ],
          const Divider(),
          const ListTile(title: Text('Version'), subtitle: Text('1.0.0')),
        ],
      ),
    );
  }
}
