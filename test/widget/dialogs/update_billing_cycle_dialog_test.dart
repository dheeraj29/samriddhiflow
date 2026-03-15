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
  });

  testWidgets('Successful submission flow with dropdown and datepicker',
      (tester) async {
    when(() => mockStorageService.updateBillingCycle(
          accountId: any(named: 'accountId'),
          newCycleDay: any(named: 'newCycleDay'),
          newDueDateDay: any(named: 'newDueDateDay'),
          freezeDate: any(named: 'freezeDate'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(createTestWidget(tester));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // 1. Select Freeze Date
    await tester.tap(find.text('Select Freeze Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // 2. Change Cycle Day
    // Use the explicit label to find the right dropdown if possible
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();

    // In many Flutter versions, dropdown items are offstage or in a separate stack
    // until fully settled. We find '5' in the list.
    final item5 = find.text('5').last;
    await tester.tap(item5);
    await tester.pumpAndSettle();

    // 3. Change Due Day
    await tester.tap(find.text('28'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('10').last);
    await tester.pumpAndSettle();

    // 4. Submit
    await tester.tap(find.text('Initialize Update'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.updateBillingCycle(
          accountId: 'acc1',
          newCycleDay: 5,
          newDueDateDay: 10,
          freezeDate: any(named: 'freezeDate'),
        )).called(1);

    expect(find.text('Billing cycle update initialized successfully!'),
        findsOneWidget);
  });

  testWidgets('Shows validation error if freeze date is not selected',
      (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Initialize Update'));
    await tester.pumpAndSettle();

    expect(find.text('Please select a Freeze Date.'), findsOneWidget);
  });

  testWidgets('Shows error message when storageService throws', (tester) async {
    when(() => mockStorageService.updateBillingCycle(
          accountId: any(named: 'accountId'),
          newCycleDay: any(named: 'newCycleDay'),
          newDueDateDay: any(named: 'newDueDateDay'),
          freezeDate: any(named: 'freezeDate'),
        )).thenThrow(Exception('Update failed'));

    await tester.pumpWidget(createTestWidget(tester));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select Freeze Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
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
}
