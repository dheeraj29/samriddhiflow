import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/utils/currency_utils.dart';

void main() {
  group('CurrencyUtils Tests', () {
    test('getSymbol returns correct symbol for locales', () {
      expect(CurrencyUtils.getSymbol('en_IN'), '₹');
      expect(CurrencyUtils.getSymbol('en_US'), '\$');
      expect(CurrencyUtils.getSymbol('en_GB'), '£');
      expect(CurrencyUtils.getSymbol('en_EU'), '€');
    });

    test('getFormatter formats correctly', () {
      final formatter = CurrencyUtils.getFormatter('en_IN');
      expect(formatter.currencySymbol, '₹');

      // Can't easily test exact string output due to space inconsistencies (non-breaking vs normal) without normalizing,
      // but we can test basic properties.
    });

    test('roundTo2Decimals handles rounding', () {
      expect(CurrencyUtils.roundTo2Decimals(10.123), 10.12);
      expect(CurrencyUtils.roundTo2Decimals(10.126), 10.13);
      expect(CurrencyUtils.roundTo2Decimals(10.0), 10.0);
    });

    test('getSmartFormat shortens large numbers', () {
      // Indian Locale
      expect(CurrencyUtils.getSmartFormat(150000, 'en_IN'), '₹1.50L');
      expect(CurrencyUtils.getSmartFormat(15000000, 'en_IN'), '₹1.50Cr');
      expect(CurrencyUtils.getSmartFormat(1500, 'en_IN'), '₹1.50K');

      // International Locale
      expect(CurrencyUtils.getSmartFormat(1500000, 'en_US'), '\$1.50M');
      expect(CurrencyUtils.getSmartFormat(1500, 'en_US'), '\$1.50K');
    });

    test('getSmartFormat handles negatives', () {
      expect(CurrencyUtils.getSmartFormat(-1500, 'en_IN'), '₹-1.50K');
    });
  });
}
