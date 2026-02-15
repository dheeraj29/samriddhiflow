import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/utils/currency_utils.dart';

void main() {
  group('CurrencyUtils Tests', () {
    test('getSymbol returns correct symbol for locales', () {
      expect(CurrencyUtils.getSymbol('en_IN'), '₹');
      expect(CurrencyUtils.getSymbol('en_US'), '\$');
      expect(CurrencyUtils.getSymbol('en_GB'), '£');
      expect(CurrencyUtils.getSymbol('en_EU'), '€');
      // Fallback via getFormatter (catch block)
      expect(CurrencyUtils.getSymbol('unknown'), '₹');
    });

    test('getFormatter formats correctly', () {
      final formatter = CurrencyUtils.getFormatter('en_IN');
      expect(formatter.currencySymbol, '₹');

      final compactFormatter =
          CurrencyUtils.getFormatter('en_US', compact: true);
      expect(compactFormatter.format(1000000), '\$1M');
    });

    test('roundTo2Decimals handles rounding', () {
      expect(CurrencyUtils.roundTo2Decimals(10.123), 10.12);
      expect(CurrencyUtils.roundTo2Decimals(10.126), 10.13);
      expect(CurrencyUtils.roundTo2Decimals(10.0), 10.0);
    });

    test('getSmartFormat shortens large numbers', () {
      // Indian Locale
      expect(CurrencyUtils.getSmartFormat(150000, 'en_IN'), '₹1.50L');
      expect(CurrencyUtils.getSmartFormat(100000, 'en_IN'), '₹1L');
      expect(CurrencyUtils.getSmartFormat(15000000, 'en_IN'), '₹1.50Cr');
      expect(CurrencyUtils.getSmartFormat(10000000, 'en_IN'), '₹1Cr');
      expect(CurrencyUtils.getSmartFormat(1500, 'en_IN'), '₹1.50K');
      expect(CurrencyUtils.getSmartFormat(1000, 'en_IN'), '₹1K');

      // International Locale
      expect(CurrencyUtils.getSmartFormat(1500000, 'en_US'), '\$1.50M');
      expect(CurrencyUtils.getSmartFormat(1000000, 'en_US'), '\$1M');
      expect(CurrencyUtils.getSmartFormat(1500000000, 'en_US'), '\$1.50B');
      expect(CurrencyUtils.getSmartFormat(1000000000, 'en_US'), '\$1B');
      expect(CurrencyUtils.getSmartFormat(1500, 'en_US'), '\$1.50K');
      expect(CurrencyUtils.getSmartFormat(1000, 'en_US'), '\$1K');

      // Values under 1000
      expect(CurrencyUtils.getSmartFormat(500, 'en_US'), '\$500.00');
    });

    test('getSmartFormat handles negatives and edge cases', () {
      expect(CurrencyUtils.getSmartFormat(-1500, 'en_IN'), '₹-1.50K');
      expect(CurrencyUtils.getSmartFormat(double.nan, 'en_IN'), '0');
      expect(CurrencyUtils.getSmartFormat(double.infinity, 'en_IN'), '0');
    });

    test('formatCurrency uses default Indian locale', () {
      expect(CurrencyUtils.formatCurrency(1000, 'en_IN'), contains('1,000'));
      expect(CurrencyUtils.formatCurrency(1000, 'en_IN'), contains('₹'));
    });
  });
}
