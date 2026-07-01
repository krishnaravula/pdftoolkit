import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/config/app_config.dart';
import 'billing_service.dart';

class PlayBillingService implements BillingService {
  PlayBillingService()
    : _premiumController = StreamController<bool>.broadcast();

  final StreamController<bool> _premiumController;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isPremium = false;

  static const _productIds = {AppConfig.removeAdsProductId};

  @override
  Stream<bool> get premiumStream => _premiumController.stream;

  @override
  bool get isPremium => _isPremium;

  @override
  Future<void> initialize() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      _setPremium(false);
      return;
    }

    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (_) => _setPremium(false),
    );

    await restorePurchases();
  }

  @override
  Future<void> purchaseRemoveAds() async {
    final response = await InAppPurchase.instance.queryProductDetails(
      _productIds,
    );
    if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
      return;
    }

    final product = response.productDetails.first;
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  @override
  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID == AppConfig.removeAdsProductId &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        _setPremium(true);
      }

      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  void _setPremium(bool value) {
    _isPremium = value;
    _premiumController.add(value);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _premiumController.close();
  }
}
