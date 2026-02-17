import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lending_record.dart';
import '../../services/lending/lending_provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
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
              ? (widget.recordToEdit!.closedDate ?? DateTime.now())
              : null,
        );
        ref.read(lendingProvider.notifier).updateRecord(updatedRecord);
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.recordToEdit == null ? "Add" : "Edit";

    return Scaffold(
      appBar: AppBar(
        title: Text('$mode Lending Record'),
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
                segments: const [
                  ButtonSegment(
                    value: LendingType.lent,
                    label: Text('Lent (Given)'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: LendingType.borrowed,
                    label: Text('Borrowed (Taken)'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<LendingType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Person Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Person Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter amount';
                  if (double.tryParse(value) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason / Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (widget.recordToEdit != null)
                SwitchListTile(
                  title: const Text('Mark as Closed / SETTLED'),
                  value: _isClosed,
                  onChanged: (val) => setState(() => _isClosed = val),
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
                  '$mode Record',
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
