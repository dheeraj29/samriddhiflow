import 'package:flutter/material.dart';
import '../models/transaction.dart';

enum TimeRange { all, last30Days, thisMonth, lastMonth, custom }

class TransactionFilter extends StatelessWidget {
  final TimeRange selectedRange;
  final String? selectedCategory;
  final String? selectedAccountId;
  final TransactionType? selectedType; // New

  final List<String> categories;
  final List<DropdownMenuItem<String?>> accountItems;

  final Function(TimeRange) onRangeChanged;
  final Function(String?) onCategoryChanged;
  final Function(String?) onAccountChanged;
  final Function(TransactionType?) onTypeChanged; // New
  final VoidCallback? onCustomRangeTap;
  final String? customRangeLabel;

  const TransactionFilter({
    super.key,
    required this.selectedRange,
    required this.selectedCategory,
    required this.selectedAccountId,
    this.selectedType, // New
    required this.categories,
    required this.accountItems,
    required this.onRangeChanged,
    required this.onCategoryChanged,
    required this.onAccountChanged,
    required this.onTypeChanged, // New
    this.onCustomRangeTap,
    this.customRangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Row(
            children: [
              // Time Range Dropdown
              Expanded(
                child: DropdownButtonFormField<TimeRange>(
                  initialValue: selectedRange,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(),
                    labelText: 'Time Range',
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: TimeRange.all, child: Text('All Time')),
                    DropdownMenuItem(
                        value: TimeRange.last30Days,
                        child: Text('Last 30 Days')),
                    DropdownMenuItem(
                        value: TimeRange.thisMonth, child: Text('This Month')),
                    DropdownMenuItem(
                        value: TimeRange.lastMonth, child: Text('Last Month')),
                    DropdownMenuItem(
                        value: TimeRange.custom, child: Text('Custom Range')),
                  ],
                  onChanged: (v) => onRangeChanged(v!),
                ),
              ),
              const SizedBox(width: 16),
              // Category Dropdown
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: categories.contains(selectedCategory)
                      ? selectedCategory
                      : null,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(),
                    labelText: 'Category',
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All Categories')),
                    ...categories.map((c) =>
                        DropdownMenuItem<String?>(value: c, child: Text(c))),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Type Dropdown
              Expanded(
                child: DropdownButtonFormField<TransactionType?>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(),
                    labelText: 'Type',
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Types')),
                    DropdownMenuItem(
                        value: TransactionType.income, child: Text('Income')),
                    DropdownMenuItem(
                        value: TransactionType.expense, child: Text('Expense')),
                    DropdownMenuItem(
                        value: TransactionType.transfer,
                        child: Text('Transfer')),
                  ],
                  onChanged: onTypeChanged,
                ),
              ),
              const SizedBox(width: 16),
              // Account Dropdown
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: accountItems
                          .any((item) => item.value == selectedAccountId)
                      ? selectedAccountId
                      : null,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(),
                    labelText: 'Account',
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All Accounts')),
                    ...accountItems,
                  ],
                  onChanged: onAccountChanged,
                ),
              ),

              if (selectedRange == TimeRange.custom) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: onCustomRangeTap,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Select Dates',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(customRangeLabel ?? 'Tap to select',
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }
}
