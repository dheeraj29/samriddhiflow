import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/add_loan_screen.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/services/loan_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockLoanService extends Mock implements LoanService {}

class MockStorageService extends Mock implements StorageService {}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

class FakeLoan extends Fake implements Loan {}

// Mock Profile Notifier
class MockProfileNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

void main() {
  late MockLoanService mockLoanService;
  late MockStorageService mockStorageService;

  setUpAll(() {
    registerFallbackValue(FakeLoan());
    registerFallbackValue(Loan.create(
        name: 't',
        principal: 1,
        rate: 1,
        tenureMonths: 1,
        startDate: DateTime.now(),
        emiAmount: 1,
        emiDay: 1,
        firstEmiDate: DateTime.now()));
  });

  setUp(() {
    mockLoanService = MockLoanService();
    mockStorageService = MockStorageService();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        loanServiceProvider.overrideWithValue(mockLoanService),
        storageServiceProvider.overrideWithValue(mockStorageService),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        accountsProvider.overrideWith((ref) => Stream.value([])),
        activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
      ],
      child: const MaterialApp(
        home: AddLoanScreen(),
      ),
    );
  }

  testWidgets('AddLoanScreen checks required fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final createButton = find.widgetWithText(ElevatedButton, 'Create Loan');
    if (createButton.evaluate().isEmpty) {
      debugPrint('Create Loan button NOT found. Tree dump:');
      // debugDumpApp();
    }

    // Check if loading
    if (find.byType(LinearProgressIndicator).evaluate().isNotEmpty) {
      debugPrint('Found LinearProgressIndicator - Accounts Loading?');
    }

    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget); // Name
    expect(find.text('Invalid'), findsWidgets); // Principal, Rate

    addTearDown(() => tester.view.resetPhysicalSize());
  });

  testWidgets('AddLoanScreen calculates EMI and creates loan', (tester) async {
    when(() => mockLoanService.calculateEMI(
        principal: any(named: 'principal'),
        annualRate: any(named: 'annualRate'),
        tenureMonths: any(named: 'tenureMonths'))).thenReturn(212.47);

    when(() => mockStorageService.saveLoan(any())).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Fill Name
    await tester.enterText(
        find.ancestor(
            of: find.text('Loan Name'), matching: find.byType(TextFormField)),
        'New Car');

    // Fill Principal
    await tester.enterText(
        find.ancestor(
            of: find.text('Principal Amount'),
            matching: find.byType(TextFormField)),
        '10000');

    // Fill Rate
    await tester.enterText(
        find.ancestor(
            of: find.text('Interest Rate (Annual)'),
            matching: find.byType(TextFormField)),
        '10');

    // Fill Tenure
    await tester.enterText(
        find.ancestor(
            of: find.text('Tenure (Months)'),
            matching: find.byType(TextFormField)),
        '60');
    await tester.pumpAndSettle(); // Trigger calculation

    // Verify EMI Calculation UI Update
    verify(() => mockLoanService.calculateEMI(
        principal: 10000, annualRate: 10, tenureMonths: 60)).called(1);
    expect(find.text('212.47'), findsOneWidget); // Calculated EMI Field

    // Create
    final createButton = find.widgetWithText(ElevatedButton, 'Create Loan');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    verify(() => mockStorageService.saveLoan(
            any(that: isA<Loan>().having((l) => l.name, 'name', 'New Car'))))
        .called(1);
  });

  testWidgets(
      'AddLoanScreen - Interest Type and Date Selection trigger updates',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. Change Loan Type
    await tester.tap(find.text('PERSONAL'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('HOME').last);
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsWidgets);

    // 2. Change EMI Date
    final emiDateText = find.text('1st EMI Date');
    await tester.dragUntilVisible(
        emiDateText, find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(emiDateText, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });
}
