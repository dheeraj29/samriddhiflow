import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/settings_screen.dart';
import 'package:samriddhi_flow/services/subscription_service.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';

class MockSubscriptionService extends Mock implements SubscriptionService {}

class MockStorageService extends Mock implements StorageService {}

class MockAuthService extends Mock implements AuthService {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class FakeIsOfflineNotifier extends IsOfflineNotifier {
  @override
  bool build() => false;
  @override
  void setOffline(bool isOffline) {}
}

void main() {
  late MockSubscriptionService mockSubscriptionService;
  late MockStorageService mockStorageService;
  late MockAuthService mockAuthService;
  late MockCloudSyncService mockCloudSyncService;

  setUp(() {
    mockSubscriptionService = MockSubscriptionService();
    mockStorageService = MockStorageService();
    mockAuthService = MockAuthService();
    mockCloudSyncService = MockCloudSyncService();

    when(() => mockStorageService.getLocale()).thenReturn(null);
    when(() => mockStorageService.getThemeMode()).thenReturn('system');
    when(() => mockStorageService.getCurrencyLocale()).thenReturn('en_IN');
    when(() => mockStorageService.getActiveProfileId()).thenReturn('default');
    when(() => mockStorageService.getCloudDatabaseRegion()).thenReturn('India');
    when(() => mockStorageService.getAuthFlag()).thenReturn(false);
    when(() => mockStorageService.isAppLockEnabled()).thenReturn(false);
    when(() => mockStorageService.getAppPin()).thenReturn(null);
    when(() => mockStorageService.getDashboardConfig())
        .thenReturn(const DashboardVisibilityConfig());
    when(() => mockStorageService.getCategories()).thenReturn([]);
    when(() => mockStorageService.getProfiles()).thenReturn([]);
    when(() => mockStorageService.getHolidays()).thenReturn([]);
    when(() => mockStorageService.getMonthlyBudget()).thenReturn(0.0);
    when(() => mockStorageService.getBackupThreshold()).thenReturn(5);
    when(() => mockStorageService.getTxnsSinceBackup()).thenReturn(0);
    when(() => mockStorageService.isSmartCalculatorEnabled()).thenReturn(true);

    when(() => mockAuthService.isSignOutInProgress).thenReturn(false);
  });

  Widget wrap(Widget child, SubscriptionTier tier) {
    when(() => mockSubscriptionService.getTier()).thenReturn(tier);
    when(() => mockSubscriptionService.isAdFree())
        .thenReturn(tier != SubscriptionTier.free);
    when(() => mockSubscriptionService.isCloudSyncEnabled())
        .thenReturn(tier == SubscriptionTier.premium);
    when(() => mockSubscriptionService.getExpiryDate()).thenReturn(null);

    return ProviderScope(
      overrides: [
        subscriptionServiceProvider.overrideWithValue(mockSubscriptionService),
        storageServiceProvider.overrideWithValue(mockStorageService),
        authServiceProvider.overrideWithValue(mockAuthService),
        cloudSyncServiceProvider.overrideWithValue(mockCloudSyncService),
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        firebaseInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        authStreamProvider.overrideWith((ref) => Stream.value(null)),
        // Correct override for NotifierProvider
        isOfflineProvider.overrideWith(() => FakeIsOfflineNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('SettingsScreen Subscription Tiers', () {
    testWidgets('Free tier shows status and Upgrade button', (tester) async {
      await tester
          .pumpWidget(wrap(const SettingsScreen(), SubscriptionTier.free));
      await tester.pumpAndSettle();
      
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text('Global Settings'));
      await tester.pumpAndSettle();

      expect(
          find.textContaining(l10n.freeTierActive, findRichText: true), findsOneWidget);
      expect(
          find.widgetWithText(TextButton, l10n.upgradeButtonLabel), findsOneWidget);

      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
    });

    testWidgets('Lite tier shows Lite status and Upgrade to Premium',
        (tester) async {
      await tester
          .pumpWidget(wrap(const SettingsScreen(), SubscriptionTier.lite));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text('Global Settings'));
      await tester.pumpAndSettle();

      expect(find.textContaining(l10n.liteActive, findRichText: true),
          findsOneWidget);
      expect(find.widgetWithText(TextButton, l10n.upgradeToPremiumLabel),
          findsOneWidget);

      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
    });

    testWidgets('Premium tier shows Premium Active and hides Upgrade button',
        (tester) async {
      await tester
          .pumpWidget(wrap(const SettingsScreen(), SubscriptionTier.premium));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text('Global Settings'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.premiumActive), findsOneWidget);
      expect(find.text(l10n.expiresOnLabel(l10n.expiresNever)), findsOneWidget);
      expect(find.widgetWithText(TextButton, l10n.upgradeButtonLabel), findsNothing);
      expect(
          find.widgetWithText(TextButton, l10n.upgradeToPremiumLabel), findsNothing);

      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();
    });
  });
}

