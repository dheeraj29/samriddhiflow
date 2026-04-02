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

  testWidgets('InvestmentsScreen renders tabs and FAB', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('FAB navigates to AddInvestmentScreen', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(AddInvestmentScreen), findsOneWidget);
    expect(find.text('Add Investment'), findsOneWidget);
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

  testWidgets('Dashboard displays type breakdown', (tester) async {
    final stock = Investment.create(
      name: 'Apple',
      type: InvestmentType.stock,
      acquisitionDate: DateTime.now(),
      acquisitionPrice: 100,
      quantity: 1,
      profileId: 'default',
    );

    await tester.pumpWidget(createTestWidget(investments: [stock]));
    await tester.pumpAndSettle();

    expect(find.text('Stocks'), findsAtLeastNWidgets(1));
  });
}
