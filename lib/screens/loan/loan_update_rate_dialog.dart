import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import '../../models/loan.dart';
import '../../providers.dart';
import '../../widgets/form_utils.dart';

class LoanUpdateRateDialog extends ConsumerStatefulWidget {
  final Loan loan;

  const LoanUpdateRateDialog({super.key, required this.loan});

  @override
  ConsumerState<LoanUpdateRateDialog> createState() =>
      _LoanUpdateRateDialogState();
}

class _LoanUpdateRateDialogState extends ConsumerState<LoanUpdateRateDialog> {
  late TextEditingController _rateController;
  bool _updateTenure = false; // false = Adjust EMI, true = Adjust Tenure
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _rateController =
        TextEditingController(text: widget.loan.interestRate.toString());
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.updateInterestRateTitle),
      content: _buildDialogContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildDialogContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.enterNewRateDescription),
        const SizedBox(height: 16),
        _buildRateField(),
        const SizedBox(height: 16),
        FormUtils.buildDatePickerField(
          context: context,
          selectedDate: _selectedDate,
          onDateTarget: (d) =>
              setState(() => _selectedDate = d), // coverage:ignore-line
          label: AppLocalizations.of(context)!.effectiveDateLabel,
        ),
        const SizedBox(height: 16),
        Text(AppLocalizations.of(context)!.recalculationModeLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        _buildRecalculationMode(),
      ],
    );
  }

  Widget _buildRateField() {
    return TextField(
      controller: _rateController,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.newAnnualRateLabel,
          suffixText: '%'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp)
      ],
    );
  }

  Widget _buildRecalculationMode() {
    return RadioGroup<bool>(
      groupValue: _updateTenure,
      onChanged: (v) {
        if (v != null) setState(() => _updateTenure = v);
      },
      child: Column(
        children: [
          RadioListTile<bool>.adaptive(
            title: Text(AppLocalizations.of(context)!.adjustEmiOption),
            subtitle: Text(AppLocalizations.of(context)!.adjustEmiSubtitleLong),
            value: false,
          ),
          RadioListTile<bool>.adaptive(
            title: Text(AppLocalizations.of(context)!.adjustTenureOption),
            subtitle:
                Text(AppLocalizations.of(context)!.adjustTenureSubtitleLong),
            value: true,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    return [
      TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancelButton)),
      ElevatedButton(
        onPressed: _onUpdatePressed,
        child: Text(AppLocalizations.of(context)!.updateButton),
      ),
    ];
  }

  void _onUpdatePressed() async {
    final newRate = double.tryParse(_rateController.text);
    if (newRate != null && newRate > 0) {
      await _handleUpdateInterestRate(
        loan: widget.loan,
        newRate: newRate,
        effectiveDate: _selectedDate,
        updateTenure: _updateTenure,
      );
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _handleUpdateInterestRate({
    required Loan loan,
    required double newRate,
    required DateTime effectiveDate,
    required bool updateTenure,
  }) async {
    final storage = ref.read(storageServiceProvider);
    final loanService = ref.read(loanServiceProvider);

    final lastDate = loan.transactions.isNotEmpty
        // coverage:ignore-start
        ? loan.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        // coverage:ignore-end
        : loan.startDate;

    final accruedInterest = loanService.calculateAccruedInterest(
      principal: loan.remainingPrincipal,
      annualRate: loan.interestRate,
      fromDate: lastDate,
      toDate: effectiveDate,
    );

    loan.transactions = [
      ...loan.transactions,
      LoanTransaction(
        id: const Uuid().v4(),
        date: effectiveDate,
        amount: newRate,
        type: LoanTransactionType.rateChange,
        principalComponent: 0,
        interestComponent: accruedInterest,
        resultantPrincipal: loan.remainingPrincipal,
      )
    ];
    loan.interestRate = newRate;

    _recalibrateLoan(loan, loanService, updateTenure, effectiveDate, newRate);

    await storage.saveLoan(loan);
    ref.invalidate(loansProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(AppLocalizations.of(context)!.rateUpdatedSuccessMessage)));
    }
  }

  void _recalibrateLoan(Loan loan, dynamic loanService, bool updateTenure,
      DateTime effectiveDate, double newRate) {
    if (!updateTenure) {
      final monthsPassed =
          effectiveDate.difference(loan.startDate).inDays ~/ 30;
      final remainingMonths = (loan.tenureMonths - monthsPassed).clamp(1, 600);
      loan.emiAmount = loanService.calculateEMI(
        principal: loan.remainingPrincipal,
        annualRate: newRate,
        tenureMonths: remainingMonths,
      );
    } else {
      loan.tenureMonths = loanService.calculateTenureForEMI(
        principal: loan.remainingPrincipal,
        annualRate: newRate,
        emi: loan.emiAmount,
      );
    }
  }
}
