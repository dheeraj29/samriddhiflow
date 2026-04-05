import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:samriddhi_flow/screens/premium_promo_screen.dart';
import 'package:samriddhi_flow/services/subscription_service.dart';

class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  late MockSubscriptionService mockSubscriptionService;

  setUp(() {
    mockSubscriptionService = MockSubscriptionService();
    registerFallbackValue(SubscriptionTier.free);
  });

  Widget buildPromoScreen(SubscriptionTier tier) {
    when(() => mockSubscriptionService.getTier()).thenReturn(tier);
    when(() => mockSubscriptionService.purchasePackage(any()))
        .thenAnswer((_) async => true);

    return ProviderScope(
      overrides: [
        subscriptionServiceProvider.overrideWithValue(mockSubscriptionService),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PremiumPromoScreen(),
      ),
    );
  }

  group('PremiumPromoScreen Tiers', () {
    testWidgets('Free tier shows both Lite and Premium options',
        (tester) async {
      await tester.pumpWidget(buildPromoScreen(SubscriptionTier.free));
      await tester.pumpAndSettle();

      expect(find.text('GET LITE (AD-FREE)'), findsOneWidget);
      expect(find.text('GET PREMIUM (FULL ACCESS)'), findsOneWidget);
    });

    testWidgets('Lite tier shows only Upgrade to Premium', (tester) async {
      await tester.pumpWidget(buildPromoScreen(SubscriptionTier.lite));
      await tester.pumpAndSettle();

      expect(find.text('GET LITE (AD-FREE)'), findsNothing);
      expect(find.text('UPGRADE TO PREMIUM'), findsOneWidget);
    });

    testWidgets('Premium tier shows Already Premium message', (tester) async {
      await tester.pumpWidget(buildPromoScreen(SubscriptionTier.premium));
      await tester.pumpAndSettle();

      expect(find.text('You are a Premium User!'), findsOneWidget);
      expect(find.text('GET LITE (AD-FREE)'), findsNothing);
      expect(find.text('GET PREMIUM (FULL ACCESS)'), findsNothing);
      expect(find.text('UPGRADE TO PREMIUM'), findsNothing);
      expect(find.text('Close'),
          findsOneWidget); // Close text remains Close in arb
    });
  });
}
