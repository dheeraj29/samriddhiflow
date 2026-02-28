import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/cloud_storage_interface.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

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
    registerFallbackValue(Loan(
        id: 'f',
        name: 'f',
        totalPrincipal: 0,
        remainingPrincipal: 0,
        interestRate: 0,
        tenureMonths: 0,
        startDate: DateTime.now(),
        emiAmount: 0,
        firstEmiDate: DateTime.now()));
    registerFallbackValue(const TaxYearData(year: 2025));
    registerFallbackValue(TaxRules());

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

    test('encrypts profiles and tax rules when passcode provided', () async {
      when(() => mockStorageService.getAllAccounts()).thenReturn([]);
      when(() => mockStorageService.getAllTransactions()).thenReturn([]);
      when(() => mockStorageService.getAllLoans()).thenReturn([]);
      when(() => mockStorageService.getAllRecurring()).thenReturn([]);
      when(() => mockStorageService.getAllCategories()).thenReturn([]);
      when(() => mockStorageService.getProfiles()).thenReturn([
        Profile(id: 'p1', name: 'Profile 1'),
      ]);
      when(() => mockStorageService.getAllSettings()).thenReturn({});
      when(() => mockStorageService.getInsurancePolicies()).thenReturn([]);
      when(() => mockStorageService.getAllTaxYearData()).thenReturn([]);
      when(() => mockStorageService.getLendingRecords()).thenReturn([]);
      when(() => mockTaxConfigService.getAllRules()).thenReturn({});

      when(() => mockCloudStorage.syncData(any(), any()))
          .thenAnswer((_) async {});

      await cloudSyncService.syncToCloud(passcode: 'secret123');

      final captured =
          verify(() => mockCloudStorage.syncData('user123', captureAny()))
              .captured
              .single as Map<String, dynamic>;

      // Profiles and Tax Rules should be strings (encrypted) instead of lists/maps
      expect(captured['profiles'], isA<String>());
      expect(captured['tax_rules_v2'], isA<Map>());
      expect(captured['is_encrypted'], isTrue);
    });

    test('partitions transactions by month', () async {
      final t1 = Transaction.create(
          title: 'T1',
          amount: 10,
          date: DateTime(2024, 1, 15),
          type: TransactionType.expense,
          category: 'Food');
      final t2 = Transaction.create(
          title: 'T2',
          amount: 20,
          date: DateTime(2024, 2, 10),
          type: TransactionType.expense,
          category: 'Rent');

      when(() => mockStorageService.getAllTransactions()).thenReturn([t1, t2]);
      when(() => mockStorageService.getAllAccounts()).thenReturn([]);
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

      final captured =
          verify(() => mockCloudStorage.syncData('user123', captureAny()))
              .captured
              .single as Map<String, dynamic>;

      final txnsV2 = captured['transactions_v2'] as Map<String, dynamic>;
      expect(txnsV2.containsKey('2024-01'), isTrue);
      expect(txnsV2.containsKey('2024-02'), isTrue);
      expect(txnsV2['2024-01'], isA<List>());
      expect(txnsV2['2024-01'].length, 1);
    });

    test('throws error if not logged in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(() => cloudSyncService.syncToCloud(), throwsException);
    });
  });

  group('CloudSyncService - restoreFromCloud', () {
    test('restoreFromCloud strips isLoggedIn from settings', () async {
      final cloudData = {
        'settings': {
          'theme': 'dark',
          'isLoggedIn': true, // This should be stripped
        },
      };

      when(() => mockCloudStorage.fetchData('user123'))
          .thenAnswer((_) async => cloudData);
      when(() => mockStorageService.getAllTaxYearData()).thenReturn([]);
      when(() => mockStorageService.getLendingRecords()).thenReturn([]);
      when(() => mockStorageService.clearAllData()).thenAnswer((_) async {});

      Map<String, dynamic>? savedSettings;
      when(() => mockStorageService.saveSettings(any()))
          .thenAnswer((invocation) async {
        savedSettings =
            invocation.positionalArguments[0] as Map<String, dynamic>;
      });

      await cloudSyncService.restoreFromCloud();

      expect(savedSettings, isNotNull);
      expect(savedSettings!['theme'], 'dark');
      expect(savedSettings!.containsKey('isLoggedIn'), isFalse);
    });

    test('recovers from partitioned v2 formats', () async {
      final cloudData = {
        'transactions_v2': {
          '2024-01': [
            {
              'id': 't1',
              'title': 'T1',
              'amount': 10.0,
              'date': DateTime(2024, 1, 15).toIso8601String(),
              'type': 1,
              'category': 'Food',
            }
          ]
        },
        'loans_v2': {
          'l1': {
            'id': 'l1',
            'name': 'Loan 1',
            'totalPrincipal': 1000.0,
            'remainingPrincipal': 1000.0,
            'interestRate': 10.0,
            'tenureMonths': 12,
            'startDate': DateTime(2024, 1, 1).toIso8601String(),
            'emiAmount': 100.0,
            'firstEmiDate': DateTime(2024, 2, 1).toIso8601String(),
          }
        },
        'tax_data_v2': {
          '2025': {'year': 2025}
        },
        'tax_rules_v2': {
          '2025': {'slabs': []}
        }
      };

      when(() => mockCloudStorage.fetchData('user123'))
          .thenAnswer((_) async => cloudData);
      when(() => mockStorageService.getAllTaxYearData()).thenReturn([]);
      when(() => mockStorageService.getLendingRecords()).thenReturn([]);
      when(() => mockStorageService.clearAllData()).thenAnswer((_) async {});
      when(() => mockStorageService.saveTransaction(any(), applyImpact: false))
          .thenAnswer((_) async {});
      when(() => mockStorageService.saveLoan(any())).thenAnswer((_) async {});
      when(() => mockStorageService.saveTaxYearData(any()))
          .thenAnswer((_) async {});
      when(() => mockTaxConfigService.restoreAllRules(any()))
          .thenAnswer((_) async {});

      await cloudSyncService.restoreFromCloud();

      verify(() =>
              mockStorageService.saveTransaction(any(), applyImpact: false))
          .called(1);
      verify(() => mockStorageService.saveLoan(any())).called(1);
      verify(() => mockStorageService.saveTaxYearData(any())).called(1);
      verify(() => mockTaxConfigService.restoreAllRules(any())).called(1);
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
