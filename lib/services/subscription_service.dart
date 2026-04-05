import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SubscriptionTier { free, lite, premium }

/// A skeletal service to manage user entitlements via RevenueCat in the future.
class SubscriptionService {
  /// Toggle this to test different tiers during development.
  final SubscriptionTier currentTier = SubscriptionTier.premium;

  /// Returns true if the user has at least the 'lite' (ad-free) status.
  bool isAdFree() {
    return currentTier == SubscriptionTier.lite ||
        currentTier == SubscriptionTier.premium;
  }

  /// Returns true if the user has the 'premium' (cloud sync) status.
  bool isCloudSyncEnabled() {
    return currentTier == SubscriptionTier.premium;
  }

  /// Returns the current active tier.
  SubscriptionTier getTier() => currentTier;

  /// Returns the expiry date for the subscription.
  /// For development/dummy mode, returns null (Never).
  DateTime? getExpiryDate() {
    return null;
  }

  /// Placeholder for triggering the RevenueCat purchase flow.
  Future<bool> purchasePackage(String packageId) async {
    // In future: purchases_flutter implementation here
    return true;
  }

  /// Placeholder for restoring purchases.
  Future<void> restorePurchases() async {
    // In future: Purchases.restorePurchases()
  }
}

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});
