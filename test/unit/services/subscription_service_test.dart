import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/services/ad_service.dart';
import 'package:samriddhi_flow/services/subscription_service.dart';

class FreeSubscriptionService extends SubscriptionService {
  @override
  bool isAdFree() => false;

  @override
  bool isCloudSyncEnabled() => false;

  @override
  SubscriptionTier getTier() => SubscriptionTier.free;
}

void main() {
  group('SubscriptionService', () {
    test('defaults to premium tier with ad-free cloud sync enabled', () {
      final service = SubscriptionService();

      expect(service.getTier(), SubscriptionTier.premium);
      expect(service.isAdFree(), isTrue);
      expect(service.isCloudSyncEnabled(), isTrue);
      expect(service.getExpiryDate(), isNull);
    });

    test('placeholder purchase and restore methods complete successfully',
        () async {
      final service = SubscriptionService();

      expect(await service.purchasePackage('premium_monthly'), isTrue);
      await service.restorePurchases();
    });
  });

  group('AdService', () {
    testWidgets('showBanner returns placeholder banner for free tier',
        (tester) async {
      final adService = AdService();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          subscriptionServiceProvider
              .overrideWithValue(FreeSubscriptionService()),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) => Scaffold(
              body: adService.showBanner(ref),
            ),
          ),
        ),
      ));

      expect(find.text('Ad Placeholder'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('showBanner hides banner for ad-free tier', (tester) async {
      final adService = AdService();

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) => Scaffold(
              body: adService.showBanner(ref),
            ),
          ),
        ),
      ));

      expect(find.text('Ad Placeholder'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
