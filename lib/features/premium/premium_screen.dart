import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/di/providers.dart';
import '../../core/widgets/app_widgets.dart';

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Remove ads')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Support ${Env.appName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const _BenefitRow(
              icon: Icons.block,
              text: 'No banner or interstitial ads',
            ),
            const _BenefitRow(
              icon: Icons.offline_bolt,
              text: 'All PDF tools remain fully offline',
            ),
            const _BenefitRow(
              icon: Icons.favorite_outline,
              text: 'Helps support ongoing development',
            ),
            const Spacer(),
            AppPrimaryButton(
              label: billing.isPremium ? 'Ad-free active' : 'Remove ads',
              onPressed: billing.isPremium ? null : billing.purchaseRemoveAds,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: billing.restorePurchases,
              child: const Text('Restore purchases'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
