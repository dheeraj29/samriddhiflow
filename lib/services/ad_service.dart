import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'subscription_service.dart';

/// A skeletal service to manage Google Mobile Ads in the future.
class AdService {
  /// Initialize the AdMob instance.
  Future<void> initialize() async {
    // coverage:ignore-line
    // In future: MobileAds.instance.initialize()
  }

  /// Returns a banner widget for display in the UI.
  /// If the user is ad-free, it returns a zero-height sized box.
  // coverage:ignore-start
  Widget showBanner(WidgetRef ref) {
    final subService = ref.read(subscriptionServiceProvider);
    if (subService.isAdFree()) {
      // coverage:ignore-end
      return const SizedBox.shrink();
    }

    // In future: AdBanner widget implementation here
    return Container(
      // coverage:ignore-line
      height: 60,
      width: double.infinity,
      color: Colors.grey.withAlpha(50), // coverage:ignore-line
      child: const Center(child: Text("Ad Placeholder")),
    );
  }
}

final adServiceProvider = Provider<AdService>((ref) {
  // coverage:ignore-line
  return AdService(); // coverage:ignore-line
});
