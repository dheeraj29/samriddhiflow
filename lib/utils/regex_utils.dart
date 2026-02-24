class RegexUtils {
  // ignore: deprecated_member_use
  static final amountExp = RegExp(r'^\d*\.?\d{0,2}$');

  // ignore: deprecated_member_use
  static final negativeAmountExp = RegExp(r'^-?\d*\.?\d{0,2}$');

  // ignore: deprecated_member_use
  static final amountWithOptionalDecimalsExp = RegExp(r'^\d*(\.\d{0,2})?$');

  // ignore: deprecated_member_use
  static final mathExp = RegExp(r'[0-9.\+\-\*\/]');

  // ignore: deprecated_member_use
  static final mathOpExp = RegExp(r'[+\-*/]');

  // ignore: deprecated_member_use
  static final camelCaseExp = RegExp(r'(?<=[a-z])[A-Z]');
}
