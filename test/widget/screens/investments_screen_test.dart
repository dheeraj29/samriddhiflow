import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:samriddhi_flow/models/investment.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/investments_screen.dart';
import 'package:samriddhi_flow/screens/add_investment_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/widgets/pagination_bar.dart';

class MockStorageService extends Mock implements StorageService {}

class MockInvestmentsNotifier extends InvestmentsNotifier {
  final List<Investment> _investments;
  MockInvestmentsNotifier(this._investments);

  @override
  List<Investment> build() => _investments;

  @override
  Future<void> saveInvestment(Investment inv) async {}
  @override
  Future<void> deleteInvestment(String id) async {}
}

class FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_IN';
}

void main() {
  late MockStorageService mockStorage;

  setUp(() {
    mockStorage = MockStorageService();
    when(() => mockStorage.getInvestments()).thenReturn([]);
  });

  Widget createTestWidget({List<Investment> investments = const []}) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        investmentsProvider
            .overrideWith(() => MockInvestmentsNotifier(investments)),
        currencyProvider.overrideWith(() => FakeCurrencyNotifier()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: InvestmentsScreen(),
      ),
    );
  }

  testWidgets('InvestmentsScreen renders tabs', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Dashboard tab has Add Investment button', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(ElevatedButton, 'Add Investment');
    expect(addButton, findsAtLeastNWidgets(1));

    await tester.tap(addButton.first);
    await tester.pumpAndSettle();

    expect(find.byType(AddInvestmentScreen), findsOneWidget);
  });

  testWidgets('Management tab has Add Investment button', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Switch to Manage tab
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(ElevatedButton, 'Add Investment');
    expect(addButton, findsAtLeastNWidgets(1));

    await tester.tap(addButton.first);
    await tester.pumpAndSettle();

    expect(find.byType(AddInvestmentScreen), findsOneWidget);
  });

  testWidgets('InvestmentsScreen filtering, search and pagination UI',
      (tester) async {
    // Generate 16 investments to trigger pagination (page size 15)
    final invs = List.generate(
        16,
        (i) => Investment.create(
              name: 'Inv $i',
              type: InvestmentType.stock,
              acquisitionDate: DateTime.now(),
              acquisitionPrice: 100,
              quantity: 1,
              profileId: 'default',
            ));

    await tester.pumpWidget(createTestWidget(investments: invs));
    await tester.pumpAndSettle();

    // Switch to Manage tab
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();

    // Check search and filter
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.sort), findsOneWidget);

    // Check Original label
    expect(find.text('Original: '), findsAtLeastNWidgets(1));

    // Check PaginationBar is present
    expect(find.byType(PaginationBar), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
  });

  testWidgets('InvestmentsScreen shows pagination even with a single item',
      (tester) async {
    final inv = Investment.create(
      name: 'Single Inv',
      type: InvestmentType.stock,
      acquisitionDate: DateTime.now(),
      acquisitionPrice: 100,
      quantity: 1,
      profileId: 'default',
    );

    await tester.pumpWidget(createTestWidget(investments: [inv]));
    await tester.pumpAndSettle();

    // Switch to Manage tab
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();

    // Check PaginationBar is present even if there is only 1 page
    expect(find.byType(PaginationBar), findsOneWidget);
    expect(find.text('Page 1 of 1'), findsOneWidget);
  });
  testWidgets('Dashboard displays type breakdown and Gain%', (tester) async {
    final stock = Investment.create(
      name: 'Apple',
      type: InvestmentType.stock,
      acquisitionDate: DateTime.now(),
      acquisitionPrice: 100,
      quantity: 1,
      currentPrice: 150, // 50% gain
      profileId: 'default',
    );

    await tester.pumpWidget(createTestWidget(investments: [stock]));
    await tester.pumpAndSettle();

    expect(find.text('Stocks'), findsAtLeastNWidgets(1));

    // Verify Gain% is displayed (regex handles potential symbols or spaces)
    // It appears twice: once in the overall summary card and once in the type breakdown row
    expect(find.textContaining(RegExp(r'\+50\.0%')), findsNWidgets(2));
    // Use a simpler check for absolute gain value
    expect(find.textContaining('50'), findsAtLeastNWidgets(1));
  });

  testWidgets('InvestmentsScreen hides LT badge for threshold 0',
      (tester) async {
    final inv = Investment.create(
      name: 'Disabled LT',
      type: InvestmentType.stock,
      acquisitionDate: DateTime.now().subtract(const Duration(days: 100)),
      acquisitionPrice: 100,
      quantity: 1,
      customLongTermThresholdYears: 0, // DISABLED
      profileId: 'default',
    );

    await tester.pumpWidget(createTestWidget(investments: [inv]));
    await tester.pumpAndSettle();

    // Switch to Manage tab
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();

    // Check Long Term In... badge is NOT present
    expect(find.textContaining('Long Term In'), findsNothing);

    // Switch to Dashboard tab
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    // Check Ready to Sell LT alert is NOT present
    expect(find.textContaining('Ready to Sell (LT)'), findsNothing);
  });
}
