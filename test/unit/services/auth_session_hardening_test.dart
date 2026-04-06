import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/cloud_storage_interface.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/core/cloud_config.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/subscription_service.dart';

import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class MockStorageService extends Mock implements StorageService {}

class MockUser extends Mock implements User {}

class MockCloudStorage extends Mock implements CloudStorageInterface {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

class ProfileFake extends Fake implements Profile {}

class CategoryFake extends Fake implements Category {}

class AccountFake extends Fake implements Account {}

class TransactionFake extends Fake implements Transaction {}

class LoanFake extends Fake implements Loan {}

class RecurringTransactionFake extends Fake implements RecurringTransaction {}

void main() {
  setUpAll(() {
    registerFallbackValue(ProfileFake());
    registerFallbackValue(CategoryFake());
    registerFallbackValue(AccountFake());
    registerFallbackValue(TransactionFake());
    registerFallbackValue(LoanFake());
    registerFallbackValue(RecurringTransactionFake());
  });

  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockCloudStorage mockCloudStorage;
  late MockStorageService mockStorage;
  late MockTaxConfigService mockTaxConfig;
  late MockSubscriptionService mockSubscription;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockCloudStorage = MockCloudStorage();
    mockStorage = MockStorageService();
    mockTaxConfig = MockTaxConfigService();
    mockSubscription = MockSubscriptionService();

    when(() => mockUser.uid).thenReturn('test-uid');
    when(() => mockUser.getIdToken(true)).thenAnswer((_) async => 'fake-token');
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockCloudStorage.fetchData('test-uid'))
        .thenAnswer((_) async => {});
    when(() => mockStorage.getAuthFlag()).thenReturn(true);
    when(() => mockStorage.getAllTaxYearData()).thenReturn([]);
    when(() => mockStorage.clearAllData()).thenAnswer((_) async {});
    // Stub the restore helpers
    when(() => mockStorage.getProfiles()).thenReturn([]);
    when(() => mockStorage.saveProfile(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveSettings(any())).thenAnswer((_) async {});
    when(() => mockStorage.setSessionId(any())).thenAnswer((_) async {});
    when(() => mockStorage.setAuthFlag(any())).thenAnswer((_) async {});
    when(() => mockStorage.setLastLogin(any())).thenAnswer((_) async {});
    when(() => mockStorage.setCloudDatabaseRegion(any()))
        .thenAnswer((_) async {});
    when(() => mockStorage.setActiveProfileId(any())).thenAnswer((_) async {});
    when(() => mockStorage.getCloudDatabaseRegion())
        .thenReturn(CloudDatabaseRegion.india);
    when(() => mockStorage.getActiveProfileId()).thenReturn('default');
    when(() => mockSubscription.isCloudSyncEnabled()).thenReturn(true);
    when(() => mockSubscription.getTier()).thenReturn(SubscriptionTier.premium);
    when(() => mockSubscription.getExpiryDate()).thenReturn(null);
  });

  group('Session Hardening Logic', () {
    test('CloudSyncService verifies session ID and token freshness', () async {
      when(() => mockCloudStorage.getActiveSessionId('test-uid'))
          .thenAnswer((_) async => 'correct-uuid');
      when(() => mockStorage.getSessionId()).thenReturn('correct-uuid');
      when(() => mockCloudStorage.setActiveSessionId(any(), any()))
          .thenAnswer((_) async {});

      final cloudSync = CloudSyncService(
        mockCloudStorage,
        mockStorage,
        mockTaxConfig,
        mockSubscription,
        firebaseAuth: mockAuth,
      );

      // Attempt restoration
      await cloudSync.restoreFromCloud();

      // _syncSessionBeforeRestore skips (localId exists) →
      // 1. _verifySession (verification)
      // 2. updateActiveSessionId (post-restore claim)
      verify(() => mockUser.getIdToken(true)).called(2);
      verify(() => mockCloudStorage.getActiveSessionId('test-uid')).called(1);
    });

    test('CloudSyncService proactively syncs sessionId on new devices',
        () async {
      String? currentCloudId = 'cloud-uuid';
      String? currentLocalId; // Starts as null

      when(() => mockCloudStorage.getActiveSessionId('test-uid'))
          .thenAnswer((_) async => currentCloudId);
      when(() => mockStorage.getSessionId()).thenAnswer((_) => currentLocalId);

      // Capture the new session ID being set locally
      when(() => mockStorage.setSessionId(any())).thenAnswer((inv) async {
        currentLocalId = inv.positionalArguments[0] as String;
      });

      // Capture the new session ID being set in cloud
      when(() => mockCloudStorage.setActiveSessionId(any(), any()))
          .thenAnswer((inv) async {
        currentCloudId = inv.positionalArguments[1] as String;
      });

      final cloudSync = CloudSyncService(
        mockCloudStorage,
        mockStorage,
        mockTaxConfig,
        mockSubscription,
        firebaseAuth: mockAuth,
      );

      await cloudSync.restoreFromCloud();

      // 1. _syncSessionBeforeRestore (proactive claim)
      // 2. _verifySession (verification)
      // 3. updateActiveSessionId (post-restore claim)
      verify(() => mockUser.getIdToken(true)).called(3);
      verify(() => mockCloudStorage.getActiveSessionId('test-uid')).called(1);
    });
  });
}
