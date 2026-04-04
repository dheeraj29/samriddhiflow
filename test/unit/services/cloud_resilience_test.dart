import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/cloud_storage_interface.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/core/cloud_config.dart';
import 'package:samriddhi_flow/services/subscription_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockCloudStorage extends Mock implements CloudStorageInterface {}

class MockStorageService extends Mock implements StorageService {}

class MockTaxConfig extends Mock implements TaxConfigService {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

void main() {
  group('AuthService Resilience', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      authService = AuthService(mockAuth);

      when(() => mockAuth.currentUser).thenReturn(mockUser);
    });

    test('reloadUser handles "auth/network-request-failed" (Web prefix)',
        () async {
      when(() => mockUser.reload()).thenThrow(FirebaseAuthException(
          code: 'auth/network-request-failed', message: 'Offline'));

      // Pass null for Ref - AuthService handles this safely.
      await authService.reloadUser(null);

      verify(() => mockUser.reload()).called(1);
    });
  });

  group('CloudSyncService Resilience', () {
    late MockCloudStorage mockCloud;
    late MockStorageService mockStorage;
    late MockTaxConfig mockTax;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockSubscriptionService mockSubscription;
    late CloudSyncService syncService;

    setUp(() {
      mockCloud = MockCloudStorage();
      mockStorage = MockStorageService();
      mockTax = MockTaxConfig();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockSubscription = MockSubscriptionService();
      syncService = CloudSyncService(
          mockCloud, mockStorage, mockTax, mockSubscription,
          firebaseAuth: mockAuth);

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('test-uid');

      when(() => mockStorage.getAllSettings()).thenReturn({});
      when(() => mockStorage.getAllAccounts()).thenReturn([]);
      when(() => mockStorage.getAllTransactions()).thenReturn([]);
      when(() => mockStorage.getAllLoans()).thenReturn([]);
      when(() => mockStorage.getAllRecurring()).thenReturn([]);
      when(() => mockStorage.getAllCategories()).thenReturn([]);
      when(() => mockStorage.getProfiles()).thenReturn([]);
      when(() => mockStorage.getInsurancePolicies()).thenReturn([]);
      when(() => mockTax.getAllRules()).thenReturn({});
      when(() => mockStorage.getAllTaxYearData()).thenReturn([]);
      when(() => mockStorage.getLendingRecords()).thenReturn([]);
      when(() => mockStorage.getAllInvestments()).thenReturn([]);
      when(() => mockUser.getIdToken(any()))
          .thenAnswer((_) async => 'token123');
      when(() => mockCloud.getActiveSessionId(any()))
          .thenAnswer((_) async => 'session123');
      when(() => mockStorage.getSessionId()).thenReturn('session123');
      when(() => mockStorage.getCloudDatabaseRegion())
          .thenReturn(CloudDatabaseRegion.india);
      when(() => mockSubscription.isCloudSyncEnabled()).thenReturn(true);
    });

    test('syncToCloud handles "firestore/unavailable" (Prefix check)',
        () async {
      when(() => mockCloud.syncData(any(), any())).thenThrow(FirebaseException(
          plugin: 'firestore', code: 'firestore/unavailable'));

      expect(
        () => syncService.syncToCloud(),
        throwsA(predicate((e) =>
            e.toString().contains('Cloud Sync temporarily unavailable'))),
      );
    });

    test('restoreFromCloud handles "storage/unauthenticated" (Prefix check)',
        () async {
      when(() => mockCloud.fetchData(any())).thenThrow(FirebaseException(
          plugin: 'storage', code: 'storage/unauthenticated'));

      expect(
        () => syncService.restoreFromCloud(),
        throwsA(
            predicate((e) => e.toString().contains('Cloud Restore failed'))),
      );
    });
  });
}
