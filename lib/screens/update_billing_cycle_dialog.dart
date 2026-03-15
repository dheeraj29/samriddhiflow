import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
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
  DateTime? _freezeDate;

  @override
  void initState() {
    super.initState();
    _cycleDay = widget.account.billingCycleDay ?? 1;
    _dueDay = widget.account.paymentDueDateDay ?? 1;
  }

  Future<void> _selectFreezeDate() async {
    final now = DateTime.now();
    // Freeze date must be >= newest transaction date + 1 day to be safe.
    final firstAllowedDate =
        widget.newestTransactionDate.add(const Duration(days: 1));
    final initial = firstAllowedDate.isAfter(now) ? firstAllowedDate : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate:
          firstAllowedDate, // Strictly strictly greater than newest transaction
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _freezeDate = picked);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_freezeDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Freeze Date.')),
      );
      return;
    }

    // Freeze date must be strictly after the newest transaction date
    if (!_freezeDate!.isAfter(widget.newestTransactionDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        // coverage:ignore-line
        const SnackBar(
            content: Text('Freeze date must be after the newest transaction.')),
      );
      return;
    }

    try {
      final storage = ref.read(storageServiceProvider);
      await storage.updateBillingCycle(
        accountId: widget.account.id,
        newCycleDay: _cycleDay,
        newDueDateDay: _dueDay,
        freezeDate: _freezeDate!,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Billing cycle update initialized successfully!')),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Billing Cycle'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Updating the billing cycle requires freezing the statement until the next cycle to prevent historical data corruption.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _cycleDay,
                decoration:
                    const InputDecoration(labelText: 'New Billing Cycle Day'),
                items: List.generate(28, (i) => i + 1)
                    .map((day) => DropdownMenuItem(
                          value: day,
                          child: Text(day.toString()),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _cycleDay = val);
                },
                onSaved: (val) => _cycleDay = val!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
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
                  if (val != null) setState(() => _dueDay = val);
                },
                onSaved: (val) => _dueDay = val!,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_freezeDate == null
                    ? 'Select Freeze Date'
                    : 'Freeze Date: ${_freezeDate!.year}-${_freezeDate!.month}-${_freezeDate!.day}'),
                subtitle:
                    const Text('Must be after your most recent transaction.'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectFreezeDate,
              ),
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
          child: const Text('Initialize Update'),
        ),
      ],
    );
  }
}
