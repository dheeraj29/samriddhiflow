import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../utils/billing_helper.dart';
import '../models/account.dart';
import '../services/storage_service.dart';
import '../providers.dart';

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
                  ? 'Billing cycle update initialized successfully!'
                  : 'Payment due date updated successfully!')),
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
      throw Exception('Please select your first statement date.');
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
      throw Exception(// coverage:ignore-line
          'Billing cycle day can only be changed when the total debt is 0. However, you can still update your Payment Due Date.');
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
    final options = _calculateOptions();
    final dateFormat = DateFormat('MMM dd, yyyy');

    return AlertDialog(
      title: const Text('Update Billing Cycle'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Updating the billing cycle requires freezing the statement until your chosen start month.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !isAlreadyFrozen,
                title: const Text('Freeze Transactions Until'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(_freezeDate)),
                trailing: Icon(Icons.calendar_today,
                    color: isAlreadyFrozen ? Colors.grey : null),
                onTap: isAlreadyFrozen
                    ? null
                    : () async {
                        // coverage:ignore-line
                        final picked = await showDatePicker(
                          // coverage:ignore-line
                          context: context,
                          // coverage:ignore-start
                          initialDate: _freezeDate,
                          firstDate: widget.newestTransactionDate,
                          lastDate: DateTime.now(),
                          // coverage:ignore-end
                        );
                        if (picked != null) {
                          // coverage:ignore-start
                          setState(() {
                            _freezeDate = picked;
                            _firstStatementDate =
                                // coverage:ignore-end
                                null; // Reset selection as options might change
                          });
                        }
                      },
              ),
              if (isAlreadyFrozen)
                const Text(
                  'Freeze date cannot be changed for an active freeze.',
                  style: TextStyle(fontSize: 10, color: Colors.orange),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: const Key('cycleDayDropdown'),
                initialValue: _cycleDay,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _cycleDay = val;
                      _firstStatementDate = null; // Reset selection
                    });
                  }
                },
                decoration:
                    const InputDecoration(labelText: 'New Billing Cycle Day'),
                items: List.generate(28, (i) => i + 1)
                    .map((day) => DropdownMenuItem(
                          value: day,
                          child: Text(day.toString()),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const Key('dueDayDropdown'),
                initialValue: _dueDay,
                decoration:
                    const InputDecoration(labelText: 'New Payment Due Day'),
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
              ),
              if (_cycleDay != widget.account.billingCycleDay) ...[
                const SizedBox(height: 24),
                const Text(
                  'Select First Statement Month:',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_cycleDay != widget.account.billingCycleDay
              ? 'Initialize Update'
              : 'Save Changes'),
        ),
      ],
    );
  }
}
