import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/profile.dart';

class MockHive extends Mock implements HiveInterface {}

class MockBox extends Mock implements Box {}

class MockAccountBox extends Mock implements Box<Account> {}

class MockProfileBox extends Mock implements Box<Profile> {}

class ProfileFake extends Fake implements Profile {}

void main() {
  late StorageService storageService;
  late MockHive mockHive;
  late MockBox mockSettingsBox;
  late MockProfileBox mockProfileBox;

  setUpAll(() {
    registerFallbackValue(ProfileFake());
  });

  setUp(() {
    mockHive = MockHive();
    mockSettingsBox = MockBox();
    mockProfileBox = MockProfileBox();

    when(() => mockHive.box<Profile>(any())).thenReturn(mockProfileBox);
    when(() => mockHive.box(any())).thenReturn(mockSettingsBox);

    storageService = StorageService(mockHive);

    // Default mock for profile ID
    when(() => mockSettingsBox.get('activeProfileId',
        defaultValue: any(named: 'defaultValue'))).thenReturn('default');
  });

  group('StorageService - Profile Operations', () {
    test('getActiveProfileId returns value from hive', () {
      when(() => mockSettingsBox.get('activeProfileId',
          defaultValue: any(named: 'defaultValue'))).thenReturn('p1');
      expect(storageService.getActiveProfileId(), 'p1');
    });

    test('setActiveProfileId sets value in Hive', () async {
      when(() => mockSettingsBox.put('activeProfileId', 'p1'))
          .thenAnswer((_) async {});
      await storageService.setActiveProfileId('p1');
      verify(() => mockSettingsBox.put('activeProfileId', 'p1')).called(1);
    });
  });

  group('StorageService - Settings', () {
    test('getCurrencyLocale returns profile value', () {
      final p =
          Profile(id: 'default', name: 'Default', currencyLocale: 'en_US');
      when(() => mockProfileBox.get('default')).thenReturn(p);

      expect(storageService.getCurrencyLocale(), 'en_US');
    });

    test('setCurrencyLocale updates profile in Hive', () async {
      final p = Profile(id: 'default', name: 'Default');
      when(() => mockProfileBox.get('default')).thenReturn(p);
      when(() => mockProfileBox.put('default', any())).thenAnswer((_) async {});

      await storageService.setCurrencyLocale('hi_IN');

      verify(() => mockProfileBox.put('default', any())).called(1);
    });

    test('getMonthlyBudget returns profile value', () {
      final p = Profile(id: 'default', name: 'Default', monthlyBudget: 50000.0);
      when(() => mockProfileBox.get('default')).thenReturn(p);

      expect(storageService.getMonthlyBudget(), 50000.0);
    });
  });

  group('StorageService - Auth', () {
    test('getAuthFlag returns value from settings', () {
      when(() => mockSettingsBox.get('isLoggedIn',
          defaultValue: any(named: 'defaultValue'))).thenReturn(true);
      expect(storageService.getAuthFlag(), true);
    });

    test('setAuthFlag updates Hive', () async {
      when(() => mockSettingsBox.put('isLoggedIn', true))
          .thenAnswer((_) async {});
      await storageService.setAuthFlag(true);
      verify(() => mockSettingsBox.put('isLoggedIn', true)).called(1);
    });
  });

  group('StorageService - Holidays', () {
    test('getHolidays returns list', () {
      final holidays = [DateTime(2025, 1, 1)];
      when(() => mockSettingsBox.get('holidays',
          defaultValue: any(named: 'defaultValue'))).thenReturn(holidays);
      // StorageService returns a mapped list, so we check equality
      expect(storageService.getHolidays(), holidays);
    });
  });
}
