import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/widgets/transaction_filter.dart';

void main() {
  testWidgets('TransactionFilter renders and triggers callbacks',
      (tester) async {
    tester.view.physicalSize = const Size(2000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    TimeRange? changedRange;
    String? changedCategory;
    String? changedAccount;
    TransactionType? changedType;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionFilter(
          selectedRange: TimeRange.all,
          selectedCategory: null,
          selectedAccountId: null,
          categories: const ['Food', 'Salary'],
          accountItems: const [
            DropdownMenuItem(value: 'acc1', child: Text('Cash')),
            DropdownMenuItem(value: 'acc2', child: Text('Bank')),
          ],
          onRangeChanged: (v) => changedRange = v,
          onCategoryChanged: (v) => changedCategory = v,
          onAccountChanged: (v) => changedAccount = v,
          onTypeChanged: (v) => changedType = v,
          onCustomRangeTap: () {},
          customRangeLabel: 'May 1 - May 31',
        ),
      ),
    ));

    // Verify initial renders
    expect(find.text('All Time'), findsOneWidget);
    expect(find.text('All Categories'), findsOneWidget);
    expect(find.text('All Types'), findsOneWidget);
    expect(find.text('All Accounts'), findsOneWidget);

    // 1. Change Time Range
    await tester.tap(find.text('All Time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 30 Days').last);
    await tester.pumpAndSettle();
    expect(changedRange, TimeRange.last30Days);

    // 2. Change Category
    await tester.tap(find.text('All Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    expect(changedCategory, 'Food');

    // 3. Change Type
    await tester.tap(find.text('All Types'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();
    expect(changedType, TransactionType.income);

    // 4. Change Account
    await tester.tap(find.text('All Accounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    expect(changedAccount, 'acc1');
  });

  testWidgets('TransactionFilter handles custom range visibility and tap',
      (tester) async {
    tester.view.physicalSize = const Size(2000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool customTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionFilter(
          selectedRange: TimeRange.custom,
          selectedCategory: null,
          selectedAccountId: null,
          categories: const [],
          accountItems: const [],
          onRangeChanged: (_) {},
          onCategoryChanged: (_) {},
          onAccountChanged: (_) {},
          onTypeChanged: (_) {},
          onCustomRangeTap: () => customTapped = true,
          customRangeLabel: 'May 1 - May 31',
        ),
      ),
    ));

    expect(find.text('May 1 - May 31'), findsOneWidget);
    expect(find.text('Select Dates'), findsOneWidget);

    await tester.tap(find.text('May 1 - May 31'));
    await tester.pumpAndSettle();
    expect(customTapped, isTrue);
  });
}
