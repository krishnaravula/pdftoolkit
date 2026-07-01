import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/app_config.dart';
import 'ad_service.dart';

class AdMobAdService implements AdService {
  BannerAd? _bannerAd;
  BannerAd? _loadingBanner;
  InterstitialAd? _interstitialAd;
  DateTime? _lastInterstitial;

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  @override
  Widget buildBannerAd() {
    if (!Platform.isAndroid) return const SizedBox.shrink();

    final ad = _bannerAd ?? _loadingBanner ?? _createBanner();

    return SizedBox(height: 50, child: AdWidget(ad: ad));
  }

  BannerAd _createBanner() {
    _loadingBanner = BannerAd(
      adUnitId: AppConfig.testBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerAd = ad as BannerAd;
          _loadingBanner = null;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _loadingBanner = null;
        },
      ),
    )..load();
    return _loadingBanner!;
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AppConfig.testInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  @override
  Future<void> showInterstitial() async {
    final last = _lastInterstitial;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 3)) {
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );

    await ad.show();
    _lastInterstitial = DateTime.now();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
  }
}
