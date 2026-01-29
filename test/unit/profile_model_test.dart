import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/profile.dart';

void main() {
  group('Profile Model Tests', () {
    test('Profile.create defaults', () {
      final profile = Profile.create(name: 'Test User');
      expect(profile.name, 'Test User');
      expect(profile.currencyLocale, 'en_IN');
      expect(profile.monthlyBudget, 0.0);
      expect(profile.id, isNotEmpty);
    });

    test('Profile.create overrides', () {
      final profile = Profile.create(
        name: 'User 2',
        currencyLocale: 'en_US',
        monthlyBudget: 5000.0,
      );
      expect(profile.name, 'User 2');
      expect(profile.currencyLocale, 'en_US');
      expect(profile.monthlyBudget, 5000.0);
    });
  });
}
