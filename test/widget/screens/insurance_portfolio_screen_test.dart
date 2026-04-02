import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:samriddhi_flow/screens/taxes/insurance_portfolio_screen.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/taxes/insurance_tax_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockInsuranceTaxService extends Mock implements InsuranceTaxService {}

class MockBox<T> extends Mock implements Box<T> {}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_IN';
  @override
  Future<void> setCurrency(String locale) async {}
}

void main() {
  late MockStorageService mockStorage;
  late MockTaxConfigService mockConfig;
  late MockInsuranceTaxService mockInsuranceTax;
  late MockBox<InsurancePolicy> policiesBox;
  late ValueNotifier<Box<InsurancePolicy>> policiesListenable;

  setUpAll(() async {
    registerFallbackValue(InsurancePolicy.create(
      name: 'test',
      number: '123',
      premium: 0,
      sumAssured: 0,
      start: DateTime.now(),
      maturity: DateTime.now(),
    ));
    registerFallbackValue(const TaxYearData(year: 2024));
    registerFallbackValue(TaxRules());
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    mockStorage = MockStorageService();
    mockConfig = MockTaxConfigService();
    mockInsuranceTax = MockInsuranceTaxService();
    policiesBox = MockBox<InsurancePolicy>();
    policiesListenable = ValueNotifier<Box<InsurancePolicy>>(policiesBox);

    when(() => mockStorage.getInsurancePoliciesBox()).thenReturn(policiesBox);
    when(() => mockStorage.getInsurancePolicies()).thenReturn([]);
    when(() => mockStorage.getInsurancePoliciesListenable())
        .thenReturn(policiesListenable);
    when(() => policiesBox.toMap()).thenReturn({});
    when(() => policiesBox.values).thenReturn([]);

    when(() => mockConfig.getRulesForYear(any())).thenReturn(TaxRules());
    when(() => mockInsuranceTax.optimizeMaturityTax(any())).thenReturn([]);
    when(() => mockInsuranceTax.isApplicableForYear(any(), any()))
        .thenReturn(true);
    when(() => mockInsuranceTax.calculateInsuranceSummaryData(any(), any()))
        .thenReturn(InsuranceSummaryData(
      totalPremium: 0,
      currentTaxableGain: 0,
      futureTaxableGain: 0,
      taxableUlipTotal: 0,
      taxableNonUlipTotal: 0,
      hasPendingCalculations: false,
    ));
    when(() => mockInsuranceTax.getEventDateForYear(any(), any()))
        .thenReturn(DateTime(2030, 1, 1));
    when(() => mockInsuranceTax.calculateTaxableIncomeSplit(any())).thenReturn({
      'saleConsideration': 100000,
      'costOfAcquisition': 80000,
      'taxableGain': 20000,
      'totalGain': 20000,
    });

    // Support saving
    when(() => mockStorage.getTaxYearData(any())).thenReturn(null);
    when(() => mockStorage.saveTaxYearData(any())).thenAnswer((_) async {});
    when(() => policiesBox.put(any(), any())).thenAnswer((_) async {});
  });

  Widget createInsurancePortfolioScreen() {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        taxConfigServiceProvider.overrideWithValue(mockConfig),
        insuranceTaxServiceProvider.overrideWithValue(mockInsuranceTax),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: InsurancePortfolioScreen(),
      ),
    );
  }

  testWidgets('InsurancePortfolioScreen renders tabs and summary',
      (WidgetTester tester) async {
    await tester.pumpWidget(createInsurancePortfolioScreen());
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('Insurance Portfolio'), findsOneWidget);
    expect(find.text('Policies'), findsOneWidget);
    expect(find.text('Tax Rules'), findsOneWidget);
  });

  testWidgets('Add Policy dialog opening', (WidgetTester tester) async {
    await tester.pumpWidget(createInsurancePortfolioScreen());
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final addButton = find.byTooltip('Add Insurance Policy');
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Add Insurance Policy'), findsOneWidget);
    expect(find.text('Policy Name'), findsOneWidget);
    expect(find.textContaining('Annual Premium'), findsOneWidget);

    // New installment fields
    expect(find.text('Enable Installment?'), findsOneWidget);
  });

  testWidgets('Populate Income dialog works', (WidgetTester tester) async {
    final policy = InsurancePolicy.create(
      name: 'Taxable Policy',
      number: 'T1',
      premium: 10000,
      sumAssured: 100000,
      start: DateTime(2020, 1, 1),
      maturity: DateTime(2030, 1, 1),
      isTaxExempt: false,
    );
    when(() => policiesBox.toMap()).thenReturn({'key1': policy});
    when(() => policiesBox.values).thenReturn([policy]);
    when(() => mockStorage.getInsurancePolicies()).thenReturn([policy]);

    await tester.pumpWidget(createInsurancePortfolioScreen());
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    // Find the populate income button (icon: Icons.add_chart)
    final populateButton = find.byTooltip('Populate Taxable Income');
    expect(populateButton, findsOneWidget);
    await tester.ensureVisible(populateButton);
    await tester.tap(populateButton);
    await tester.pumpAndSettle();

    expect(find.text('Populate Taxable Income'), findsOneWidget);
    expect(find.text('Tax Year'), findsOneWidget);
    expect(find.text('Tax Head'), findsOneWidget);

    // Click Add to Dashboard
    final addButton = find.text('Add to Dashboard');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final captured = verify(() => mockStorage.saveTaxYearData(captureAny()))
        .captured
        .last as TaxYearData;
    expect(captured.otherIncomes.last.transactionDate, DateTime(2030, 1, 1));
  });

  testWidgets('Tax Rules tab interactions', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createInsurancePortfolioScreen());
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final taxRulesTab = find.byType(Tab).at(1);
    await tester.tap(taxRulesTab);
    await tester.pumpAndSettle();

    final aggregateSwitch = find.widgetWithText(
      SwitchListTile,
      'Enable Aggregate Limits',
    );
    expect(aggregateSwitch, findsWidgets);
    final aggregateSwitch0 = aggregateSwitch.at(0);

    // Toggle a switch
    await tester.tap(aggregateSwitch0);
    await tester.pumpAndSettle();

    expect(find.text('Save Rules'), findsOneWidget);
  });

  testWidgets('Recalculate tax button trigger', (WidgetTester tester) async {
    await tester.pumpWidget(createInsurancePortfolioScreen());
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Recalculate Tax Status'));
    await tester.pumpAndSettle();

    verify(() => mockInsuranceTax.optimizeMaturityTax(any())).called(1);
    expect(
        find.text('Tax status for all policies recalculated.'), findsOneWidget);
  });
}
