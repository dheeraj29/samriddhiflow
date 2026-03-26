import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/screens/taxes/tax_dashboard_screen.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_data_fetcher.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_IN';
  @override
  Future<void> setCurrency(String locale) async {}
}

class MockStorageService extends Mock implements StorageService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockIndianTaxService extends Mock implements IndianTaxService {}

class MockTaxDataFetcher extends Mock implements TaxDataFetcher {}

class MockBox<T> extends Mock implements Box<T> {}

void main() {
  late MockStorageService mockStorage;
  late MockTaxConfigService mockConfig;
  late MockIndianTaxService mockIndianTax;
  late MockTaxDataFetcher mockFetcher;
  late MockBox<InsurancePolicy> policiesBox;
  late ValueNotifier<Box<InsurancePolicy>> policiesListenable;

  setUpAll(() async {
    registerFallbackValue(const TaxYearData(year: 2024));
    registerFallbackValue(InsurancePolicy.create(
      name: 'test',
      number: '123',
      premium: 0,
      sumAssured: 0,
      start: DateTime.now(),
      maturity: DateTime.now(),
    ));
    registerFallbackValue(TaxRules());
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    mockStorage = MockStorageService();
    mockConfig = MockTaxConfigService();
    mockIndianTax = MockIndianTaxService();
    mockFetcher = MockTaxDataFetcher();
    policiesBox = MockBox<InsurancePolicy>();
    policiesListenable = ValueNotifier<Box<InsurancePolicy>>(policiesBox);

    when(() => mockConfig.init()).thenAnswer((_) async {});
    when(() => mockConfig.getCurrentFinancialYear()).thenReturn(2025);
    when(() => mockConfig.getRulesForYear(any())).thenReturn(TaxRules());
    when(() => mockStorage.getTaxYearData(any()))
        .thenReturn(const TaxYearData(year: 2025));
    when(() => mockStorage.getAllTaxYearData())
        .thenReturn([const TaxYearData(year: 2025)]);

    when(() => mockStorage.getInsurancePoliciesBox()).thenReturn(policiesBox);
    when(() => mockStorage.getInsurancePolicies()).thenReturn([]);
    when(() => mockStorage.getInsurancePoliciesListenable())
        .thenReturn(policiesListenable);
    when(() => policiesBox.toMap()).thenReturn({});
    when(() => policiesBox.values).thenReturn([]);

    when(() => mockIndianTax.calculateDetailedLiability(any(), any()))
        .thenReturn({
      'totalTax': 50000.0,
      'grossIncome': 1000000.0,
      'capitalGainsTotal': 0.0,
      'totalDeductions': 0.0,
      'taxableIncome': 0.0,
      'slabTax': 0.0,
      'specialTax': 0.0,
      'cess': 0.0,
      'advanceTax': 0.0,
      'tds': 0.0,
      'tcs': 0.0,
      'advanceTaxInterest': 0.0,
      'netTaxPayable': 10000.0,
      'nextAdvanceTaxDueDate': DateTime.now().add(const Duration(days: 5)),
      'nextAdvanceTaxAmount': 15000.0,
      'daysUntilAdvanceTax': 5,
    });
    when(() => mockIndianTax.suggestITR(any())).thenReturn('ITR-1');
  });

  Widget createTaxDashboardScreen() {
    return ProviderScope(
      overrides: [
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        taxYearDataProvider.overrideWith(
            (ref, year) => Stream.value(mockStorage.getTaxYearData(year))),
        allTaxYearDataProvider.overrideWith(
            (ref) => Stream.value(mockStorage.getAllTaxYearData())),
        insurancePoliciesProvider.overrideWith(
            (ref) => Stream.value(mockStorage.getInsurancePolicies())),
        storageServiceProvider.overrideWithValue(mockStorage),
        taxConfigServiceProvider.overrideWithValue(mockConfig),
        indianTaxServiceProvider.overrideWithValue(mockIndianTax),
        taxDataFetcherProvider.overrideWithValue(mockFetcher),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
      ],
      child: const MaterialApp(
        home: TaxDashboardScreen(),
      ),
    );
  }

  testWidgets('TaxDashboardScreen renders summary and reminders',
      (WidgetTester tester) async {
    await tester.pumpWidget(createTaxDashboardScreen());
    await tester.pumpAndSettle();

    expect(find.text('Tax Dashboard'), findsOneWidget);
    expect(find.text('Projected Tax Liability'), findsOneWidget);
    expect(find.textContaining('Suggested: ITR-1'), findsOneWidget);

    // Check reminder card
    expect(find.text('Action Required: Advance Tax'), findsOneWidget);
    expect(find.textContaining('5 d left'), findsOneWidget);
  });

  testWidgets('Year selection changes data', (WidgetTester tester) async {
    await tester.pumpWidget(createTaxDashboardScreen());
    await tester.pumpAndSettle();

    final dropdown = find.byType(DropdownButton<int>).first;
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('FY 2024-2025').last);
    await tester.pumpAndSettle();

    verify(() => mockStorage.getTaxYearData(2024)).called(1);
  });

  testWidgets('Sync button opens sync dialog', (WidgetTester tester) async {
    await tester.pumpWidget(createTaxDashboardScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sync Data'));
    await tester.pumpAndSettle();

    expect(find.text('Sync Tax Data'), findsOneWidget);
    expect(find.text('Smart Sync (Recommended)'), findsOneWidget);
  });

  testWidgets('Insurance button navigates to Insurance Portfolio',
      (WidgetTester tester) async {
    await tester.pumpWidget(createTaxDashboardScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.health_and_safety));
    await tester.pumpAndSettle();

    expect(find.text('Insurance Portfolio'), findsOneWidget);
  });

  testWidgets('InsuranceTaxDisclaimer shows when taxable policy exists',
      (WidgetTester tester) async {
    final policy = InsurancePolicy.create(
      name: 'Taxable Policy',
      number: 'T1',
      premium: 10000,
      sumAssured: 100000,
      start: DateTime(2020, 1, 1),
      maturity: DateTime(2025, 6, 1), // Maturity in FY 2025-26
      isTaxExempt: false,
    );
    when(() => mockStorage.getInsurancePolicies()).thenReturn([policy]);
    when(() => mockConfig.getCurrentFinancialYear()).thenReturn(2025);

    await tester.pumpWidget(createTaxDashboardScreen());
    await tester.pumpAndSettle();

    expect(find.text('Taxable Insurance Alert'), findsOneWidget);
    expect(find.textContaining('taxable in FY 2025-2026'), findsOneWidget);
  });

  testWidgets('InsuranceTaxDisclaimer appears when income NOT added for year',
      (WidgetTester tester) async {
    final policy = InsurancePolicy(
      id: 'p1',
      policyName: 'Taxable Policy',
      policyNumber: '123',
      annualPremium: 10000,
      sumAssured: 100000,
      startDate: DateTime(2020, 1, 1),
      maturityDate: DateTime(2027, 3, 31),
      isTaxExempt: false,
      isInstallmentEnabled: true,
      installmentStartDate: DateTime(2025, 5, 1),
      isIncomeAddedByYear: {2025: false},
    );

    when(() => mockStorage.getInsurancePolicies()).thenReturn([policy]);
    when(() => mockStorage.getTaxYearData(any()))
        .thenReturn(const TaxYearData(year: 2025));
    when(() => mockStorage.getAllTaxYearData()).thenReturn([]);

    await tester.pumpWidget(createTaxDashboardScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('Taxable Insurance Alert'), findsOneWidget);
  });

  testWidgets('InsuranceTaxDisclaimer disappears when income IS added for year',
      (WidgetTester tester) async {
    final policy = InsurancePolicy(
      id: 'p1',
      policyName: 'Taxable Policy',
      policyNumber: '123',
      annualPremium: 10000,
      sumAssured: 100000,
      startDate: DateTime(2020, 1, 1),
      maturityDate: DateTime(2027, 3, 31),
      isTaxExempt: false,
      isInstallmentEnabled: true,
      installmentStartDate: DateTime(2025, 5, 1),
      isIncomeAddedByYear: {2025: true},
    );

    when(() => mockStorage.getInsurancePolicies()).thenReturn([policy]);
    when(() => mockStorage.getTaxYearData(any()))
        .thenReturn(const TaxYearData(year: 2025));
    when(() => mockStorage.getAllTaxYearData()).thenReturn([]);

    await tester.pumpWidget(createTaxDashboardScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('Taxable Insurance Alert'), findsNothing);
  });

  testWidgets('Advance tax reminder shows overdue state',
      (WidgetTester tester) async {
    when(() => mockIndianTax.calculateDetailedLiability(any(), any()))
        .thenReturn({
      'totalTax': 50000.0,
      'grossIncome': 1000000.0,
      'capitalGainsTotal': 0.0,
      'totalDeductions': 0.0,
      'taxableIncome': 0.0,
      'slabTax': 0.0,
      'specialTax': 0.0,
      'cess': 0.0,
      'advanceTax': 0.0,
      'tds': 0.0,
      'tcs': 0.0,
      'advanceTaxInterest': 0.0,
      'netTaxPayable': 10000.0,
      'nextAdvanceTaxDueDate': DateTime.now().subtract(const Duration(days: 3)),
      'nextAdvanceTaxAmount': 15000.0,
      'daysUntilAdvanceTax': -3,
    });

    await tester.pumpWidget(createTaxDashboardScreen());
    await tester.pumpAndSettle();

    expect(find.text('Advance Tax Overdue!'), findsOneWidget);
    expect(find.text('3d Late'), findsOneWidget);
  });

  testWidgets('Advance tax reminder shows due today badge',
      (WidgetTester tester) async {
    when(() => mockIndianTax.calculateDetailedLiability(any(), any()))
        .thenReturn({
      'totalTax': 50000.0,
      'grossIncome': 1000000.0,
      'capitalGainsTotal': 0.0,
      'totalDeductions': 0.0,
      'taxableIncome': 0.0,
      'slabTax': 0.0,
      'specialTax': 0.0,
      'cess': 0.0,
      'advanceTax': 0.0,
      'tds': 0.0,
      'tcs': 0.0,
      'advanceTaxInterest': 0.0,
      'netTaxPayable': 10000.0,
      'nextAdvanceTaxDueDate': DateTime.now(),
      'nextAdvanceTaxAmount': 15000.0,
      'daysUntilAdvanceTax': 0,
    });

    await tester.pumpWidget(createTaxDashboardScreen());
    await tester.pumpAndSettle();

    expect(find.text('Action Required: Advance Tax'), findsOneWidget);
    expect(find.text('Due Today'), findsOneWidget);
  });
}
