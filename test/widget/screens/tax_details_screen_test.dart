import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/screens/taxes/tax_details_screen.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';

class MockIndianTaxService extends Mock implements IndianTaxService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockStorageService extends Mock implements StorageService {}

class MockThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

class MockCategoriesNotifier extends CategoriesNotifier {
  @override
  List<Category> build() => [];
}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_IN';
}

class MockCurrencyFormatNotifier extends CurrencyFormatNotifier {
  @override
  bool build() => false;
}

void main() {
  late MockIndianTaxService mockTaxService;
  late MockTaxConfigService mockConfig;
  late MockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValue(const TaxYearData(year: 2025));
    registerFallbackValue(TaxRules(slabs: []));
  });

  Future<void> pumpScreen(WidgetTester tester, TaxYearData data,
      {Function(TaxYearData)? onSave, VoidCallback? onDelete}) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        indianTaxServiceProvider.overrideWithValue(mockTaxService),
        taxConfigServiceProvider.overrideWithValue(mockConfig),
        storageServiceProvider.overrideWithValue(mockStorage),
        themeModeProvider.overrideWith(() => MockThemeModeNotifier()),
        loansProvider.overrideWith((ref) => Stream.value([])),
        categoriesProvider.overrideWith(() => MockCategoriesNotifier()),
        currencyProvider.overrideWith(() => MockCurrencyNotifier()),
        currencyFormatProvider.overrideWith(() => MockCurrencyFormatNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: TaxDetailsScreen(
          data: data,
          onSave: onSave ?? (d) {},
          onDelete: onDelete,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> switchTab(WidgetTester tester, String label) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  setUp(() {
    mockTaxService = MockIndianTaxService();
    mockConfig = MockTaxConfigService();
    mockStorage = MockStorageService();

    // Default mocks for all methods called in TaxDetailsScreen build/init
    when(() => mockTaxService.calculateLiability(any())).thenReturn(0.0);
    when(() => mockTaxService.calculateSalaryGross(any(), any()))
        .thenReturn(0.0);
    when(() => mockTaxService.calculateSalaryExemptions(any(), any()))
        .thenReturn(0.0);
    when(() => mockTaxService.calculateSalaryOnlyLiability(any()))
        .thenReturn(0.0);
    when(() => mockTaxService.calculateHousePropertyIncome(any(), any()))
        .thenReturn(0.0);
    when(() => mockTaxService.calculateBusinessIncome(any(), any()))
        .thenReturn(0.0);
    when(() => mockTaxService.calculateOtherSources(any(), any()))
        .thenReturn(0.0);
    when(() => mockTaxService.calculateMonthlySalaryBreakdown(any(), any()))
        .thenReturn(<int, Map<String, double>>{});

    when(() => mockTaxService.calculateDetailedLiability(any(), any(),
        salaryIncomeOverride: any(named: 'salaryIncomeOverride'),
        includeGeneratedTds: any(named: 'includeGeneratedTds'))).thenReturn({
      'totalTax': 0.0,
      'grossIncome': 0.0,
      'tds': 0.0,
      'netTaxPayable': 0.0,
      'baseForAdvanceTax': 0.0,
    });
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);
    when(() => mockStorage.getTaxYearData(any())).thenReturn(null);
  });

  testWidgets('TaxDetailsScreen shows generated TDS as read-only (Lock icon)',
      (tester) async {
    final rules = TaxRules(
      slabs: const [TaxSlab(300000, 0)],
      isCessEnabled: true,
      enableAdvanceTaxInterest: true,
    );

    final generatedEntry = TaxPaymentEntry(
      id: 'gen_1',
      amount: 5000,
      date: DateTime(2025, 4, 30),
      source: 'Employer (Salary TDS)',
      isManualEntry: false,
    );

    final manualEntry = TaxPaymentEntry(
      id: 'man_1',
      amount: 1000,
      date: DateTime(2025, 5, 15),
      source: 'Manual TDS',
      isManualEntry: true,
    );

    final data = TaxYearData(
      year: 2025,
      tdsEntries: [manualEntry],
    );

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([generatedEntry]);

    await pumpScreen(tester, data);

    // Switch to Tax Paid tab
    await switchTab(tester, 'Tax Paid');

    expect(find.textContaining('Employer (Salary TDS)'), findsOneWidget);
    expect(find.textContaining('Manual TDS'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('TaxDetailsScreen hides tax hints when advance tax is disabled',
      (tester) async {
    final rules = TaxRules(
      slabs: const [TaxSlab(300000, 0)],
      isCessEnabled: true,
      enableAdvanceTaxInterest: false, // DISABLED
    );

    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // Switch to Tax Paid tab
    await switchTab(tester, 'Tax Paid');

    expect(find.textContaining('Installment'), findsNothing);
  });

  testWidgets('Salary Tab: Can add and edit salary structures', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // 1. Initial state: No structure
    expect(
        find.textContaining('No salary structure defined for this period.',
            skipOffstage: false),
        findsOneWidget);

    // 2. Add Structure
    await tester.tap(find.text('Add Structure'));
    await tester.pumpAndSettle();

    expect(find.text('Add Salary Structure'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Annual Basic Pay (CTC)'),
        '600000'); // Annual Basic (50k monthly)
    await tester.enterText(
        find.widgetWithText(TextField, 'Annual Fixed Allowances (CTC)'),
        '240000'); // Annual Fixed (20k monthly)
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Save'),
    ));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('No salary structure defined.',
            skipOffstage: false),
        findsNothing);
    expect(find.textContaining('Basic:', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('Allowances', skipOffstage: false),
        findsAtLeast(1));

    // 3. Edit structure
    await tester.tap(find.widgetWithIcon(IconButton, Icons.edit).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Salary Structure'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Annual Basic Pay (CTC)'), '720000');
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Save'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Basic:', skipOffstage: false), findsOneWidget);
  });

  testWidgets('General: Filter by Date Range works', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // Initial state: Calendar icon should be calendar_today
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(find.byIcon(Icons.event_busy), findsNothing);

    // Tap to open range picker
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();

    // The DateRangePicker should be visible, tap Save without selecting to close
    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });

  testWidgets('General: Save button triggers onSave callback', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);
    bool saveCalled = false;

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data, onSave: (d) => saveCalled = true);

    // Tap Save icon in AppBar (or FAB area)
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    expect(saveCalled, isTrue);
    expect(
        find.textContaining('Tax details saved successfully.'), findsOneWidget);
  });

  testWidgets('General: Clear Tax Data dialog and deletion flow',
      (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);
    bool deleteCalled = false;

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data, onDelete: () => deleteCalled = true);

    // Tap Delete icon in AppBar
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Clear ALL Data for FY 2025?'), findsOneWidget);

    // Test Cancel
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(deleteCalled, isFalse);

    // Test Action
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DELETE ALL'));
    await tester.pumpAndSettle();

    expect(deleteCalled, isTrue);
  });

  testWidgets('General: Unsaved changes warning on back press', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // 1. Make a change (Edit Salary Structure)
    await tester.tap(find.text('Add Structure'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '50000');
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Save'),
    ));
    await tester.pumpAndSettle();

    // 2. Try to pop
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    // Expect warning dialog
    expect(find.text('Unsaved Changes'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    // Dialog should be gone
    expect(find.text('Unsaved Changes'), findsNothing);
  });

  testWidgets('Salary Tab: Copy previous year shows message when empty',
      (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);
    when(() => mockStorage.getTaxYearData(2024)).thenReturn(null);

    await pumpScreen(tester, data);

    await tester.tap(find.byTooltip('Copy from Previous Year'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No salary data found for the previous year.'),
        findsOneWidget);
  });

  testWidgets('House Property Tab: Can add a property', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // 1. Switch to House Prop tab
    await switchTab(tester, 'House Property');

    expect(
        find.textContaining('No house properties found for this year.',
            skipOffstage: false),
        findsOneWidget);

    // 2. Add Property
    await tester.tap(find.textContaining('Add Property'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Home 1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Home 1'), findsOneWidget);
  });

  testWidgets('House Property Tab: Can copy previous year properties',
      (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);
    const previousYearData = TaxYearData(
      year: 2024,
      houseProperties: [
        HouseProperty(name: 'Old House', isSelfOccupied: true),
      ],
    );

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);
    when(() => mockStorage.getTaxYearData(2024)).thenReturn(previousYearData);

    await pumpScreen(tester, data);
    await switchTab(tester, 'House Property');

    await tester.tap(find.byTooltip('Copy from Previous Year'));
    await tester.pumpAndSettle();

    expect(find.text('Old House'), findsOneWidget);
    expect(find.textContaining('1 house properties copied.'), findsOneWidget);
  });

  testWidgets('Business Tab: Can add a business entity', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // 1. Switch to Business tab
    await switchTab(tester, 'Business');

    expect(find.textContaining('No business income found for this year.'),
        findsOneWidget);

    // 2. Add Entry
    await tester.tap(find.textContaining('Add Business'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Shop 1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Shop 1'), findsOneWidget);
  });

  testWidgets('Capital Gains Tab: Can add an entry', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // 1. Switch to Cap Gains tab
    await switchTab(tester, 'Capital Gains');

    expect(
        find.textContaining('No capital gains found for this year.',
            skipOffstage: false),
        findsOneWidget);

    // 2. Add Entry
    await tester.tap(find.textContaining('Add Entry'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Stock A');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Stock A'), findsOneWidget);
  });

  testWidgets('Dividend Tab: Can update quarterly breakdown', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // 1. Switch to Dividend tab
    await switchTab(tester, 'Dividend');

    // 2. Update Q1
    await tester.enterText(find.byType(TextField).at(0), '1000');
    await tester.tap(find.text('Update Total'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dividend income updated.'), findsOneWidget);
  });

  testWidgets('Agri Tab: Can update agri income history', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // 1. Switch to Agri tab
    await switchTab(tester, 'Agri');

    expect(find.textContaining('No agricultural income found for this year.'),
        findsOneWidget);

    // 2. Add history entry
    await tester.tap(find.textContaining('Add Entry'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Rice Harvest');
    await tester.enterText(find.byType(TextField).at(1), '50000');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Rice Harvest'), findsOneWidget);
  });

  testWidgets('Live Summary: Updates when income is added', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);
    when(() => mockTaxService.calculateDetailedLiability(any(), any(),
        salaryIncomeOverride: any(named: 'salaryIncomeOverride'),
        includeGeneratedTds: any(named: 'includeGeneratedTds'))).thenReturn({
      'totalTax': 5432.0,
      'grossIncome': 0.0,
    });

    await pumpScreen(tester, data);

    // Initial Est. Tax (should be mocked 5432)
    expect(find.textContaining('5,432'), findsWidgets);

    // 1. Add Business Income (which triggers _updateSummary)
    await switchTab(tester, 'Business');

    await tester.tap(find.textContaining('Add Business'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Shop 1');
    await tester.enterText(find.byType(TextField).at(2), '50000');
    when(() => mockTaxService.calculateDetailedLiability(any(), any(),
        salaryIncomeOverride: any(named: 'salaryIncomeOverride'),
        includeGeneratedTds: any(named: 'includeGeneratedTds'))).thenReturn({
      'totalTax': 5432.0,
      'grossIncome': 50000.0,
    });
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('50,000'), findsWidgets);
  });

  testWidgets('Other Income Tab: Can add an entry', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // 1. Switch to Other Income tab
    await switchTab(tester, 'Other');

    final emptyState =
        find.textContaining('No Other Income added.', skipOffstage: false);
    await tester.ensureVisible(emptyState);
    expect(emptyState, findsOneWidget);

    // 2. Add Entry
    final addBtn = find.widgetWithText(TextButton, 'Add Other Income',
        skipOffstage: false);
    await tester.ensureVisible(addBtn);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    final dialogOther = find.byType(AlertDialog);
    await tester.enterText(
        find
            .descendant(of: dialogOther, matching: find.byType(TextField))
            .at(0),
        'Freelance Work');
    await tester.enterText(
        find
            .descendant(of: dialogOther, matching: find.byType(TextField))
            .at(1),
        '15000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Freelance Work'), findsOneWidget);
  });

  testWidgets('Cash Gifts Tab: Can add an entry', (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // 1. Switch to Cash Gifts tab
    await switchTab(tester, 'Gifts');

    final emptyState = find.textContaining('No cash gifts found for this year.',
        skipOffstage: false);
    await tester.ensureVisible(emptyState);
    expect(emptyState, findsOneWidget);

    // 2. Add Entry
    final addBtn = find.textContaining('Add Gift', skipOffstage: false);
    await tester.ensureVisible(addBtn);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    final dialogGifts = find.byType(AlertDialog);
    await tester.enterText(
        find
            .descendant(of: dialogGifts, matching: find.byType(TextField))
            .at(0),
        'Birthday Gift');
    await tester.enterText(
        find
            .descendant(of: dialogGifts, matching: find.byType(TextField))
            .at(1),
        '5000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Birthday Gift'), findsOneWidget);
  });

  testWidgets('Tax Paid Tab: Can manually add TDS and Advance Tax',
      (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);

    await pumpScreen(tester, data);

    // 1. Switch to Tax Paid tab
    await switchTab(tester, 'Tax Paid');

    // 2. Add TDS Entry
    final tdsHeaderRow =
        find.ancestor(of: find.text('TDS'), matching: find.byType(Row)).first;
    await tester.tap(
        find.descendant(of: tdsHeaderRow, matching: find.byType(IconButton)));
    await tester.pumpAndSettle();

    final dialogTds = find.byType(AlertDialog);
    await tester.enterText(
        find.descendant(
            of: dialogTds,
            matching: find.widgetWithText(TextField, 'Source/Description')),
        'Bank Interest TDS');
    await tester.enterText(
        find.descendant(
            of: dialogTds,
            matching: find.widgetWithText(TextField, 'Gross Amount (₹)')),
        '500');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final tdsItem = find.text('Source: Bank Interest TDS', skipOffstage: false);
    await tester.ensureVisible(tdsItem);
    await tester.pumpAndSettle();
    expect(find.text('Source: Bank Interest TDS'), findsOneWidget);

    // 3. Add Advance Tax Entry
    final advanceTaxHeaderRow = find
        .ancestor(
            of: find.text('Advance Tax', skipOffstage: false),
            matching: find.byType(Row))
        .first;
    await tester.ensureVisible(advanceTaxHeaderRow);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
        of: advanceTaxHeaderRow, matching: find.byType(IconButton)));
    await tester.pumpAndSettle();

    final dialogAdv = find.byType(AlertDialog);
    await tester.enterText(
        find.descendant(
            of: dialogAdv,
            matching: find.widgetWithText(TextField, 'Source/Description')),
        'Q2 Installment');
    await tester.enterText(
        find.descendant(
            of: dialogAdv,
            matching: find.widgetWithText(TextField, 'Gross Amount (₹)')),
        '10000');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final advItem = find.text('Source: Q2 Installment', skipOffstage: false);
    await tester.ensureVisible(advItem);
    await tester.pumpAndSettle();
    expect(find.text('Source: Q2 Installment'), findsOneWidget);
  });

  testWidgets('Salary Tab: Shows monthly take-home breakdown estimate',
      (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);

    // Mock breakdown for current month
    final mockBreakdown = {
      DateTime.now().month: {
        'gross': 100000.0,
        'tax': 10000.0,
        'deductions': 5000.0,
        'takeHome': 85000.0,
      }
    };

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.calculateMonthlySalaryBreakdown(any(), any()))
        .thenReturn(mockBreakdown);

    await pumpScreen(tester, data);

    // Verify presence of breakdown UI
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pumpAndSettle();

    final detailedEstFinder =
        find.text('DETAILED EST. (CURRENT MONTH)', skipOffstage: false);
    await tester.ensureVisible(detailedEstFinder);
    await tester.pumpAndSettle();
    expect(detailedEstFinder, findsOneWidget);

    expect(find.text('NET MONTHLY', skipOffstage: false), findsOneWidget);

    // Verify values (using en_IN locale format ₹1,00,000.00 etc.)
    expect(find.textContaining('85,000', skipOffstage: false), findsWidgets);
    expect(find.textContaining('1,00,000', skipOffstage: false), findsWidgets);
  });

  testWidgets('Salary Tab: Copy previous year copies all components',
      (tester) async {
    final rules = TaxRules(slabs: const [TaxSlab(300000, 0)]);
    const data = TaxYearData(year: 2025);
    final previousYearData = TaxYearData(
      year: 2024,
      salary: SalaryDetails(
        history: [
          SalaryStructure(
            id: 'old_struct',
            effectiveDate: DateTime(2024, 4, 1),
            monthlyBasic: 50000,
          ),
        ],
        independentDeductions: [
          const CustomDeduction(
              id: 'old_ded', name: 'Old Deduction', amount: 1234),
        ],
        independentExemptions: [
          const CustomExemption(
              id: 'old_ex', name: 'Old Exemption', amount: 567),
        ],
        independentAllowances: [
          const CustomAllowance(
              id: 'old_all', name: 'Old Allowance', payoutAmount: 890),
        ],
        npsEmployer: 10000,
        leaveEncashment: 5000,
        gratuity: 15000,
      ),
    );

    when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);
    when(() => mockTaxService.getGeneratedSalaryTds(any(), any()))
        .thenReturn([]);
    when(() => mockStorage.getTaxYearData(2024)).thenReturn(previousYearData);

    await pumpScreen(tester, data);

    // Initial check: shouldn't have the data
    expect(find.textContaining('1,234'), findsNothing);

    // Trigger copy
    await tester.ensureVisible(find.byTooltip('Copy from Previous Year'));
    await tester.tap(find.byTooltip('Copy from Previous Year'));
    await tester.pumpAndSettle();

    // Verify history copied
    expect(find.textContaining('1 salary structures copied.'), findsOneWidget);

    // Scroll to check independent components
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pumpAndSettle();

    // Verify individual components
    expect(find.text('Old Deduction'), findsOneWidget);
    expect(find.textContaining('1,234'), findsWidgets);
    expect(find.text('Old Exemption'), findsOneWidget);
    expect(find.textContaining('567'), findsWidgets);
    expect(find.text('Old Allowance'), findsOneWidget);
    expect(find.textContaining('890'), findsWidgets);

    // Verify static values (Static figures section)
    await tester.ensureVisible(find.text('Employer NPS Contribution'));
    expect(find.text('Employer NPS Contribution'), findsOneWidget);

    // Find the TextField next to the label (usually the one containing the controller with the value 10000.0)
    expect(find.text('10000.0'), findsOneWidget);
    expect(find.text('5000.0'), findsOneWidget);
    expect(find.text('15000.0'), findsOneWidget);
  });
}
