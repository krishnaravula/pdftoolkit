import 'package:shared_preferences/shared_preferences.dart';

/// Compile-time and runtime feature flags for monetization.
class AppConfig {
  AppConfig._();

  static const enableAds = bool.fromEnvironment(
    'ENABLE_ADS',
    defaultValue: false,
  );
  static const enableBilling = bool.fromEnvironment(
    'ENABLE_BILLING',
    defaultValue: false,
  );

  static const _adsOverrideKey = 'debug_enable_ads';
  static const _billingOverrideKey = 'debug_enable_billing';

  static Future<bool> adsEnabled() async {
    if (!enableAds) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adsOverrideKey) ?? true;
  }

  static Future<bool> billingEnabled() async {
    if (!enableBilling) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_billingOverrideKey) ?? true;
  }

  static Future<void> setAdsOverride(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adsOverrideKey, value);
  }

  static Future<void> setBillingOverride(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_billingOverrideKey, value);
  }

  static const removeAdsProductId = 'remove_ads';
  static const premiumSubscriptionId = 'premium_monthly';

  static const testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
}
