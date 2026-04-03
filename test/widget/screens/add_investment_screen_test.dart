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
  MockInvestmentsNotifier();
  @override
  List<Investment> build() => [];
  @override
  Future<void> saveInvestment(Investment inv) async {}
}

class FakeProfileIdNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

void main() {
  late MockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValue(Investment.create(
      name: 'Fallback',
      type: InvestmentType.stock,
      acquisitionDate: DateTime.now(),
      acquisitionPrice: 0,
      quantity: 0,
    ));
  });

  setUp(() {
    mockStorage = MockStorageService();
  });

  Widget createTestWidget({Investment? investmentToEdit}) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        investmentsProvider.overrideWith(() => MockInvestmentsNotifier()),
        activeProfileIdProvider.overrideWith(() => FakeProfileIdNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: AddInvestmentScreen(investmentToEdit: investmentToEdit),
      ),
    );
  }

  testWidgets('AddInvestmentScreen renders basic form fields', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Add Investment'), findsOneWidget);
    expect(find.text('Investment Name'), findsWidgets);
    expect(find.text('Acquisition Price'), findsWidgets);
    expect(find.text('Current Price'), findsWidgets);
    expect(find.text('Quantity'), findsWidgets);
    expect(find.text('LT Threshold (Years)'), findsWidgets);
  });

  testWidgets('Ticker and Quantity fields visibility based on type',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Ticker / Code Name'), findsOneWidget);
    expect(find.text('Quantity'), findsWidgets);

    // Switch to Fixed Savings
    await tester.tap(find.text('Fixed Savings (FD/RD)'));
    await tester.pumpAndSettle();

    expect(find.text('Ticker / Code Name'), findsNothing);
    expect(find.text('Quantity'), findsNothing);
    expect(find.text('Interest Rate (%)'), findsOneWidget);

    // Switch to PF
    await tester.tap(find.text('PF / EPF / VPF'));
    await tester.pumpAndSettle();

    expect(find.text('Ticker / Code Name'), findsNothing);
    expect(find.text('Quantity'), findsNothing);
    expect(find.text('Interest Rate (%)'), findsOneWidget);
  });

  testWidgets('Pre-fills data when editing an investment', (tester) async {
    final inv = Investment.create(
      name: 'Existing Apple',
      codeName: 'AAPL_EXT',
      type: InvestmentType.stock,
      acquisitionDate: DateTime(2023, 1, 1),
      acquisitionPrice: 150.0,
      quantity: 10,
      currentPrice: 175.0,
      customLongTermThresholdYears: 5,
      profileId: 'default',
    );

    await tester.pumpWidget(createTestWidget(investmentToEdit: inv));
    await tester.pumpAndSettle();

    expect(find.text('Edit Investment'), findsOneWidget);
    expect(find.text('Existing Apple'), findsOneWidget);
    expect(find.text('AAPL_EXT'), findsOneWidget);
    expect(find.text('150.0'), findsOneWidget);
    expect(find.text('175.0'), findsOneWidget);
    expect(find.text('10.0'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('Recurring Investment fields visibility and toggle',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final listView = find.byType(ListView);
    await tester.drag(listView, const Offset(0, -1000));
    await tester.pumpAndSettle();

    // Verify some text from the recurring section is visible
    expect(find.textContaining('Recurring'), findsWidgets);

    // Toggle recurring on using the first available switch in the view
    final switches = find.byType(Switch);
    expect(switches, findsWidgets);
    await tester.tap(switches.first);
    await tester.pumpAndSettle();

    // Check if configuration fields appear
    expect(find.textContaining('Amount'), findsWidgets);
    expect(find.textContaining('Date'), findsWidgets);
  });
}
