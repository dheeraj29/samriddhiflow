import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      title: const Text('Recalculate Loan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Current Outstanding: ${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).format(widget.loan.remainingPrincipal)}'),
          const SizedBox(height: 16),
          TextField(
            controller: _emiController,
            decoration: const InputDecoration(
                labelText: 'New EMI Amount', border: OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))
            ],
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Calculate Interest Rate?'),
            subtitle: const Text(
                'If checked, Tenure will be used to find the new Rate. Otherwise, Tenure is recalculated.'),
            value: _adjustRate,
            onChanged: (v) => setState(() => _adjustRate = v!),
          ),
          if (_adjustRate) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _tenureController,
              decoration: const InputDecoration(
                  labelText: 'Target Tenure (Months)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final newEmi = double.tryParse(_emiController.text) ?? 0;
            final newTenure = int.tryParse(_tenureController.text) ?? 0;

            if (newEmi > 0) {
              await _handleRecalculate(newEmi, newTenure);
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Update'),
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
