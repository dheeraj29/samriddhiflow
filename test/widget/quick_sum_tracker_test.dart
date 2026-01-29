import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/providers/sum_tracker_provider.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/widgets/quick_sum_tracker.dart';

// Mocks
class LocalMockStorageService extends Mock implements StorageService {}

class MockSumTrackerNotifier extends SumTrackerNotifier with Mock {
  @override
  SumTrackerState build() {
    return SumTrackerState(
      profiles: [
        SumProfile(id: '1', name: 'Test Profile', entries: []),
      ],
      activeProfileId: '1',
    );
  }

  @override
  Future<void> addValue(double value, {String? name, String operation = '+'}) {
    return super.noSuchMethod(
      Invocation.method(
          #addValue, [value], {#name: name, #operation: operation}),
    );
  }

  @override
  Future<void> clearValues() {
    return super.noSuchMethod(
      Invocation.method(#clearValues, []),
    );
  }
}

void main() {
  final mockStorage = LocalMockStorageService();
  late MockSumTrackerNotifier mockSumTracker;

  setUp(() {
    mockSumTracker = MockSumTrackerNotifier();

    when(() => mockStorage.getCurrencyLocale()).thenReturn('en_US');

    // Stub Notifier Methods
    when(() => mockSumTracker.addValue(any(),
        name: any(named: 'name'),
        operation: any(named: 'operation'))).thenAnswer((_) async {});
    when(() => mockSumTracker.clearValues()).thenAnswer((_) async {});
  });

  testWidgets('QuickSumTracker renders and handles input', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sumTrackerProvider.overrideWith(() => mockSumTracker),
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              QuickSumTracker(),
            ],
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // 1. Initial State (Collapsed)
    expect(find.byType(QuickSumTracker), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // 2. Expanded State
    expect(find.text('Test Profile'), findsOneWidget);

    // 3. Add Value
    await tester.enterText(
        find.widgetWithText(TextField, 'Value (e.g., 5 or *2)'), '100');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(() => mockSumTracker.addValue(100.0,
        name: any(named: 'name'), operation: '+')).called(1);

    // 4. Clear History
    await tester.tap(find.text('Clear History'));
    await tester.pump();
    verify(() => mockSumTracker.clearValues()).called(1);
  });
}
