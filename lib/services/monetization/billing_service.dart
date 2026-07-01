abstract class BillingService {
  Future<void> initialize();
  Stream<bool> get premiumStream;
  bool get isPremium;
  Future<void> purchaseRemoveAds();
  Future<void> restorePurchases();
  void dispose();
}

class NoOpBillingService implements BillingService {
  @override
  Future<void> initialize() async {}

  @override
  Stream<bool> get premiumStream => Stream.value(true);

  @override
  bool get isPremium => true;

  @override
  Future<void> purchaseRemoveAds() async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  void dispose() {}
}
