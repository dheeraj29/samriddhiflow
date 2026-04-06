import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:samriddhi_flow/models/investment.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/add_investment_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockInvestmentsNotifier extends InvestmentsNotifier {
  List<Investment> _investments;
  MockInvestmentsNotifier(this._investments);

  @override
  List<Investment> build() => _investments;

  @override
  Future<void> saveInvestment(Investment inv) async {
    _investments = _investments.map((e) => e.id == inv.id ? inv : e).toList();
    if (!_investments.any((e) => e.id == inv.id)) _investments.add(inv);
    state = _investments;
  }

  @override
  Future<void> updateCodeNameBulk(String oldCode, String newCode) async {
    _investments = _investments.map((inv) {
      if (inv.codeName == oldCode) {
        return inv.copyWith(codeName: newCode);
      }
      return inv;
    }).toList();
    state = _investments;
  }

  @override
  Future<void> updateValuationBulk(String code, double price) async {
    _investments = _investments.map((inv) {
      if (inv.codeName == code) {
        return inv.copyWith(currentPrice: price);
      }
      return inv;
    }).toList();
    state = _investments;
  }
}

class FakeProfileIdNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

void main() {
  late MockStorageService mockStorage;

  setUp(() {
    mockStorage = MockStorageService();
  });

  Widget createTestWidget({
    Investment? investmentToEdit,
    required List<Investment> investments,
  }) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        investmentsProvider
            .overrideWith(() => MockInvestmentsNotifier(investments)),
        activeProfileIdProvider.overrideWith(() => FakeProfileIdNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => child!,
        home: const Scaffold(body: Text('Root')),
      ),
    );
  }

  Future<void> openAddScreen(
      WidgetTester tester, Investment? investmentToEdit) async {
    final BuildContext context = tester.element(find.text('Root'));
    Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) =>
            AddInvestmentScreen(investmentToEdit: investmentToEdit)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Investment: Bulk update all stock codes across entries when editing one item',
      (tester) async {
    final inv1 = Investment.create(
      name: 'Google',
      codeName: 'GOOG',
      type: InvestmentType.stock,
      acquisitionDate: DateTime(2022),
      acquisitionPrice: 100,
      quantity: 1,
      profileId: 'default',
    );
    final inv2 = Investment.create(
      name: 'Google Part 2',
      codeName: 'GOOG',
      type: InvestmentType.stock,
      acquisitionDate: DateTime(2023),
      acquisitionPrice: 120,
      quantity: 1,
      profileId: 'default',
    );

    await tester.pumpWidget(createTestWidget(
      investments: [inv1, inv2],
    ));
    await openAddScreen(tester, inv1);

    final codeField = find.widgetWithText(TextFormField, 'Ticker / Code Name');
    await tester.enterText(codeField, 'Alphabet');
    await tester.pumpAndSettle();

    final l10n =
        AppLocalizations.of(tester.element(find.byType(AddInvestmentScreen)))!;

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.check));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Dialog 1: Code Rename
    expect(find.text(l10n.bulkUpdateCodeTitle), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(TextButton, l10n.updateAllAction));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Dialog 2: Valuation Sync (if it appeared sequentially)
    if (find.text(l10n.bulkUpdateValuationTitle).evaluate().isNotEmpty) {
      await tester.runAsync(() async {
        await tester
            .tap(find.widgetWithText(TextButton, l10n.updateAllAction).last);
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }

    await tester.pumpAndSettle();

    expect(find.byType(AddInvestmentScreen), findsNothing);
    expect(find.text('Root'), findsOneWidget);
  });

  testWidgets(
      'Investment: Valuation sync dialog appears when price differs for same code',
      (tester) async {
    final inv1 = Investment.create(
      name: 'Apple',
      codeName: 'AAPL',
      type: InvestmentType.stock,
      acquisitionDate: DateTime(2022),
      acquisitionPrice: 150,
      currentPrice: 180,
      quantity: 1,
      profileId: 'default',
    );
    final inv2 = Investment.create(
      name: 'Apple Home',
      codeName: 'AAPL',
      type: InvestmentType.stock,
      acquisitionDate: DateTime(2023),
      acquisitionPrice: 160,
      currentPrice: 180,
      quantity: 1,
      profileId: 'default',
    );

    await tester.pumpWidget(createTestWidget(
      investments: [inv1, inv2],
    ));
    await openAddScreen(tester, inv1);

    final priceField = find.widgetWithText(TextFormField, 'Current Price');
    await tester.enterText(priceField, '190');
    await tester.pumpAndSettle();

    final l10n =
        AppLocalizations.of(tester.element(find.byType(AddInvestmentScreen)))!;

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.check));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text(l10n.bulkUpdateValuationTitle), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(TextButton, l10n.updateAllAction));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.byType(AddInvestmentScreen), findsNothing);
    expect(find.text('Root'), findsOneWidget);
  });
}
