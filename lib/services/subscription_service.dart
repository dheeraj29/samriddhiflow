import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A skeletal service to manage user entitlements via RevenueCat in the future.
class SubscriptionService {
  /// Returns true if the user has the 'premium_ad_free' entitlement.
  /// Currently hardcoded to return true for local access during development.
  bool isAdFree() {
    // coverage:ignore-line
    return true;
  }

  /// Returns true if the user has the 'premium_cloud_sync' entitlement.
  /// Currently hardcoded to return true for local access during development.
  bool isCloudSyncEnabled() {
    return true;
  }

  /// Placeholder for triggering the RevenueCat purchase flow.
  Future<bool> purchasePackage(String packageId) async {
    // coverage:ignore-line
    // In future: purchases_flutter implementation here
    return true;
  }

  /// Placeholder for restoring purchases.
  Future<void> restorePurchases() async {
    // coverage:ignore-line
    // In future: Purchases.restorePurchases()
  }
}

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});
