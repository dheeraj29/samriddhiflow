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

    final compact = (locale == 'en_IN' || locale == 'INR')
        ? _formatIndianSystem(absValue, sign, symbol)
        : _formatInternationalSystem(absValue, sign, symbol);

    return compact ?? getFormatter(locale).format(value);
  }

  static String? _formatIndianSystem(
      double absValue, String sign, String symbol) {
    return _formatSystem(
        absValue, sign, symbol, [10000000, 100000, 1000], ['Cr', 'L', 'K']);
  }

  static String? _formatInternationalSystem(
      double absValue, String sign, String symbol) {
    return _formatSystem(
        absValue, sign, symbol, [1000000000, 1000000, 1000], ['B', 'M', 'K']);
  }

  static String? _formatSystem(double absValue, String sign, String symbol,
      List<double> thresholds, List<String> suffixes) {
    for (int i = 0; i < thresholds.length; i++) {
      if (absValue >= thresholds[i]) {
        return '$symbol$sign${(absValue / thresholds[i]).toStringAsFixed(absValue % thresholds[i] == 0 ? 0 : 2)}${suffixes[i]}';
      }
    }
    return null;
  }

  static double roundTo2Decimals(double value) {
    if (value.isInfinite || value.isNaN) return 0.0;
    return (value * 100).roundToDouble() / 100;
  }

  static String formatCurrency(double value, String locale) {
    return getFormatter(locale).format(value);
  }
}
