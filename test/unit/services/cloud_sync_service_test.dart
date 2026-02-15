import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/cloud_storage_interface.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';

class MockCloudStorage extends Mock implements CloudStorageInterface {
  Map<String, dynamic>? _data;

  @override
  Future<void> syncData(String uid, Map<String, dynamic> data) async {
    _data = data;
  }

  @override
  Future<Map<String, dynamic>?> fetchData(String uid) async {
    return _data;
  }
}

class MockStorageService extends Mock implements StorageService {
  final List<LendingRecord> _lendingRecords = [];

  @override
  List<LendingRecord> getLendingRecords() => _lendingRecords;

  @override
  Future<void> saveLendingRecord(LendingRecord record) async {
    _lendingRecords.add(record);
  }

  @override
  Future<void> clearAllData() async {
    _lendingRecords.clear();
  }

  // Stubs for other calls in syncToCloud
  @override
  List<Account> getAllAccounts() => [];
  @override
  List<Transaction> getAllTransactions() => [];
  @override
  List<Loan> getAllLoans() => [];
  @override
  List<RecurringTransaction> getAllRecurring() => [];
  @override
  List<Category> getAllCategories() => [];
  @override
  List<Profile> getProfiles() => [];
  @override
  Map<String, dynamic> getAllSettings() => {};
  @override
  List<InsurancePolicy> getInsurancePolicies() => [];
  @override
  List<TaxYearData> getAllTaxYearData() => [];
}

class MockTaxConfigService extends Mock implements TaxConfigService {
  @override
  Map<int, TaxRules> getAllRules() => {};
}

class MockUser extends Mock implements User {
  @override
  String get uid => 'test_uid';
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  User? get currentUser => MockUser();
}

void main() {
  late CloudSyncService syncService;
  late MockCloudStorage mockCloudStorage;
  late MockStorageService mockStorageService;
  late MockTaxConfigService mockTaxConfigService;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockCloudStorage = MockCloudStorage();
    mockStorageService = MockStorageService();
    mockTaxConfigService = MockTaxConfigService();
    mockAuth = MockFirebaseAuth();

    syncService = CloudSyncService(
      mockCloudStorage,
      mockStorageService,
      mockTaxConfigService,
      firebaseAuth: mockAuth,
    );
  });

  test('syncToCloud includes lending records', () async {
    final record = LendingRecord.create(
      personName: 'Test Person',
      amount: 100.0,
      reason: 'Test Reason',
      date: DateTime.now(),
      type: LendingType.lent,
    );
    mockStorageService._lendingRecords.add(record);

    await syncService.syncToCloud();

    final data = mockCloudStorage._data;
    expect(data, isNotNull);
    expect(data!.containsKey('lending_records'), true);
    final records = data['lending_records'] as List;
    expect(records.length, 1);
    expect(records[0]['personName'], 'Test Person');
  });

  test('restoreFromCloud restores lending records', () async {
    // Setup cloud data
    final recordMap = {
      'id': 'test_id',
      'personName': 'Restored Person',
      'amount': 500.0,
      'reason': 'Restored Reason',
      'date': DateTime.now().toIso8601String(),
      'type': LendingType.borrowed.index,
      'isClosed': false,
      'profileId': 'default',
    };

    mockCloudStorage._data = {
      'lending_records': [recordMap],
      // Add other required fields as empty to avoid null errors
      // check CloudSyncService for what it expects
    };

    await syncService.restoreFromCloud();

    expect(mockStorageService._lendingRecords.length, 1);
    final restored = mockStorageService._lendingRecords.first;
    expect(restored.personName, 'Restored Person');
    expect(restored.amount, 500.0);
    expect(restored.type, LendingType.borrowed);
  });
}
