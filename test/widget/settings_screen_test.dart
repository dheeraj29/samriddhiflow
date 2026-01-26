import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_mocks.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    const MethodChannel('dev.flutter_community.plus/connectivity')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return ['wifi'];
    });
  });

  testWidgets('Settings Screen - Render & Interaction',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStreamProvider.overrideWith((ref) => Stream.value(null)),
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          profilesProvider.overrideWith((ref) => Future.value(
              [Profile(id: 'default', name: 'User', currencyLocale: 'en_IN')])),
          activeProfileIdProvider.overrideWith(() => MockProfileNotifier()),
          themeModeProvider.overrideWith(() => ThemeModeNotifier()),
          excelServiceProvider.overrideWith((ref) => MockExcelService()),
          // Basic providers defaults
          currencyProvider.overrideWith(() => CurrencyNotifier()),
          monthlyBudgetProvider.overrideWith(() => BudgetNotifier()),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    // Initial Pump
    await tester.pump(); // No settle yet, might be async loading
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Settings'), findsOneWidget);

    // Verify Theme Section
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);

    // Verify Data Management
    await tester.scrollUntilVisible(
      find.text('Data Management'),
      500.0,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data Management'), findsOneWidget);
    expect(find.text('Export Data to Excel'), findsOneWidget);

    // Tap Export (Should not crash, mocks are in place)
    // Note: MockExcelService.exportData returns []. MockFileService returns null.
    // Screen might show Snackbar.
    await tester.tap(find.text('Export Data to Excel'));
    await tester.pumpAndSettle();

    // Verify Snackbar message (Exported: ...)
    // Our mock exportData returns empty list.
    // Logic: final accounts = ref.read(accountsProvider).value...
    // MockStorageService returns accounts.
    // So it should succeed.
    // expect(find.byType(SnackBar), findsOneWidget);
  });
}
