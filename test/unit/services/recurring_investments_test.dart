import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/investment.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:hive_ce/hive.dart';

class MockHiveInterface extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

void main() {
  late StorageService storageService;
  late MockHiveInterface mockHive;
  late MockBox<Investment> mockInvestmentsBox;
  late MockBox<dynamic> mockSettingsBox;

  setUpAll(() {
    registerFallbackValue(DateTime.now());
    registerFallbackValue(Investment.create(
      name: '',
      type: InvestmentType.stock,
      acquisitionDate: DateTime.now(),
      acquisitionPrice: 0,
      quantity: 0,
      currentPrice: 0,
      profileId: '',
    ));
  });

  setUp(() {
    mockHive = MockHiveInterface();
    mockInvestmentsBox = MockBox<Investment>();
    mockSettingsBox = MockBox<dynamic>();

    when(() => mockHive.isBoxOpen(any())).thenReturn(true);
    when(() => mockHive.box<Investment>(any())).thenReturn(mockInvestmentsBox);
    when(() => mockHive.box(any())).thenReturn(mockSettingsBox);

    // Default mock for holidays
    when(() => mockSettingsBox.get('holidays',
        defaultValue: any(named: 'defaultValue'))).thenReturn(<dynamic>[]);

    storageService = StorageService(mockHive);
  });

  group('processRecurringInvestments', () {
    test('does nothing if no recurring investments exist', () async {
      when(() => mockInvestmentsBox.toMap()).thenReturn({});

      await storageService.processRecurringInvestments();

      verifyNever(() => mockInvestmentsBox.put(any(), any()));
    });

    test('generates new record and advances date for catch-up', () async {
      final now = DateTime.now();
      // Ensure we are at least 32 days into the month or something to guarantee a loop
      // Actually, picking a date exactly 1 month ago usually triggers 2 iterations if we use isBefore || isSame
      final lastMonth = DateTime(now.year, now.month - 1, now.day);

      final inv = Investment.create(
        name: 'SIP',
        type: InvestmentType.mutualFund,
        acquisitionDate: lastMonth.subtract(const Duration(days: 30)),
        acquisitionPrice: 5000,
        quantity: 1.0,
        currentPrice: 5000,
        isRecurringEnabled: true,
        nextRecurringDate: lastMonth,
        recurringAmount: 5000,
        profileId: 'default',
      );

      when(() => mockInvestmentsBox.toMap()).thenReturn({inv.id: inv});
      when(() => mockInvestmentsBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.processRecurringInvestments();

      // Should have put 3 things usually (child 1, child 2, parent)
      // We check if it's called at least twice (one child, one parent)
      verify(() => mockInvestmentsBox.put(any(), any()))
          .called(greaterThanOrEqualTo(2));

      expect(inv.nextRecurringDate!.isAfter(lastMonth), true);
    });

    test('advances date but does NOT generate record if paused', () async {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, now.day);

      final inv = Investment.create(
        name: 'SIP Paused',
        type: InvestmentType.mutualFund,
        acquisitionDate: lastMonth.subtract(const Duration(days: 30)),
        acquisitionPrice: 5000,
        quantity: 1.0,
        currentPrice: 5000,
        isRecurringEnabled: true,
        isRecurringPaused: true,
        nextRecurringDate: lastMonth,
        recurringAmount: 5000,
        profileId: 'default',
      );

      when(() => mockInvestmentsBox.toMap()).thenReturn({inv.id: inv});
      when(() => mockInvestmentsBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.processRecurringInvestments();

      // Should have put only 1 thing: the updated parent investment
      verify(() => mockInvestmentsBox.put(inv.id, inv)).called(1);

      expect(inv.nextRecurringDate!.isAfter(lastMonth), true);
    });
  });
}
