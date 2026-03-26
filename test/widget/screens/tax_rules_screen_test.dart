import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/screens/taxes/tax_rules_screen.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockTaxConfigService mockConfig;
  late MockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValue(TaxRules());
  });

  setUp(() {
    mockConfig = MockTaxConfigService();
    mockStorage = MockStorageService();

    final defaultRules = TaxRules();
    when(() => mockConfig.getRulesForYear(any())).thenReturn(defaultRules);
    when(() => mockConfig.getCurrentFinancialYear()).thenReturn(2025);
    when(() => mockConfig.saveRulesForYear(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockStorage.getAllTransactions()).thenReturn([]);
    when(() => mockStorage.getCategories()).thenReturn([]);
    when(() => mockConfig.init()).thenAnswer((_) async {});
  });

  Widget createTaxRulesScreen() {
    return ProviderScope(
      overrides: [
        taxConfigServiceProvider.overrideWithValue(mockConfig),
        storageServiceProvider.overrideWithValue(mockStorage),
      ],
      child: const MaterialApp(
        home: TaxRulesScreen(),
      ),
    );
  }

  testWidgets('TaxRulesScreen renders and allows tab switching',
      (WidgetTester tester) async {
    await tester.pumpWidget(createTaxRulesScreen());
    await tester.pumpAndSettle();

    expect(find.text('Tax Configuration'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);

    // Switch to Salary tab
    await tester.tap(find.text('Salary'));
    await tester.pumpAndSettle();
    expect(find.text('Standard Deduction (Salary)'), findsOneWidget);

    // Switch to Business tab
    await tester.tap(find.text('Business'));
    await tester.pumpAndSettle();
    expect(find.text('Presumptive Income'), findsOneWidget);
  });

  testWidgets('Updating General settings and saving',
      (WidgetTester tester) async {
    await tester.pumpWidget(createTaxRulesScreen());
    await tester.pumpAndSettle();

    final rebateSwitch = find.byType(SwitchListTile).first;
    await tester.tap(rebateSwitch);
    await tester.pumpAndSettle();

    await tester.tap(find.byWidgetPredicate((widget) {
      return widget is Icon && widget.icon == Icons.save && widget.size == 24;
    }));
    await tester.pumpAndSettle();

    verify(() => mockConfig.saveRulesForYear(2025, any())).called(1);
    expect(find.text('Tax Rules Saved Successfully'), findsOneWidget);
  });

  testWidgets('Restore defaults confirmation', (WidgetTester tester) async {
    when(() => mockConfig.deleteRulesForYear(any())).thenAnswer((_) async {});

    await tester.pumpWidget(createTaxRulesScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.restore));
    await tester.pumpAndSettle();

    expect(find.text('Restore System Defaults?'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    verify(() => mockConfig.deleteRulesForYear(2025)).called(1);
  });

  testWidgets('Copy from previous year', (WidgetTester tester) async {
    await tester.pumpWidget(createTaxRulesScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy_all));
    await tester.pumpAndSettle();

    expect(find.textContaining('Values copied from previous year'),
        findsOneWidget);
    verify(() => mockConfig.getRulesForYear(2024)).called(1);
  });

  testWidgets('Year change warns about unsaved changes and can be cancelled',
      (WidgetTester tester) async {
    await tester.pumpWidget(createTaxRulesScreen());
    await tester.pumpAndSettle();

    final jurisdictionDropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>).first);
    jurisdictionDropdown.onChanged?.call('Custom');
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Country Name'), 'UAE');
    await tester.pumpAndSettle();

    clearInteractions(mockConfig);

    final yearDropdownFinder = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(DropdownButton<int>),
    );
    final yearDropdown =
        tester.widget<DropdownButton<int>>(yearDropdownFinder.first);
    yearDropdown.onChanged?.call(2024);
    await tester.pumpAndSettle();

    expect(find.text('Unsaved Changes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved Changes'), findsNothing);
    verifyNever(() => mockConfig.getRulesForYear(2024));
  });

  testWidgets('Selecting custom jurisdiction reveals country field',
      (WidgetTester tester) async {
    await tester.pumpWidget(createTaxRulesScreen());
    await tester.pumpAndSettle();

    final jurisdictionDropdown = find.byType(DropdownButton<String>).first;
    await tester.tap(jurisdictionDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Country Name'), findsOneWidget);
  });
}
