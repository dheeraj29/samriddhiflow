import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/models/investment.dart';
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
    registerFallbackValue(
        Account(id: 'f', name: 'f', type: AccountType.savings, balance: 0));
    registerFallbackValue(Transaction(
        id: 'f',
        title: 'f',
        amount: 0,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'c'));
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
    registerFallbackValue(RecurringTransaction(
        id: 'f',
        title: 'f',
        amount: 0,
        category: 'c',
        frequency: Frequency.monthly,
        nextExecutionDate: DateTime.now()));
    registerFallbackValue(<InsurancePolicy>[]);
    registerFallbackValue(LendingRecord(
        id: 'f',
        personName: 'f',
        amount: 0,
        reason: 'f',
        type: LendingType.lent,
        date: DateTime.now()));
    registerFallbackValue(Investment(
        id: 'f',
        name: 'f',
        type: InvestmentType.stock,
        acquisitionDate: DateTime.now(),
        acquisitionPrice: 0,
        quantity: 0));
    registerFallbackValue(<int, TaxRules>{});
    registerFallbackValue(<String, dynamic>{});

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('user123');
    when(() => mockUser.getIdToken(any())).thenAnswer((_) async => 'token123');
    when(() => mockCloudStorage.getActiveSessionId(any()))
        .thenAnswer((_) async => 'session123');
    when(() => mockStorageService.getSessionId()).thenReturn('session123');

    cloudSyncService = CloudSyncService(
        mockCloudStorage, mockStorageService, mockTaxConfigService,
        firebaseAuth: mockAuth);
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
      when(() => mockStorageService.getAllInvestments()).thenReturn([]);
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
      when(() => mockStorageService.getAllInvestments()).thenReturn([]);
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
      when(() => mockStorageService.getAllInvestments()).thenReturn([]);
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

    test('partitions investments by month', () async {
      final i1 = Investment.create(
          name: 'I1',
          type: InvestmentType.stock,
          acquisitionDate: DateTime(2024, 1, 15),
          acquisitionPrice: 100,
          quantity: 10);
      final i2 = Investment.create(
          name: 'I2',
          type: InvestmentType.mutualFund,
          acquisitionDate: DateTime(2024, 2, 10),
          acquisitionPrice: 200,
          quantity: 5);

      when(() => mockStorageService.getAllInvestments()).thenReturn([i1, i2]);
      when(() => mockStorageService.getAllTransactions()).thenReturn([]);
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

      final invsV2 = captured['investments_v2'] as Map<String, dynamic>;
      expect(invsV2.containsKey('2024-01'), isTrue);
      expect(invsV2.containsKey('2024-02'), isTrue);
      expect(invsV2['2024-01'], isA<List>());
      expect(invsV2['2024-01'].length, 1);

      // Verify settings are scrubbed
      final settingsJson = captured['settings'];
      if (settingsJson is Map) {
        expect(settingsJson.containsKey('sessionId'), isFalse);
        expect(settingsJson.containsKey('isLoggedIn'), isFalse);
      }
    });

    test('partitions lending records by month', () async {
      final lr1 = LendingRecord(
          id: 'lr1',
          personName: 'John',
          amount: 100,
          reason: 'Loan',
          type: LendingType.lent,
          date: DateTime(2024, 1, 15));
      final lr2 = LendingRecord(
          id: 'lr2',
          personName: 'Jane',
          amount: 200,
          reason: 'Borrow',
          type: LendingType.borrowed,
          date: DateTime(2024, 2, 10));

      when(() => mockStorageService.getLendingRecords()).thenReturn([lr1, lr2]);
      when(() => mockStorageService.getAllInvestments()).thenReturn([]);
      when(() => mockStorageService.getAllTransactions()).thenReturn([]);
      when(() => mockStorageService.getAllAccounts()).thenReturn([]);
      when(() => mockStorageService.getAllLoans()).thenReturn([]);
      when(() => mockStorageService.getAllRecurring()).thenReturn([]);
      when(() => mockStorageService.getAllCategories()).thenReturn([]);
      when(() => mockStorageService.getProfiles()).thenReturn([]);
      when(() => mockStorageService.getAllSettings()).thenReturn({});
      when(() => mockStorageService.getInsurancePolicies()).thenReturn([]);
      when(() => mockStorageService.getAllTaxYearData()).thenReturn([]);
      when(() => mockTaxConfigService.getAllRules()).thenReturn({});

      when(() => mockCloudStorage.syncData(any(), any()))
          .thenAnswer((_) async {});

      await cloudSyncService.syncToCloud();

      final captured =
          verify(() => mockCloudStorage.syncData('user123', captureAny()))
              .captured
              .single as Map<String, dynamic>;

      final lrPartitioned = captured['lending_records'] as Map<String, dynamic>;
      expect(lrPartitioned.containsKey('2024-01'), isTrue);
      expect(lrPartitioned.containsKey('2024-02'), isTrue);
      expect(lrPartitioned['2024-01'], isA<List>());
      expect(lrPartitioned['2024-01'].length, 1);
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
      when(() => mockStorageService.getAllInvestments()).thenReturn([]);
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
      expect(savedSettings!.containsKey('sessionId'), isFalse);
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
      when(() => mockStorageService.getAllInvestments()).thenReturn([]);
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

    test('throws when user is null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(() => cloudSyncService.deleteCloudData(), throwsException);
    });
  });

  group('CloudSyncService - restoreFromCloud full paths', () {
    /// Helper that stubs fetchData to return `cloudData`
    /// and sets up standard mock returns for clearAllData, save*, etc.
    void stubRestore(Map<String, dynamic> cloudData) {
      when(() => mockCloudStorage.fetchData('user123'))
          .thenAnswer((_) async => cloudData);
      when(() => mockStorageService.getAllTaxYearData()).thenReturn([]);
      when(() => mockStorageService.clearAllData()).thenAnswer((_) async {});
      when(() => mockStorageService.saveProfile(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.addCategory(any(), isRestore: true))
          .thenAnswer((_) async {});
      when(() => mockStorageService.saveAccount(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.initRolloverForImport(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.saveTransaction(any(), applyImpact: false))
          .thenAnswer((_) async {});
      when(() => mockStorageService.saveLoan(any())).thenAnswer((_) async {});
      when(() => mockStorageService.saveRecurringTransaction(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.saveSettings(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.saveInsurancePolicies(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.saveTaxYearData(any()))
          .thenAnswer((_) async {});
      when(() => mockTaxConfigService.restoreAllRules(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.saveLendingRecord(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.saveInvestment(any()))
          .thenAnswer((_) async {});
    }

    test('restores profiles', () async {
      stubRestore({
        'profiles': [
          {'id': 'p1', 'name': 'Main'},
        ],
      });

      await cloudSyncService.restoreFromCloud();

      verify(() => mockStorageService.saveProfile(any())).called(1);
    });

    test('restores accounts with credit card rollover', () async {
      stubRestore({
        'accounts': [
          {
            'id': 'cc1',
            'name': 'CC',
            'type': AccountType.creditCard.index,
            'balance': 0,
            'billingCycleDay': 15,
          },
          {
            'id': 'sv1',
            'name': 'Savings',
            'type': AccountType.savings.index,
            'balance': 5000,
          },
        ],
      });

      await cloudSyncService.restoreFromCloud();

      verify(() => mockStorageService.saveAccount(any())).called(2);
      verify(() => mockStorageService.initRolloverForImport('cc1', 15))
          .called(1);
    });

    test('restores recurring transactions', () async {
      stubRestore({
        'recurring': [
          {
            'id': 'rt1',
            'title': 'Rent',
            'amount': 15000,
            'type': 1,
            'category': 'Rent',
            'frequency': Frequency.monthly.index,
            'nextExecutionDate': DateTime(2024, 1, 1).toIso8601String(),
          },
        ],
      });

      await cloudSyncService.restoreFromCloud();

      verify(() => mockStorageService.saveRecurringTransaction(any()))
          .called(1);
    });

    test('restores insurance policies', () async {
      stubRestore({
        'insurance_policies': [
          {
            'id': 'ip1',
            'policyName': 'Term Plan',
            'policyNumber': 'TP001',
            'annualPremium': 15000,
            'sumAssured': 5000000,
            'startDate': DateTime(2020, 1, 1).toIso8601String(),
            'maturityDate': DateTime(2050, 1, 1).toIso8601String(),
          },
        ],
      });

      await cloudSyncService.restoreFromCloud();

      verify(() => mockStorageService.saveInsurancePolicies(any())).called(1);
    });

    test('restores lending records', () async {
      stubRestore({
        'lending_records': {
          '2024-06': [
            {
              'id': 'lr1',
              'personName': 'John',
              'amount': 5000,
              'reason': 'Loan',
              'type': LendingType.lent.index,
              'date': DateTime(2024, 6, 1).toIso8601String(),
            }
          ]
        },
      });

      await cloudSyncService.restoreFromCloud();

      verify(() => mockStorageService.saveLendingRecord(any())).called(1);
    });

    test('restores investments', () async {
      stubRestore({
        'investments_v2': {
          '2024-01': [
            {
              'id': 'i1',
              'name': 'Inv 1',
              'acquisitionDate': DateTime(2024, 1, 15).toIso8601String(),
              'acquisitionPrice': 100,
              'quantity': 10,
              'type': InvestmentType.stock.index,
            }
          ]
        },
      });

      await cloudSyncService.restoreFromCloud();

      verify(() => mockStorageService.saveInvestment(any())).called(1);
    });

    test('mergeLocalTaxSafety preserves local data when cloud is empty',
        () async {
      // Local has tax data for 2025 with salary
      final localTaxData = [
        TaxYearData(
            year: 2025,
            salary: SalaryDetails(history: [
              SalaryStructure(
                  id: 'local',
                  monthlyBasic: 500000 / 12,
                  effectiveDate: DateTime(2025, 4, 1))
            ])),
      ];
      when(() => mockStorageService.getAllTaxYearData())
          .thenReturn(localTaxData);

      // Cloud has no tax data
      stubRestore({});
      // Override getAllTaxYearData specifically for this test
      when(() => mockStorageService.getAllTaxYearData())
          .thenReturn(localTaxData);

      await cloudSyncService.restoreFromCloud();

      // Local data for year 2025 should be re-saved (not in restored set)
      verify(() => mockStorageService.saveTaxYearData(any())).called(1);
    });

    test('mergeLocalTaxSafety merges salary when cloud has empty salary',
        () async {
      final localTaxData = [
        TaxYearData(
            year: 2025,
            salary: SalaryDetails(history: [
              SalaryStructure(
                  id: 'local',
                  monthlyBasic: 600000 / 12,
                  effectiveDate: DateTime(2025, 4, 1))
            ])),
      ];
      when(() => mockStorageService.getAllTaxYearData())
          .thenReturn(localTaxData);

      // Cloud has tax_data_v2 for 2025 but empty salary
      stubRestore({
        'tax_data_v2': {
          '2025': {'year': 2025},
        },
      });
      when(() => mockStorageService.getAllTaxYearData())
          .thenReturn(localTaxData);

      // After restoring, getTaxYearData will return the cloud's version (empty salary)
      when(() => mockStorageService.getTaxYearData(2025))
          .thenReturn(const TaxYearData(year: 2025));

      await cloudSyncService.restoreFromCloud();

      // saveTaxYearData should be called: once for restore, once for merge
      verify(() => mockStorageService.saveTaxYearData(any())).called(2);
    });

    test('restoreFromCloud throws if no data found', () async {
      when(() => mockCloudStorage.fetchData('user123'))
          .thenAnswer((_) async => null);

      expect(() => cloudSyncService.restoreFromCloud(), throwsException);
    });

    test('syncToCloud with partitioned tax rules', () async {
      when(() => mockStorageService.getAllAccounts()).thenReturn([]);
      when(() => mockStorageService.getAllTransactions()).thenReturn([]);
      when(() => mockStorageService.getAllLoans()).thenReturn([]);
      when(() => mockStorageService.getAllRecurring()).thenReturn([]);
      when(() => mockStorageService.getAllCategories()).thenReturn([]);
      when(() => mockStorageService.getProfiles()).thenReturn([]);
      when(() => mockStorageService.getAllSettings()).thenReturn({});
      when(() => mockStorageService.getInsurancePolicies()).thenReturn([]);
      when(() => mockStorageService.getAllTaxYearData()).thenReturn([
        const TaxYearData(year: 2025),
      ]);
      when(() => mockStorageService.getLendingRecords()).thenReturn([]);
      when(() => mockStorageService.getAllInvestments()).thenReturn([]);
      when(() => mockTaxConfigService.getAllRules()).thenReturn({
        2025: TaxRules(),
      });

      when(() => mockCloudStorage.syncData(any(), any()))
          .thenAnswer((_) async {});

      await cloudSyncService.syncToCloud();

      final captured =
          verify(() => mockCloudStorage.syncData('user123', captureAny()))
              .captured
              .single as Map<String, dynamic>;

      // Tax rules and data should be partitioned by year
      expect(captured['tax_rules_v2'], isA<Map>());
      expect((captured['tax_rules_v2'] as Map).containsKey('2025'), isTrue);
      expect(captured['tax_data_v2'], isA<Map>());
      expect((captured['tax_data_v2'] as Map).containsKey('2025'), isTrue);
    });
  });
}
