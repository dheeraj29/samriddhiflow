import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/settings_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/models/profile.dart';

class MockStorageService extends Mock implements StorageService {}

class MockAuthService extends Mock implements AuthService {}

class MockThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;
  @override
  Future<void> setThemeMode(ThemeMode mode) async => state = mode;
}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
  @override
  Future<void> setCurrency(String locale) async => state = locale;
}

class MockProfileIdNotifier extends ProfileNotifier {
  @override
  String build() => '1';
  @override
  Future<void> setProfile(String id) async => state = id;
}

class MockSmartCalcNotifier extends SmartCalculatorEnabledNotifier {
  @override
  bool build() => false;
  @override
  Future<void> toggle() async => state = !state;
}

class MockIsOfflineNotifier extends IsOfflineNotifier {
  @override
  bool build() => false;
}

class MockBudgetNotifier extends BudgetNotifier {
  @override
  double build() => 1000.0;
}

class MockBackupThresholdNotifier extends BackupThresholdNotifier {
  @override
  int build() => 10;
}

void main() {
  late MockStorageService mockStorageService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockStorageService = MockStorageService();
    mockAuthService = MockAuthService();

    when(() => mockStorageService.isAppLockEnabled()).thenReturn(false);
    when(() => mockStorageService.getAppPin()).thenReturn(null);
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        authServiceProvider.overrideWithValue(mockAuthService),
        authStreamProvider.overrideWith((ref) => Stream.value(null)),
        themeModeProvider.overrideWith(MockThemeModeNotifier.new),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        profilesProvider
            .overrideWith((ref) async => [Profile(id: '1', name: 'Default')]),
        activeProfileIdProvider.overrideWith(MockProfileIdNotifier.new),
        smartCalculatorEnabledProvider.overrideWith(MockSmartCalcNotifier.new),
        isOfflineProvider.overrideWith(MockIsOfflineNotifier.new),
        monthlyBudgetProvider.overrideWith(MockBudgetNotifier.new),
        backupThresholdProvider.overrideWith(MockBackupThresholdNotifier.new),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen renders sections', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Cloud & Sync'), findsOneWidget);
    expect(find.text('Data Management'), findsOneWidget);
    expect(find.text('Profile Management'), findsOneWidget);
  });

  testWidgets('SettingsScreen changes theme', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final themeDropdown = find.byType(DropdownButton<ThemeMode>);
    await tester.tap(themeDropdown);
    await tester.pumpAndSettle();

    final darkItem = find.text('Dark').last;
    await tester.tap(darkItem);
    await tester.pumpAndSettle();

    expect(find.text('DARK'), findsOneWidget);
  });

  testWidgets('SettingsScreen toggles App Lock (shows dialog)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Find App Lock Switch
    final lockSwitch = find.ancestor(
      of: find.text('App Lock (PIN)'),
      matching: find.byType(SwitchListTile),
    );

    await tester.tap(lockSwitch);
    await tester.pumpAndSettle();

    expect(find.text('Set App PIN'), findsOneWidget);
  });
}
