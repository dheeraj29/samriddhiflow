import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:samriddhi_flow/screens/taxes/tax_constants.dart';

void main() {
  test('TaxConstants formatter uses the shared tax date format', () {
    expect(TaxConstants.dateFormat, 'dd/MM/yyyy');
    expect(TaxConstants.formatter.pattern, TaxConstants.dateFormat);
    expect(TaxConstants.formatter.format(DateTime(2026, 4, 5)), '05/04/2026');
    expect(TaxConstants.formatter, isA<DateFormat>());
  });
}
