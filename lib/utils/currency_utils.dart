import 'package:intl/intl.dart';

class CurrencyUtils {
  static NumberFormat getFormatter(String? locale, {bool compact = false}) {
    // Force specific symbols to ensure offline/font compatibility
    String? symbol;
    if (locale == 'en_IN') {
      symbol = '₹';
    } else if (locale == 'en_US') {
      symbol = '\$';
    } else if (locale == 'en_GB') {
      symbol = '£';
    } else if (locale == 'en_EU') {
      symbol = '€';
    }

    try {
      if (compact) {
        return NumberFormat.compactCurrency(locale: locale, symbol: symbol);
      }
      return NumberFormat.currency(locale: locale, symbol: symbol);
    } catch (_) {
      // Fallback
      return NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    }
  }

  static String getSymbol(String? locale) {
    if (locale == 'en_IN') return '₹';
    if (locale == 'en_US') return '\$';
    if (locale == 'en_GB') return '£';
    if (locale == 'en_EU') return '€';
    return getFormatter(locale).currencySymbol;
  }

  static String getSmartFormat(double value, String locale) {
    if (value.isNaN || value.isInfinite) return "0";
    final absValue = value.abs();
    final sign = value < 0 ? '-' : '';
    final symbol = getSymbol(locale);

    if (locale == 'en_IN' || locale == 'INR') {
      // Indian Numbering System (Lakhs, Crores)
      if (absValue >= 10000000) {
        // Crores
        return '$symbol$sign${(absValue / 10000000).toStringAsFixed(absValue % 10000000 == 0 ? 0 : 2)}Cr';
      } else if (absValue >= 100000) {
        // Lakhs
        return '$symbol$sign${(absValue / 100000).toStringAsFixed(absValue % 100000 == 0 ? 0 : 2)}L';
      } else if (absValue >= 1000) {
        // K
        return '$symbol$sign${(absValue / 1000).toStringAsFixed(absValue % 1000 == 0 ? 0 : 2)}K';
      }
    } else {
      // International System (Million, Billion)
      if (absValue >= 1000000000) {
        return '$symbol$sign${(absValue / 1000000000).toStringAsFixed(absValue % 1000000000 == 0 ? 0 : 2)}B';
      } else if (absValue >= 1000000) {
        return '$symbol$sign${(absValue / 1000000).toStringAsFixed(absValue % 1000000 == 0 ? 0 : 2)}M';
      } else if (absValue >= 1000) {
        return '$symbol$sign${(absValue / 1000).toStringAsFixed(absValue % 1000 == 0 ? 0 : 2)}K';
      }
    }

    // Default formatting if under 1000
    return getFormatter(locale).format(value);
  }

  static double roundTo2Decimals(double value) {
    if (value.isInfinite || value.isNaN) return 0.0;
    return (value * 100).roundToDouble() / 100;
  }

  static String formatCurrency(double value, String locale) {
    return getFormatter(locale).format(value);
  }
}
