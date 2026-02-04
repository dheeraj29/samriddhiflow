import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/recycle_bin_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/transaction.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockStorageService mockStorageService;

  setUp(() {
    mockStorageService = MockStorageService();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
      ],
      child: const MaterialApp(
        home: RecycleBinScreen(),
      ),
    );
  }

  testWidgets('RecycleBinScreen shows empty state', (tester) async {
    when(() => mockStorageService.getDeletedTransactions()).thenReturn([]);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Recycle Bin is empty'), findsOneWidget);
  });

  testWidgets('RecycleBinScreen restores transaction', (tester) async {
    final txn = Transaction.create(
      title: 'Deleted Item',
      amount: 100,
      type: TransactionType.expense,
      category: 'Misc',
      date: DateTime.now(),
    );

    // Initial load: 1 item. Subsequent (after SetState): 0 items to simulate removal from list
    int callCount = 0;
    when(() => mockStorageService.getDeletedTransactions()).thenAnswer((_) {
      if (callCount == 0) {
        callCount++;
        return [txn];
      }
      return [];
    });

    when(() => mockStorageService.restoreTransaction(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Deleted Item'), findsOneWidget);

    // Tap Restore
    await tester.tap(find.byTooltip('Restore'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.restoreTransaction(txn.id)).called(1);
    expect(find.text('Deleted Item'), findsNothing); // Should be gone
  });

  testWidgets('RecycleBinScreen deletes permanently', (tester) async {
    final txn = Transaction.create(
      title: 'Forever Delete',
      amount: 50,
      type: TransactionType.expense,
      category: 'Misc',
      date: DateTime.now(),
    );

    int callCount = 0;
    when(() => mockStorageService.getDeletedTransactions()).thenAnswer((_) {
      if (callCount == 0) {
        callCount++;
        return [txn];
      }
      return [];
    });

    when(() => mockStorageService.permanentlyDeleteTransaction(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Forever Delete'), findsOneWidget);

    // Tap Delete Forever
    await tester.tap(find.byTooltip('Delete Permanently'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.permanentlyDeleteTransaction(txn.id))
        .called(1);
    expect(find.text('Forever Delete'), findsNothing);
  });
}
