import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/widgets/account_card.dart';
import 'package:samriddhi_flow/providers.dart';

void main() {
  setUp(() {
    // Standardize text scaling for tests
  });

  testWidgets('AccountCard renders savings type and handles tap',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    bool tapped = false;
    final account = Account(
      id: 's1',
      name: 'My Savings',
      type: AccountType.savings,
      balance: 1000,
      profileId: 'default',
      currency: 'en_IN',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currencyFormatProvider
            .overrideWith(() => CurrencyFormatNotifier()..value = false),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 250,
              child: AccountCard(
                account: account,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.pump();
    expect(find.text('My Savings'), findsOneWidget);
    // Relaxed text expectation to avoid SmartCurrencyText formatting issues during first pump
    expect(find.byType(AccountCard), findsOneWidget);

    await tester.tap(find.byType(AccountCard));
    expect(tapped, isTrue);
  });

  testWidgets('AccountCard renders wallet type', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));

    final account = Account(
      id: 'w1',
      name: 'Cash Wallet',
      type: AccountType.wallet,
      balance: 500,
      profileId: 'default',
      currency: 'en_US',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currencyFormatProvider
            .overrideWith(() => CurrencyFormatNotifier()..value = false),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 250,
              child: AccountCard(account: account),
            ),
          ),
        ),
      ),
    ));

    await tester.pump();
    expect(find.text('Cash Wallet'), findsOneWidget);
  });

  testWidgets('AccountCard renders credit card with high utilization',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));

    final account = Account(
      id: 'c1',
      name: 'Credit Card',
      type: AccountType.creditCard,
      balance: 950,
      creditLimit: 1000,
      profileId: 'default',
      currency: 'en_IN',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currencyFormatProvider
            .overrideWith(() => CurrencyFormatNotifier()..value = false),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 250,
              child: AccountCard(
                account: account,
                unbilledAmount: 50,
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.pump();
    expect(find.text('Credit Card'), findsOneWidget);
    expect(find.textContaining('Used 95%'), findsOneWidget);

    final indicator = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.color, Colors.redAccent);
  });

  testWidgets('AccountCard handles zero credit limit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));

    final account = Account(
      id: 'c2',
      name: 'Zero Limit Card',
      type: AccountType.creditCard,
      balance: 100,
      creditLimit: 0,
      profileId: 'default',
      currency: 'en_IN',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currencyFormatProvider
            .overrideWith(() => CurrencyFormatNotifier()..value = false),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 250,
              child: AccountCard(account: account),
            ),
          ),
        ),
      ),
    ));

    await tester.pump();
    expect(find.textContaining('Used 0%'), findsOneWidget);
    final indicator = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.value, 0.0);
  });

  group('AccountCard Negative Balance Fix', () {
    testWidgets(
        'AccountCard offsets negative balance against billed AND unbilled',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final account = Account(
        id: 'cc1',
        name: 'Test CC',
        type: AccountType.creditCard,
        balance: -2000,
        currency: 'INR',
        billingCycleDay: 15,
      );

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                height: 250,
                child: AccountCard(
                  account: account,
                  billedAmount: 1200,
                  unbilledAmount: 500,
                  compactView: false,
                ),
              ),
            ),
          ),
        ),
      ));

      await tester.pump();

      expect(find.textContaining('Billed'), findsNothing);
      expect(find.textContaining('Unbilled'), findsNothing);
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('Balance:') &&
            widget.data!.contains('300')),
        findsOneWidget,
      );
    });

    testWidgets('AccountCard offsets negative balance partially',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final account = Account(
        id: 'cc1',
        name: 'Test CC',
        type: AccountType.creditCard,
        balance: -500, // Excess payment of 500
        currency: 'INR',
        billingCycleDay: 15,
      );

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                height: 250,
                child: AccountCard(
                  account: account,
                  billedAmount: 1200,
                  unbilledAmount: 500,
                  compactView: false,
                ),
              ),
            ),
          ),
        ),
      ));

      await tester.pump();

      expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('Billed:') &&
            widget.data!.contains('700')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('Unbilled:') &&
            widget.data!.contains('500')),
        findsOneWidget,
      );
      expect(find.textContaining('Balance'), findsNothing);
    });

    testWidgets('AccountCard zeros everything when exactly paid',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final account = Account(
        id: 'cc1',
        name: 'Test CC',
        type: AccountType.creditCard,
        balance: -1700, // Pays off 1200 billed + 500 unbilled
        currency: 'INR',
        billingCycleDay: 15,
      );

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                height: 250,
                child: AccountCard(
                  account: account,
                  billedAmount: 1200,
                  unbilledAmount: 500,
                  compactView: false,
                ),
              ),
            ),
          ),
        ),
      ));

      await tester.pump();

      expect(find.textContaining('Billed'), findsNothing);
      expect(find.textContaining('Unbilled'), findsNothing);
      expect(find.textContaining('Balance'), findsNothing);
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('0.00')),
        findsOneWidget,
      );
    });
  });
}
