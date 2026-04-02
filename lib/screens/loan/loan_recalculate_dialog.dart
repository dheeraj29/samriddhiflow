import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';
import '../../providers.dart';
// Though not using specific helpers, good to import

class LoanRecalculateDialog extends ConsumerStatefulWidget {
  final Loan loan;

  const LoanRecalculateDialog({super.key, required this.loan});

  @override
  ConsumerState<LoanRecalculateDialog> createState() =>
      _LoanRecalculateDialogState();
}

class _LoanRecalculateDialogState extends ConsumerState<LoanRecalculateDialog> {
  late TextEditingController _emiController;
  late TextEditingController _tenureController;
  bool _adjustRate = false; // false = Adjust Tenure, true = Adjust Rate

  @override
  void initState() {
    super.initState();
    _emiController =
        TextEditingController(text: widget.loan.emiAmount.toStringAsFixed(2));
    _tenureController =
        TextEditingController(text: widget.loan.tenureMonths.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.recalculateLoanTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.currentOutstandingLabel(
              NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider))
                  .format(widget.loan.remainingPrincipal))),
          const SizedBox(height: 16),
          TextField(
            controller: _emiController,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.newEmiAmountLabel,
                border: const OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp)
            ],
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title:
                Text(AppLocalizations.of(context)!.calculateInterestRateOption),
            subtitle: Text(
                AppLocalizations.of(context)!.calculateInterestRateSubtitle),
            value: _adjustRate,
            onChanged: (v) => setState(() => _adjustRate = v!),
          ),
          if (_adjustRate) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _tenureController,
              decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context)!.targetTenureMonthsLabel,
                  border: const OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.cancelButton)),
        ElevatedButton(
          onPressed: () async {
            final newEmi = double.tryParse(_emiController.text) ?? 0;
            final newTenure = int.tryParse(_tenureController.text) ?? 0;

            if (newEmi > 0) {
              await _handleRecalculate(newEmi, newTenure);
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: Text(AppLocalizations.of(context)!.updateButton),
        ),
      ],
    );
  }

  Future<void> _handleRecalculate(double newEmi, int newTenure) async {
    final storage = ref.read(storageServiceProvider);
    final loanService = ref.read(loanServiceProvider);
    var loan = widget.loan;

    if (_adjustRate) {
      if (newTenure > 0) {
        final newRate = loanService.calculateRateForEMITenure(
          principal: loan.remainingPrincipal,
          tenureMonths: newTenure,
          emi: newEmi,
        );
        loan.interestRate = newRate;
        loan.emiAmount = newEmi;

        final monthsPassed =
            DateTime.now().difference(loan.startDate).inDays ~/ 30;
        loan.tenureMonths = monthsPassed + newTenure;
      }
    } else {
      final calcTenure = loanService.calculateTenureForEMI(
          principal: loan.remainingPrincipal,
          annualRate: loan.interestRate,
          emi: newEmi);

      loan.emiAmount = newEmi;
      final monthsPassed =
          DateTime.now().difference(loan.startDate).inDays ~/ 30;
      loan.tenureMonths = monthsPassed + calcTenure;
    }

    await storage.saveLoan(loan);
    ref.invalidate(loansProvider);
  }
}
