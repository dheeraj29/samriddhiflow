import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/widgets/transaction_list_item.dart';

import 'package:samriddhi_flow/providers.dart';
import '../test_mocks.dart';

class MockCurrencyFormatNotifier extends CurrencyFormatNotifier {
  @override
  bool build() => false;
}

void main() {
  final account = Account(
      id: 'acc1', name: 'Cash', type: AccountType.wallet, balance: 1000);
  final category =
      Category(id: 'c1', name: 'Food', usage: CategoryUsage.expense);
  final incomeCategory =
      Category(id: 'c2', name: 'Salary', usage: CategoryUsage.income);
  final capitalGainCategory = Category(
      id: 'c3',
      name: 'Stocks',
      usage: CategoryUsage.income,
      tag: CategoryTag.capitalGain);

  Widget createWidget({
    required Transaction txn,
    bool isSelectionMode = false,
    bool isSelected = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return ProviderScope(
      overrides: [
        currencyProvider.overrideWith(() => MockCurrencyNotifier('en_IN')),
        currencyFormatProvider.overrideWith(() => MockCurrencyFormatNotifier()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TransactionListItem(
            txn: txn,
            currencyLocale: 'en_IN',
            accounts: [account],
            categories: [category, incomeCategory, capitalGainCategory],
            isSelectionMode: isSelectionMode,
            isSelected: isSelected,
            onTap: onTap ?? () {},
            onLongPress: onLongPress,
          ),
        ),
      ),
    );
  }

  testWidgets('TransactionListItem renders expense correctly', (tester) async {
    final txn = Transaction.create(
        title: 'Lunch',
        amount: 200,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'Food',
        accountId: 'acc1');

    await tester.pumpWidget(createWidget(txn: txn));
    await tester.pumpAndSettle();

    expect(find.text('Lunch'), findsOneWidget);
    // 200 formatted as -200.00 usually or similar depending on locale.
    // SmartCurrencyText might format it.
    // We check for text containing '200'.
    expect(find.textContaining('200'), findsOneWidget);
  });

  testWidgets('TransactionListItem renders income correctly', (tester) async {
    final txn = Transaction.create(
        title: 'Bonus',
        amount: 5000,
        date: DateTime.now(),
        type: TransactionType.income,
        category: 'Salary',
        accountId: 'acc1');

    await tester.pumpWidget(createWidget(txn: txn));
    await tester.pumpAndSettle();

    expect(find.text('Bonus'), findsOneWidget);
    expect(find.textContaining('5,000'), findsOneWidget);
  });

  testWidgets('TransactionListItem interactions', (tester) async {
    bool tapped = false;
    bool longPressed = false;
    final txn = Transaction.create(
        title: 'Tap Me',
        amount: 50,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'Food');

    await tester.pumpWidget(createWidget(
        txn: txn,
        onTap: () => tapped = true,
        onLongPress: () => longPressed = true));
    await tester.pumpAndSettle();

    // Check title to ensure it's rendered
    expect(find.text('Tap Me'), findsOneWidget);

    await tester.tap(find.text('Tap Me'), warnIfMissed: false);
    await tester.pump();
    expect(tapped, isTrue);

    await tester.longPress(find.text('Tap Me'), warnIfMissed: false);
    await tester.pump();
    expect(longPressed, isTrue);
  });

  testWidgets('TransactionListItem selection mode behavior', (tester) async {
    final txn = Transaction.create(
        title: 'Select Me',
        amount: 50,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'Food');

    await tester.pumpWidget(
        createWidget(txn: txn, isSelectionMode: true, isSelected: true));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('TransactionListItem renders capital gain info', (tester) async {
    final txn = Transaction.create(
        title: 'Stocks Sell',
        amount: 50000,
        date: DateTime.now(),
        type: TransactionType.income,
        category: 'Stocks',
        gainAmount: 5000,
        holdingTenureMonths: 14);

    await tester.pumpWidget(createWidget(txn: txn));
    await tester.pumpAndSettle();

    expect(find.textContaining('Profit:'), findsOneWidget);
    expect(find.textContaining('Held: 1 yr 2 mos'), findsOneWidget);
  });
}
