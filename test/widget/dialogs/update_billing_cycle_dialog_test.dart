import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/update_billing_cycle_dialog.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockStorageService mockStorageService;
  late Account testAccount;
  final newestTxnDate = DateTime(2024, 1, 1);

  setUpAll(() {
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockStorageService = MockStorageService();
    testAccount = Account(
      id: 'acc1',
      name: 'Test CC',
      type: AccountType.creditCard,
      balance: 0,
      billingCycleDay: 25,
      paymentDueDateDay: 28,
      profileId: 'default',
    );
  });

  Widget createTestWidget(WidgetTester tester) {
    // Standardize viewport for consistent layout
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => UpdateBillingCycleDialog(
                  account: testAccount,
                  newestTransactionDate: newestTxnDate,
                ),
              ),
              child: const Text('Open Dialog'),
            );
          }),
        ),
      ),
    );
  }

  testWidgets('UpdateBillingCycleDialog renders initial state correctly',
      (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Update Billing Cycle'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    // Label is hidden by default because _cycleDay hasn't changed from original 25
    expect(find.text('Select First Statement Month:'), findsNothing);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('Successful submission flow with radio selection',
      (tester) async {
    when(() => mockStorageService.updateBillingCycle(
          accountId: any(named: 'accountId'),
          newCycleDay: any(named: 'newCycleDay'),
          newDueDateDay: any(named: 'newDueDateDay'),
          freezeDate: any(named: 'freezeDate'),
          firstStatementDate: any(named: 'firstStatementDate'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(createTestWidget(tester));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // 1. Change Cycle Day FIRST
    final cycleDayDropdown = find.byKey(const Key('cycleDayDropdown'));
    await tester.tap(cycleDayDropdown);
    await tester.pumpAndSettle();
    final item5 = find.text('5').last;
    await tester.tap(item5);
    await tester.pumpAndSettle();

    // 2. NOW Select First Statement Month (Radio)
    // After cycle day change, options are recalculated
    await tester.tap(find.byType(RadioListTile<DateTime>).first);
    await tester.pumpAndSettle();

    // 3. Submit
    await tester.tap(find.text('Initialize Update'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.updateBillingCycle(
          accountId: 'acc1',
          newCycleDay: 5,
          newDueDateDay: any(named: 'newDueDateDay'),
          freezeDate: newestTxnDate, // Verified: matches last transaction date
          firstStatementDate:
              DateTime(2024, 1, 5), // Verified: next cycle end after Jan 1
        )).called(1);

    expect(find.text('Billing cycle update initialized successfully!'),
        findsOneWidget);
  });

  testWidgets('Shows validation error if statement date is not selected',
      (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // 1. Change cycle day first (Original 25 -> 5)
    final cycleDayDropdown = find.byKey(const Key('cycleDayDropdown'));
    await tester.tap(cycleDayDropdown);
    await tester.pumpAndSettle();

    // Tap the '5' in the menu
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Initialize Update'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 500)); // Middle of animation

    expect(find.textContaining('Please select'), findsOneWidget);
  });

  testWidgets('Shows error message when storageService throws', (tester) async {
    when(() => mockStorageService.updateBillingCycle(
          accountId: any(named: 'accountId'),
          newCycleDay: any(named: 'newCycleDay'),
          newDueDateDay: any(named: 'newDueDateDay'),
          freezeDate: any(named: 'freezeDate'),
          firstStatementDate: any(named: 'firstStatementDate'),
        )).thenThrow(Exception('Update failed'));

    await tester.pumpWidget(createTestWidget(tester));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
    // 1. Change cycle day first to show radio and "Initialize Update" button
    final cycleDayDropdown = find.byKey(const Key('cycleDayDropdown'));
    await tester.tap(cycleDayDropdown); // Billing Cycle Day
    await tester.pumpAndSettle();
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RadioListTile<DateTime>).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Initialize Update'));
    await tester.pumpAndSettle();

    expect(find.text('Exception: Update failed'), findsOneWidget);
  });

  testWidgets('Cancel button closes dialog', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(UpdateBillingCycleDialog), findsNothing);
  });

  testWidgets(
      'Shows statement date options from two different months when frozen',
      (tester) async {
    // Setup frozen account
    testAccount = testAccount.copyWith(
      isFrozen: true,
      isFrozenCalculated: false,
      freezeDate: DateTime(2024, 1, 1),
    );

    await tester.pumpWidget(createTestWidget(tester));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Change Cycle Day from 25 -> 5
    final cycleDayDropdown = find.byKey(const Key('cycleDayDropdown'));
    await tester.tap(cycleDayDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();

    // Verify radio buttons show dates from Jan and Feb (since freeze was Jan 1)
    // Note: We use find.descendant to avoid matching the "Freeze Transactions Until" subtitle
    final radioParent = find.byType(RadioGroup<DateTime>);
    expect(
        find.descendant(of: radioParent, matching: find.textContaining('Jan')),
        findsOneWidget);
    expect(
        find.descendant(of: radioParent, matching: find.textContaining('Feb')),
        findsOneWidget);
    expect(find.byType(RadioListTile<DateTime>), findsNWidgets(2));
  });

  testWidgets(
      'Dynamic UI: Button text changes to Initialize Update on cycle change',
      (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Initially says "Save Changes" (but might be disabled or just for payment due day)
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Initialize Update'), findsNothing);

    // Change Cycle Day
    final cycleDayDropdown = find.byKey(const Key('cycleDayDropdown'));
    await tester.tap(cycleDayDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();

    // Should now show "Initialize Update"
    expect(find.text('Initialize Update'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
  });
}
