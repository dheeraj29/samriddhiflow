import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/screens/taxes/insurance_portfolio_screen.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/taxes/insurance_tax_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockInsuranceTaxService extends Mock implements InsuranceTaxService {}

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
  late Box<InsurancePolicy> policiesBox;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('hive_insurance_tests');
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
    mockInsuranceTax = MockInsuranceTaxService();
    policiesBox =
        Hive.box<InsurancePolicy>(StorageService.boxInsurancePolicies);
    await policiesBox.clear();

    when(() => mockStorage.getInsurancePoliciesBox()).thenReturn(policiesBox);
    when(() => mockConfig.getRulesForYear(any())).thenReturn(TaxRules());
    when(() => mockInsuranceTax.optimizeMaturityTax(any())).thenReturn([]);
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
        home: InsurancePortfolioScreen(),
      ),
    );
  }

  testWidgets('InsurancePortfolioScreen renders tabs and summary',
      (WidgetTester tester) async {
    await tester.pumpWidget(createInsurancePortfolioScreen());
    await tester.pumpAndSettle();

    expect(find.text('Insurance Portfolio'), findsOneWidget);
    expect(find.text('Policies List'), findsOneWidget);
    expect(find.text('Tax Rules'), findsOneWidget);
    expect(find.text('Tax Optimization'), findsOneWidget);
  });

  testWidgets('Add Policy dialog opening', (WidgetTester tester) async {
    await tester.pumpWidget(createInsurancePortfolioScreen());
    await tester.pumpAndSettle();

    final addButton = find.byTooltip('Add Policy');
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Add Policy'), findsOneWidget);
    expect(find.text('Policy Name'), findsOneWidget);
    expect(find.text('Annual Premium (₹)'), findsOneWidget);
  });

  testWidgets('Tax Rules tab interactions', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createInsurancePortfolioScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tax Rules'));
    await tester.pumpAndSettle();

    final aggregateSwitch = find.widgetWithText(
      SwitchListTile,
      'Enable Aggregate Premium Limits',
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

    await tester.tap(find.byTooltip('Sync & Recalculate Status'));
    await tester.pumpAndSettle();

    verify(() => mockInsuranceTax.optimizeMaturityTax(any())).called(1);
    expect(find.text('Tax status recalculated and saved.'), findsOneWidget);
  });
}
