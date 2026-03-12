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
import 'dart:io';

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

void main() {
  late MockStorageService mockStorage;
  late MockTaxConfigService mockConfig;
  late MockIndianTaxService mockIndianTax;
  late MockTaxDataFetcher mockFetcher;
  late Box<InsurancePolicy> policiesBox;

  setUpAll(() async {
    registerFallbackValue(const TaxYearData(year: 2024));
    registerFallbackValue(TaxRules());
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('hive_tax_dashboard');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(InsurancePolicyAdapter().typeId)) {
      Hive.registerAdapter(InsurancePolicyAdapter());
    }
    if (!Hive.isBoxOpen(StorageService.boxInsurancePolicies)) {
      await Hive.openBox<InsurancePolicy>(StorageService.boxInsurancePolicies);
    }
  });

  setUp(() async {
    mockStorage = MockStorageService();
    mockConfig = MockTaxConfigService();
    mockIndianTax = MockIndianTaxService();
    mockFetcher = MockTaxDataFetcher();
    policiesBox =
        Hive.box<InsurancePolicy>(StorageService.boxInsurancePolicies);
    await policiesBox.clear();

    when(() => mockConfig.init()).thenAnswer((_) async {});
    when(() => mockConfig.getCurrentFinancialYear()).thenReturn(2025);
    when(() => mockConfig.getRulesForYear(any())).thenReturn(TaxRules());
    when(() => mockStorage.getTaxYearData(any()))
        .thenReturn(const TaxYearData(year: 2025));
    when(() => mockStorage.getAllTaxYearData())
        .thenReturn([const TaxYearData(year: 2025)]);
    when(() => mockStorage.getInsurancePoliciesBox()).thenReturn(policiesBox);

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
}
