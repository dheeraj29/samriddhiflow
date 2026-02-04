import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/widgets/category_manager_dialog.dart';
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
}
