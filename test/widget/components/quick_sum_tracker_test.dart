import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/providers/sum_tracker_provider.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/widgets/quick_sum_tracker.dart';
import 'package:samriddhi_flow/navigator_key.dart';

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

  @override
  Future<void> addProfile(String name) {
    return super.noSuchMethod(
      Invocation.method(#addProfile, [name]),
    );
  }

  @override
  Future<void> deleteProfile(String id) {
    return super.noSuchMethod(
      Invocation.method(#deleteProfile, [id]),
    );
  }

  @override
  Future<void> activateProfile(String id) {
    return super.noSuchMethod(
      Invocation.method(#activateProfile, [id]),
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
    when(() => mockSumTracker.addProfile(any())).thenAnswer((_) async {});
  });

  testWidgets('QuickSumTracker renders and handles input', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sumTrackerProvider.overrideWith(() => mockSumTracker),
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(
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

  testWidgets('QuickSumTracker handles operations and profile management',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sumTrackerProvider.overrideWith(() => mockSumTracker),
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ],
      child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Stack(children: [QuickSumTracker()]))),
    ));
    await tester.pumpAndSettle();

    // Expand
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // 1. Operations (*2)
    // Value field is the SECOND TextField (Name is first)
    await tester.enterText(find.byType(TextField).at(1), '*2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    verify(() => mockSumTracker.addValue(2.0,
        name: any(named: 'name'), operation: '*')).called(1);

    // 2. Profile Manager
    // Need to trigger _showProfileManager. Logic requires width > 150.
    // In test environment, screen size allows it.
    await tester.tap(find.byIcon(Icons
        .switch_account)); // PureIcons.switchAccount uses Icons.switch_account
    await tester.pumpAndSettle();

    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text('Create New Profile'), findsOneWidget);

    // 3. Add Profile
    await tester.tap(find.text('Create New Profile'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Profile Name'), 'New Pro');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    verify(() => mockSumTracker.addProfile('New Pro')).called(1);
  });
}
