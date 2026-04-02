import 'package:intl/intl.dart';

class TaxConstants {
  static const String dateFormat = 'dd/MM/yyyy';

  static DateFormat get formatter =>
      DateFormat(dateFormat); // coverage:ignore-line
}
