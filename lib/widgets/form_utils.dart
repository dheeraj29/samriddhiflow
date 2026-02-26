import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../utils/currency_utils.dart';
import 'pure_icons.dart';
import '../theme/app_theme.dart';
import '../utils/regex_utils.dart';

class FormUtils {
  /// A standardized amount input field with currency prefix.
  static Widget buildAmountField({
    required TextEditingController controller,
    required String currency,
    String label = 'Amount',
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '${CurrencyUtils.getSymbol(currency)} ',
        prefixStyle: AppTheme.offlineSafeTextStyle,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp),
      ],
    );
  }

  /// A reusable account selector dropdown.
  static Widget buildAccountSelector({
    required String value,
    required List<Account> accounts,
    required void Function(String?) onChanged,
    String label = 'Account',
    String manualLabel = 'No Account (Manual)',
    bool allowManual = true,
  }) {
    final allIds = [if (allowManual) 'manual', ...accounts.map((a) => a.id)];
    final safeValue = () {
      if (allIds.contains(value)) return value;
      return allowManual ? 'manual' : accounts.first.id; // coverage:ignore-line
    }();

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        if (allowManual)
          DropdownMenuItem<String>(
            value: 'manual',
            child: Text(manualLabel),
          ),
        ...accounts.map((a) => DropdownMenuItem<String>(
              value: a.id,
              child: Text('${a.name} (${_formatAccountBalance(a)})'),
            )),
      ],
      onChanged: onChanged,
    );
  }

  /// A standardized date picker field.
  static Widget buildDatePickerField({
    required BuildContext context,
    required DateTime selectedDate,
    required void Function(DateTime) onDateTarget,
    String label = 'Date',
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return InkWell(
      onTap: () async { // coverage:ignore-line
        final picked = await showDatePicker( // coverage:ignore-line
          context: context,
          initialDate: selectedDate,
          firstDate: firstDate ?? DateTime(2020), // coverage:ignore-line
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)), // coverage:ignore-line
        );
        if (picked != null) onDateTarget(picked); // coverage:ignore-line
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: PureIcons.calendar(),
        ),
        child: Text(
          DateFormat('yyyy-MM-dd').format(selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  static String _formatAccountBalance(Account a) {
    if (a.type == AccountType.creditCard && a.creditLimit != null) {
      final avail = a.creditLimit! - a.balance; // coverage:ignore-line
      return 'Avail: ${CurrencyUtils.getSmartFormat(avail, a.currency)}'; // coverage:ignore-line
    }
    return 'Bal: ${CurrencyUtils.getSmartFormat(a.balance, a.currency)}';
  }
}
