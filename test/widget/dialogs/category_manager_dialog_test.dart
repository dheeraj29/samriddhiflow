import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/widgets/category_manager_dialog.dart';
import 'package:samriddhi_flow/models/category.dart';
import '../test_mocks.dart';

void main() {
  late MockStorageService mockStorage;

  setUp(() {
    mockStorage = MockStorageService();
    setupStorageDefaults(mockStorage);
  });

  testWidgets('CategoryManagerDialog renders and allows adding',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          categoriesProvider.overrideWith(() => MockCategoriesNotifier()),
        ],
        child: const MaterialApp(
          home: CategoryManagerDialog(),
        ),
      ),
    );

    expect(find.text('Manage Categories'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);

    // Add new
    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.pump();
    expect(find.text('Groceries'), findsOneWidget);

    when(() => mockStorage.addCategory(any())).thenAnswer((_) async {});

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Category'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.addCategory(any())).called(1);
  });

  testWidgets('Custom Only filter hides default categories', (tester) async {
    tester.view.physicalSize = const Size(2400, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Setup: Food is a default, MyCustomCat is custom
    when(() => mockStorage.getDefaultCategoryNames()).thenReturn({'food'});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          categoriesProvider.overrideWith(() => MockCategoriesNotifier([
                Category(
                    id: 'cat1',
                    name: 'Food',
                    usage: CategoryUsage.expense,
                    iconCode: 57564,
                    tag: CategoryTag.none),
                Category(
                    id: 'cat3',
                    name: 'MyCustomCat',
                    usage: CategoryUsage.expense,
                    iconCode: 57566,
                    tag: CategoryTag.none),
              ])),
        ],
        child: const MaterialApp(
          home: CategoryManagerDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both categories visible by default
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('MyCustomCat'), findsOneWidget);

    // Tap "Custom Only" filter
    await tester.tap(find.text('Custom Only'));
    await tester.pumpAndSettle();

    // Default category hidden, custom remains
    expect(find.text('Food'), findsNothing);
    expect(find.text('MyCustomCat'), findsOneWidget);

    // Tap "All" to restore
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('MyCustomCat'), findsOneWidget);
  });
}
