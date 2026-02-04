import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/providers/sum_tracker_provider.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/widgets/global_overlay.dart';
import 'package:samriddhi_flow/widgets/quick_sum_tracker.dart';

// Mocks
// Use Mocktail for StorageService
class LocalMockStorageService extends Mock implements StorageService {}

class MockSumTrackerNotifier extends SumTrackerNotifier {
  @override
  SumTrackerState build() =>
      SumTrackerState(profiles: [], activeProfileId: null);
}

class MockCalculatorVisibleNotifier extends CalculatorVisibleNotifier {
  @override
  bool build() => false;

  void setVisible(bool v) => state = v;
}

class MockIsLoggedInNotifier extends IsLoggedInNotifier {
  @override
  bool build() => true;
}

class MockLogoutRequestedNotifier extends LogoutRequestedNotifier {
  @override
  bool build() => false;

  void setLogout(bool v) => state = v;
}

void main() {
  final mockStorage = LocalMockStorageService();

  setUp(() {
    // Stub necessary methods for CurrencyNotifier
    when(() => mockStorage.getCurrencyLocale()).thenReturn('en_US');
  });

  testWidgets('GlobalOverlay renders and handles logic', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        calculatorVisibleProvider
            .overrideWith(MockCalculatorVisibleNotifier.new),
        isLoggedInProvider.overrideWith(MockIsLoggedInNotifier.new),
        logoutRequestedProvider.overrideWith(MockLogoutRequestedNotifier.new),
        sumTrackerProvider.overrideWith(MockSumTrackerNotifier.new),

        // Mock Storage Service to support Real CurrencyNotifier
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ],
      child: const MaterialApp(
        home: GlobalOverlay(
          child: Text('Main Content'),
        ),
      ),
    ));

    await tester.pump();
    expect(find.text('Main Content'), findsOneWidget);

    final element = tester.element(find.byType(GlobalOverlay));
    final container = ProviderScope.containerOf(element);

    // 1. Test Logout Log Logic
    (container.read(logoutRequestedProvider.notifier)
            as MockLogoutRequestedNotifier)
        .setLogout(true);
    await tester.pump();
    (container.read(logoutRequestedProvider.notifier)
            as MockLogoutRequestedNotifier)
        .setLogout(false);
    await tester.pump();

    // 2. Test Show Calculator
    (container.read(calculatorVisibleProvider.notifier)
            as MockCalculatorVisibleNotifier)
        .setVisible(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(QuickSumTracker), findsOneWidget);

    // Hide it
    (container.read(calculatorVisibleProvider.notifier)
            as MockCalculatorVisibleNotifier)
        .setVisible(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(QuickSumTracker), findsNothing);
  });
}
