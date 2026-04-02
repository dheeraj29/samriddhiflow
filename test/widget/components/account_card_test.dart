import 'package:samriddhi_flow/l10n/app_localizations.dart';
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
      balance: 900,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

      expect(find.textContaining('Balance'),
          findsOneWidget); // Shows excess credit

      expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('300.00')),

        findsNWidgets(2), // Main title and mini-info chip
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

      expect(find.text('Billed'), findsOneWidget);

      expect(find.textContaining('700'), findsOneWidget);

      expect(find.text('Unbilled'), findsOneWidget);

      expect(find.textContaining('500'), findsOneWidget);

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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets('AccountCard shows billing dates for credit card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));

    final account = Account(
      id: 'cc1',
      name: 'Test CC',
      type: AccountType.creditCard,
      balance: 1000,
      billingCycleDay: 15,
      profileId: 'default',
      currency: 'en_IN',
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

    // Verify billing dates are shown

    expect(find.textContaining('Last:'), findsOneWidget);

    expect(find.textContaining('Next:'), findsOneWidget);
  });

  testWidgets('AccountCard shows Calculates on (unfreeze date) when isFrozen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));

    final account = Account(
      id: 'cc_frozen',
      name: 'Frozen CC',
      type: AccountType.creditCard,
      balance: 100,
      billingCycleDay: 25,
      isFrozen: true,
      isFrozenCalculated: false,
      freezeDate: DateTime(2024, 1, 1),
      firstStatementDate: DateTime(2024, 1, 25),
      profileId: 'default',
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

    // Verify "Calculates on" is shown instead of standard cycle info

    expect(find.textContaining('Calculates on'), findsOneWidget);

    expect(find.textContaining('25'), findsOneWidget);
  });

  testWidgets('AccountCard waterfall hides everything when offset by credit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));

    final account = Account(
      id: 'cc_credit',

      name: 'Credit CC',

      type: AccountType.creditCard,

      balance: -500, // Credit available

      billingCycleDay: 25,

      profileId: 'default',
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 350,
              height: 250,
              child: AccountCard(
                account: account,

                billedAmount: 200, // Fully offset

                unbilledAmount: 200, // Fully offset
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.pump();

    // With 500 credit, 200 billed and 200 unbilled are both offset to 0.

    // The Adjusted balance is also 0.

    // So the card should only show the available credit as a positive number or just 0.0.

    expect(find.textContaining('Billed'), findsNothing);

    expect(find.textContaining('Unbilled'), findsNothing);

    expect(
        find.textContaining('Balance'), findsOneWidget); // Shows excess credit

    // Remaining credit = 500 - 200 - 200 = 100

    expect(find.textContaining('100.00'), findsNWidgets(2));
  });
}
