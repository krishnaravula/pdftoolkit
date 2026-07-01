import 'package:flutter/widgets.dart';

abstract class AdService {
  Future<void> initialize();
  Widget buildBannerAd();
  Future<void> showInterstitial();
  void dispose();
}

class NoOpAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  Widget buildBannerAd() => const SizedBox.shrink();

  @override
  Future<void> showInterstitial() async {}

  @override
  void dispose() {}
}
