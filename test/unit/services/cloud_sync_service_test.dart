import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/services/cloud_storage_interface.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class MockCloudStorage extends Mock implements CloudStorageInterface {}

class MockStorageService extends Mock implements StorageService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late CloudSyncService cloudSyncService;
  late MockCloudStorage mockCloudStorage;
  late MockStorageService mockStorageService;
  late MockTaxConfigService mockTaxConfigService;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockCloudStorage = MockCloudStorage();
    mockStorageService = MockStorageService();
    mockTaxConfigService = MockTaxConfigService();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    registerFallbackValue(Profile(id: 'f', name: 'f'));
    registerFallbackValue(
        Category(id: 'f', name: 'f', usage: CategoryUsage.expense));
    registerFallbackValue(Account(
      id: 'f',
      name: 'f',
      type: AccountType.savings,
      balance: 0,
    ));
    registerFallbackValue(Transaction(
      id: 'f',
      title: 'f',
      amount: 0,
      date: DateTime.now(),
      type: TransactionType.expense,
      category: 'c',
    ));

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('user123');

    cloudSyncService = CloudSyncService(
      mockCloudStorage,
      mockStorageService,
      mockTaxConfigService,
      firebaseAuth: mockAuth,
    );
  });

  group('CloudSyncService - syncToCloud', () {
    test('serializes and uploads all data', () async {
      when(() => mockStorageService.getAllAccounts()).thenReturn([]);
      when(() => mockStorageService.getAllTransactions()).thenReturn([]);
      when(() => mockStorageService.getAllLoans()).thenReturn([]);
      when(() => mockStorageService.getAllRecurring()).thenReturn([]);
      when(() => mockStorageService.getAllCategories()).thenReturn([]);
      when(() => mockStorageService.getProfiles()).thenReturn([]);
      when(() => mockStorageService.getAllSettings()).thenReturn({});
      when(() => mockStorageService.getInsurancePolicies()).thenReturn([]);
      when(() => mockStorageService.getAllTaxYearData()).thenReturn([]);
      when(() => mockStorageService.getLendingRecords()).thenReturn([]);
      when(() => mockTaxConfigService.getAllRules()).thenReturn({});

      when(() => mockCloudStorage.syncData(any(), any()))
          .thenAnswer((_) async {});

      await cloudSyncService.syncToCloud();

      verify(() => mockCloudStorage.syncData('user123', any())).called(1);
    });

    test('throws error if not logged in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(() => cloudSyncService.syncToCloud(), throwsException);
    });
  });

  group('CloudSyncService - restoreFromCloud', () {
    test('clears local data and restores from cloud map', () async {
      final cloudData = {
        'profiles': [Profile(id: 'p1', name: 'P1').toMap()],
        'accounts': [
          Account(id: 'a1', name: 'A1', type: AccountType.savings, balance: 100)
              .toMap()
        ],
      };

      when(() => mockCloudStorage.fetchData('user123'))
          .thenAnswer((_) async => cloudData);
      when(() => mockStorageService.clearAllData()).thenAnswer((_) async {});
      when(() => mockStorageService.saveProfile(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.addCategory(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.saveAccount(any()))
          .thenAnswer((_) async {});

      await cloudSyncService.restoreFromCloud();

      verify(() => mockStorageService.clearAllData()).called(1);
      verify(() => mockStorageService.saveAccount(any())).called(1);
    });

    test('sanitizes Firestore timestamps recursively', () async {
      final now = DateTime.now();
      final cloudDataWithTimestamp = {
        'transactions': [
          {
            'id': 't1',
            'title': 'Test',
            'amount': 50.0,
            'date': firestore.Timestamp.fromDate(now),
            'type': 1, // expense
            'category': 'Food',
          }
        ]
      };

      when(() => mockCloudStorage.fetchData('user123'))
          .thenAnswer((_) async => cloudDataWithTimestamp);
      when(() => mockStorageService.clearAllData()).thenAnswer((_) async {});
      when(() => mockStorageService.saveTransaction(any(), applyImpact: false))
          .thenAnswer((_) async {});

      await cloudSyncService.restoreFromCloud();

      final captured = verify(() => mockStorageService.saveTransaction(
          captureAny(),
          applyImpact: false)).captured.single as Transaction;
      expect(captured.date.year, now.year);
      expect(captured.date.month, now.month);
      expect(captured.date.day, now.day);
    });
  });

  group('CloudSyncService - deleteCloudData', () {
    test('calls cloud storage delete', () async {
      when(() => mockCloudStorage.deleteData(any())).thenAnswer((_) async {});

      await cloudSyncService.deleteCloudData();

      verify(() => mockCloudStorage.deleteData('user123')).called(1);
    });
  });
}
