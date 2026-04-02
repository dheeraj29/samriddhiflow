import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lending_record.dart';
import '../../services/lending/lending_provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';

class AddLendingScreen extends ConsumerStatefulWidget {
  final LendingRecord? recordToEdit;
  final LendingType? initialType;

  const AddLendingScreen({super.key, this.recordToEdit, this.initialType});

  @override
  ConsumerState<AddLendingScreen> createState() => _AddLendingScreenState();
}

class _AddLendingScreenState extends ConsumerState<AddLendingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _reasonController;
  DateTime _selectedDate = DateTime.now();
  late LendingType _selectedType;
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.recordToEdit?.personName ?? '');
    _amountController = TextEditingController(
        text: widget.recordToEdit?.amount.toStringAsFixed(0) ?? '');
    _reasonController =
        TextEditingController(text: widget.recordToEdit?.reason ?? '');
    _selectedDate = widget.recordToEdit?.date ?? DateTime.now();
    _selectedType =
        widget.recordToEdit?.type ?? widget.initialType ?? LendingType.lent;
    _isClosed = widget.recordToEdit?.isClosed ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    // coverage:ignore-line
    final picked = await showDatePicker(
      // coverage:ignore-line
      context: context,
      // coverage:ignore-start
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      // coverage:ignore-end
    );
    // coverage:ignore-start
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // coverage:ignore-end
      });
    }
  }

  void _saveRecord() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final amount = double.tryParse(_amountController.text) ?? 0;
      final reason = _reasonController.text.trim();

      if (widget.recordToEdit == null) {
        // Create New
        final newRecord = LendingRecord.create(
          personName: name,
          amount: amount,
          reason: reason,
          date: _selectedDate,
          type: _selectedType,
        );
        ref.read(lendingProvider.notifier).addRecord(newRecord);
      } else {
        // Update Existing
        final updatedRecord = widget.recordToEdit!.copyWith(
          personName: name,
          amount: amount,
          reason: reason,
          date: _selectedDate,
          type: _selectedType,
          isClosed: _isClosed,
          closedDate: _isClosed
              ? (widget.recordToEdit!.closedDate ??
                  DateTime.now()) // coverage:ignore-line
              : null,
        );
        ref.read(lendingProvider.notifier).updateRecord(updatedRecord);
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modeTitle = widget.recordToEdit == null
        ? l10n.addLendingRecordTitle
        : l10n.editLendingRecordTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(modeTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type Selector
              SegmentedButton<LendingType>(
                segments: [
                  ButtonSegment(
                    value: LendingType.lent,
                    label: Text(l10n.lentLabel),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: LendingType.borrowed,
                    label: Text(l10n.borrowedLabel),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_selectedType},
                // coverage:ignore-start
                onSelectionChanged: (Set<LendingType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                    // coverage:ignore-end
                  });
                },
              ),
              const SizedBox(height: 24),

              // Person Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.personNameLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? l10n.enterNameError : null,
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegexUtils.amountExp),
                ],
                decoration: InputDecoration(
                  labelText: l10n.amountLabelSimplified,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.enterAmountError;
                  }
                  if (double.tryParse(value) == null) {
                    return l10n.invalidNumberError; // coverage:ignore-line
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: l10n.reasonDescriptionLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: () => _selectDate(context), // coverage:ignore-line
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.dateLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (widget.recordToEdit != null)
                SwitchListTile(
                  title: Text(l10n.markAsClosedOption),
                  value: _isClosed,
                  onChanged: (val) =>
                      setState(() => _isClosed = val), // coverage:ignore-line
                ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saveRecord,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _selectedType == LendingType.lent
                      ? Colors.green
                      : Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  widget.recordToEdit == null
                      ? l10n.addRecordButton
                      : l10n.editRecordButton,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
