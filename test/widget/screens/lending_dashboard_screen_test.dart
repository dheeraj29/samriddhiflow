import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/screens/lending/lending_dashboard_screen.dart';
import 'package:samriddhi_flow/services/lending/lending_provider.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:samriddhi_flow/providers.dart';

class MockLendingNotifier extends Notifier<List<LendingRecord>>
    implements LendingNotifier {
  final List<LendingRecord> _records;
  MockLendingNotifier([this._records = const []]);

  @override
  List<LendingRecord> build() => _records;

  @override
  Future<void> deleteRecord(String id) async {}

  @override
  Future<void> addRecord(LendingRecord record) async {}

  @override
  Future<void> updateRecord(LendingRecord record) async {}
}

class MockCurrencyNotifier extends Notifier<String>
    implements CurrencyNotifier {
  final String _locale;
  MockCurrencyNotifier([this._locale = 'en_IN']);
  @override
  String build() => _locale;

  @override
  Future<void> setCurrency(String locale) async {}
}

void main() {
  testWidgets('LendingDashboardScreen basic UI check and summary cards',
      (WidgetTester tester) async {
    final record = LendingRecord(
      id: '1',
      personName: 'John',
      amount: 1000,
      date: DateTime.now(),
      type: LendingType.lent,
      reason: 'Loan',
    );
    final record2 = LendingRecord(
      id: '2',
      personName: 'Doe',
      amount: 500,
      date: DateTime.now(),
      type: LendingType.borrowed,
      reason: 'Loan 2',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyProvider.overrideWith(() => MockCurrencyNotifier()),
          lendingProvider
              .overrideWith(() => MockLendingNotifier([record, record2])),
        ],
        child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: LendingDashboardScreen()),
      ),
    );

    expect(find.text('Lending & Borrowing'), findsOneWidget);
    expect(find.text('Total Lent'), findsOneWidget);
    expect(find.text('Total Borrowed'), findsOneWidget);

    expect(find.textContaining('1,000'), findsWidgets);
    expect(find.textContaining('500'), findsWidgets);
  });

  testWidgets('LendingDashboardScreen shows empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyProvider.overrideWith(() => MockCurrencyNotifier()),
          lendingProvider.overrideWith(() => MockLendingNotifier([])),
        ],
        child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: LendingDashboardScreen()),
      ),
    );

    expect(find.text('No records found.'), findsOneWidget);
  });

  testWidgets('LendingDashboardScreen handles all popup menu actions',
      (WidgetTester tester) async {
    final record = LendingRecord(
      id: '1',
      personName: 'John Doe',
      amount: 500,
      date: DateTime.now(),
      type: LendingType.lent,
      reason: 'Loan',
      payments: [LendingPayment(id: 'p1', amount: 10, date: DateTime.now())],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyProvider.overrideWith(() => MockCurrencyNotifier()),
          lendingProvider.overrideWith(() => MockLendingNotifier([record])),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: LendingDashboardScreen(),
        ),
      ),
    );

    // Opening Menu
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // 1. Record Payment
    await tester.tap(find.text('Record Payment'));
    await tester.pumpAndSettle();
    expect(find.text('Record Payment'), findsWidgets); // Dialog title
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 2. Payment History
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment History'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 3. Settle Full
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settle Full'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsWidgets);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    // 4. Edit
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 5. Delete
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Record?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
