import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/cloud_storage_interface.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';

import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockCloudStorageInterface extends Mock implements CloudStorageInterface {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class AccountFake extends Fake implements Account {}

class TransactionFake extends Fake implements Transaction {}

class LoanFake extends Fake implements Loan {}

class CategoryFake extends Fake implements Category {}

class ProfileFake extends Fake implements Profile {}

class RecurringTransactionFake extends Fake implements RecurringTransaction {}

void main() {
  setUpAll(() {
    registerFallbackValue(AccountFake());
    registerFallbackValue(TransactionFake());
    registerFallbackValue(LoanFake());
    registerFallbackValue(CategoryFake());
    registerFallbackValue(ProfileFake());
    registerFallbackValue(RecurringTransactionFake());
  });

  late CloudSyncService cloudSyncService;
  late MockStorageService mockStorage;
  late MockTaxConfigService mockTaxConfig;
  late MockCloudStorageInterface mockCloud;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockStorage = MockStorageService();
    mockTaxConfig = MockTaxConfigService();
    mockCloud = MockCloudStorageInterface();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    cloudSyncService = CloudSyncService(mockCloud, mockStorage, mockTaxConfig,
        firebaseAuth: mockAuth);

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('user123');
  });

  group('CloudSyncService - Mappings & Sync Mastery', () {
    test('syncToCloud - Full Serialization exhaustive', () async {
      when(() => mockStorage.getAllAccounts()).thenReturn([
        Account(
            id: 'a1',
            name: 'A1',
            type: AccountType.savings,
            balance: 100,
            profileId: 'p1')
      ]);
      when(() => mockStorage.getAllTransactions()).thenReturn([
        Transaction(
            id: 't1',
            title: 'T1',
            amount: 50,
            date: DateTime.now(),
            type: TransactionType.expense,
            accountId: 'a1',
            profileId: 'p1',
            category: 'C1')
      ]);
      final loan = Loan(
          id: 'l1',
          name: 'L1',
          totalPrincipal: 1000,
          remainingPrincipal: 900,
          interestRate: 12,
          tenureMonths: 24,
          startDate: DateTime.now(),
          emiAmount: 50,
          firstEmiDate: DateTime.now(),
          profileId: 'p1');
      loan.transactions = [
        LoanTransaction(
            id: 'lt1',
            date: DateTime.now(),
            amount: 50,
            type: LoanTransactionType.emi,
            principalComponent: 40,
            interestComponent: 10,
            resultantPrincipal: 960)
      ];
      when(() => mockStorage.getAllLoans()).thenReturn([loan]);
      when(() => mockStorage.getAllRecurring()).thenReturn([
        RecurringTransaction(
            id: 'r1',
            title: 'R1',
            amount: 10,
            category: 'C1',
            accountId: 'a1',
            frequency: Frequency.monthly,
            nextExecutionDate: DateTime.now())
      ]);
      when(() => mockStorage.getAllCategories()).thenReturn([
        Category(
            id: 'c1',
            name: 'C1',
            usage: CategoryUsage.both,
            tag: CategoryTag.none,
            iconCode: 1,
            profileId: 'p1')
      ]);
      when(() => mockStorage.getProfiles())
          .thenReturn([Profile(id: 'p1', name: 'P1')]);
      when(() => mockStorage.getAllSettings()).thenReturn({'theme': 'dark'});

      when(() => mockStorage.getInsurancePolicies()).thenReturn([]);
      when(() => mockStorage.getAllTaxYearData()).thenReturn([]);
      when(() => mockTaxConfig.getAllRules()).thenReturn({});
      when(() => mockCloud.syncData(any(), any())).thenAnswer((_) async {});

      await cloudSyncService.syncToCloud();

      verify(() => mockCloud.syncData('user123', any())).called(1);
    });

    test('restoreFromCloud - Full Deserialization exhaustive', () async {
      final nowStr = DateTime.now().toIso8601String();
      final data = {
        'profiles': [
          {
            'id': 'p1',
            'name': 'P1',
            'currencyLocale': 'en_IN',
            'monthlyBudget': 1000.0
          }
        ],
        'accounts': [
          {
            'id': 'a1',
            'name': 'A1',
            'balance': 500.0,
            'type': 0,
            'profileId': 'p1'
          }
        ],
        'categories': [
          {
            'id': 'c1',
            'name': 'C1',
            'usage': 0,
            'tag': 0,
            'iconCode': 1,
            'profileId': 'p1'
          }
        ],
        'transactions': [
          {
            'id': 't1',
            'title': 'T1',
            'amount': 100.0,
            'date': nowStr,
            'type': 0,
            'category': 'C1',
            'accountId': 'a1'
          }
        ],
        'loans': [
          {
            'id': 'l1',
            'name': 'L1',
            'totalPrincipal': 1000.0,
            'remainingPrincipal': 900.0,
            'interestRate': 12.0,
            'tenureMonths': 24,
            'startDate': nowStr,
            'emiAmount': 50.0,
            'firstEmiDate': nowStr,
            'profileId': 'p1',
            'transactions': [
              {
                'id': 'lt1',
                'date': nowStr,
                'amount': 50.0,
                'type': 0,
                'principalComponent': 40.0,
                'interestComponent': 10.0,
                'resultantPrincipal': 960.0
              }
            ]
          }
        ],
        'recurring': [
          {
            'id': 'r1',
            'title': 'R1',
            'amount': 10.0,
            'category': 'C1',
            'accountId': 'a1',
            'frequency': 2,
            'nextExecutionDate': nowStr,
            'scheduleType': 0
          }
        ],
        'settings': {'theme': 'dark'}
      };

      when(() => mockCloud.fetchData(any())).thenAnswer((_) async => data);
      when(() => mockStorage.clearAllData()).thenAnswer((_) async {});
      when(() => mockStorage.saveProfile(any())).thenAnswer((_) async {});
      when(() => mockStorage.saveAccount(any())).thenAnswer((_) async {});
      when(() => mockStorage.addCategory(any())).thenAnswer((_) async {});
      when(() => mockStorage.saveTransaction(any(),
          applyImpact: any(named: 'applyImpact'))).thenAnswer((_) async {});
      when(() => mockStorage.saveLoan(any())).thenAnswer((_) async {});
      when(() => mockStorage.saveRecurringTransaction(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.saveInsurancePolicies(any()))
          .thenAnswer((_) async {});
      when(() => mockTaxConfig.restoreAllRules(any())).thenAnswer((_) async {});
      when(() => mockStorage.saveSettings(any())).thenAnswer((_) async {});

      await cloudSyncService.restoreFromCloud();

      verify(() => mockStorage.clearAllData()).called(1);
      verify(() => mockStorage.saveProfile(any())).called(1);
      verify(() => mockStorage.saveAccount(any())).called(1);
      verify(() => mockStorage.addCategory(any())).called(1);
      verify(() => mockStorage.saveTransaction(any(), applyImpact: false))
          .called(1);
      verify(() => mockStorage.saveLoan(any())).called(1);
      verify(() => mockStorage.saveRecurringTransaction(any())).called(1);
      verify(() => mockStorage.saveSettings(any())).called(1);
    });

    test('Edge Cases - Auth Null', () async {
      final cloudNoAuth =
          CloudSyncService(mockCloud, mockStorage, mockTaxConfig);
      expect(() => cloudNoAuth.syncToCloud(), throwsA(isA<Exception>()));
      expect(() => cloudNoAuth.restoreFromCloud(), throwsA(isA<Exception>()));
      expect(() => cloudNoAuth.deleteCloudData(), throwsA(isA<Exception>()));
    });

    test('Edge Cases - User Null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(() => cloudSyncService.syncToCloud(), throwsA(isA<Exception>()));
      expect(
          () => cloudSyncService.restoreFromCloud(), throwsA(isA<Exception>()));
      expect(
          () => cloudSyncService.deleteCloudData(), throwsA(isA<Exception>()));
    });
  });
}
