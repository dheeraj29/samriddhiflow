import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../utils/billing_helper.dart';
import '../models/account.dart';
import '../services/storage_service.dart';
import '../providers.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';

class UpdateBillingCycleDialog extends ConsumerStatefulWidget {
  final Account account;
  final DateTime newestTransactionDate;

  const UpdateBillingCycleDialog({
    super.key,
    required this.account,
    required this.newestTransactionDate,
  });

  @override
  ConsumerState<UpdateBillingCycleDialog> createState() =>
      _UpdateBillingCycleDialogState();
}

class _UpdateBillingCycleDialogState
    extends ConsumerState<UpdateBillingCycleDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _cycleDay;
  late int _dueDay;
  late DateTime _freezeDate;
  DateTime? _firstStatementDate;

  @override
  void initState() {
    super.initState();
    _cycleDay = widget.account.billingCycleDay ?? 1;
    _dueDay = widget.account.paymentDueDateDay ?? 1;

    // Use existing freeze date if already frozen, else use newest transaction date
    final storage = ref.read(storageServiceProvider);
    final lastRollover = storage.getLastRollover(widget.account.id);
    if (widget.account.isFrozen && lastRollover != null) {
      _freezeDate = DateTime.fromMillisecondsSinceEpoch(
          lastRollover); // coverage:ignore-line
    } else {
      _freezeDate = widget.newestTransactionDate;
    }
  }

  List<DateTime> _calculateOptions() {
    final reference = _freezeDate;
    final option1 = BillingHelper.getCycleEnd(reference, _cycleDay);

    // Option 2 is the same day in the next month
    final option2 = BillingHelper.getCycleEnd(
      option1.add(const Duration(days: 5)), // Jump past current cycle end
      _cycleDay,
    );

    return [option1, option2];
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final cycleChanged = _cycleDay != widget.account.billingCycleDay;

    try {
      final storage = ref.read(storageServiceProvider);

      if (cycleChanged) {
        await _performCycleChange(storage);
      } else {
        await _performDueDateChange(storage); // coverage:ignore-line
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(cycleChanged
                  ? AppLocalizations.of(context)!.billingCycleUpdateSuccess
                  : AppLocalizations.of(context)!
                      .paymentDueDateUpdateSuccess)), // coverage:ignore-line
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _performCycleChange(StorageService storage) async {
    if (_firstStatementDate == null) {
      throw Exception(
          AppLocalizations.of(context)!.selectFirstStatementMonthError);
    }

    final allTxns = ref.read(transactionsProvider).value ?? [];
    final lastRollover = storage.getLastRollover(widget.account.id);

    final currentBilled = BillingHelper.calculateBilledAmount(
        widget.account, allTxns, DateTime.now(), lastRollover);
    final unbilled = BillingHelper.calculateUnbilledAmount(
        widget.account, allTxns, DateTime.now(),
        lastRolloverMillis: lastRollover);
    final payments = BillingHelper.calculatePeriodPayments(
        widget.account,
        allTxns,
        DateTime.fromMillisecondsSinceEpoch(lastRollover ?? 0),
        DateTime.now());

    final data = BillingHelper.getAdjustedCCData(
      accountBalance: widget.account.balance,
      billedAmount: currentBilled,
      unbilledAmount: unbilled,
      paymentsSinceRollover: payments,
    );

    if (data.$1 > 0.01 &&
        !(widget.account.isFrozen && !widget.account.isFrozenCalculated)) {
      // coverage:ignore-line
      throw Exception(AppLocalizations.of(context)!
          .debtZeroRequirementNote); // coverage:ignore-line
    }

    await storage.updateBillingCycle(
      accountId: widget.account.id,
      newCycleDay: _cycleDay,
      newDueDateDay: _dueDay,
      freezeDate: _freezeDate,
      firstStatementDate: _firstStatementDate!,
    );
  }

  // coverage:ignore-start
  Future<void> _performDueDateChange(StorageService storage) async {
    final updatedAccount = widget.account.copyWith(
      paymentDueDateDay: _dueDay,
      // coverage:ignore-end
    );
    await storage.saveAccount(updatedAccount); // coverage:ignore-line
  }

  @override
  Widget build(BuildContext context) {
    final isAlreadyFrozen =
        widget.account.isFrozen && !widget.account.isFrozenCalculated;
    final cycleChanged = _cycleDay != widget.account.billingCycleDay;

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.updateBillingCycleTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.updateBillingCycleNote,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _buildFreezeDateTile(isAlreadyFrozen),
              if (isAlreadyFrozen)
                Text(
                  AppLocalizations.of(context)!.freezeDateLockedNote,
                  style: const TextStyle(fontSize: 10, color: Colors.orange),
                ),
              const SizedBox(height: 8),
              _buildCycleDayDropdown(),
              const SizedBox(height: 16),
              _buildDueDayDropdown(),
              if (cycleChanged) ...[
                const SizedBox(height: 24),
                _buildFirstStatementMonthSection(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context)!.cancelAction),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(cycleChanged
              ? AppLocalizations.of(context)!.initializeUpdateAction
              : AppLocalizations.of(context)!.saveButton),
        ),
      ],
    );
  }

  Widget _buildFreezeDateTile(bool isAlreadyFrozen) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !isAlreadyFrozen,
      title: Text(AppLocalizations.of(context)!.freezeTransactionsUntil),
      subtitle: Text(DateFormat('MMM dd, yyyy').format(_freezeDate)),
      trailing: Icon(Icons.calendar_today,
          color: isAlreadyFrozen ? Colors.grey : null),
      onTap: isAlreadyFrozen
          ? null
          // coverage:ignore-start
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _freezeDate,
                firstDate: widget.newestTransactionDate,
                lastDate: DateTime.now(),
                // coverage:ignore-end
              );
              if (picked != null) {
                // coverage:ignore-start
                setState(() {
                  _freezeDate = picked;
                  _firstStatementDate = null;
                  // coverage:ignore-end
                });
              }
            },
    );
  }

  Widget _buildCycleDayDropdown() {
    return DropdownButtonFormField<int>(
      key: const Key('cycleDayDropdown'),
      initialValue: _cycleDay,
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _cycleDay = val;
            _firstStatementDate = null;
          });
        }
      },
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.newBillingCycleDayLabel),
      items: List.generate(28, (i) => i + 1)
          .map((day) => DropdownMenuItem(
                value: day,
                child: Text(day.toString()),
              ))
          .toList(),
    );
  }

  Widget _buildDueDayDropdown() {
    return DropdownButtonFormField<int>(
      key: const Key('dueDayDropdown'),
      initialValue: _dueDay,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.newPaymentDueDayLabel),
      items: List.generate(28, (i) => i + 1)
          .map((day) => DropdownMenuItem(
                value: day,
                child: Text(day.toString()),
              ))
          .toList(),
      onChanged: (val) {
        // coverage:ignore-line
        if (val != null) {
          setState(() => _dueDay = val); // coverage:ignore-line
        }
      },
    );
  }

  Widget _buildFirstStatementMonthSection() {
    final options = _calculateOptions();
    final dateFormat = DateFormat('MMM dd, yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.selectFirstStatementMonth,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        RadioGroup<DateTime>(
          groupValue: _firstStatementDate,
          onChanged: (val) {
            setState(() => _firstStatementDate = val);
          },
          child: Column(
            children: options
                .map((date) => RadioListTile<DateTime>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(dateFormat.format(date)),
                      value: date,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
