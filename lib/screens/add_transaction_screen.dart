import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers.dart';
import '../utils/currency_utils.dart';
import '../models/transaction.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../widgets/pure_icons.dart';
import '../theme/app_theme.dart';
import '../utils/recurrence_utils.dart';
import '../utils/billing_helper.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionType initialType;
  final Transaction? transactionToEdit;
  final String? recurringId;
  const AddTransactionScreen({
    super.key,
    this.initialType = TransactionType.expense,
    this.transactionToEdit,
    this.recurringId,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TransactionType _type;
  double _amount = 0;
  String _title = '';
  String? _category;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  String? _selectedAccountId;
  String? _toAccountId; // For transfers

  bool _isRecurring = false;
  bool _isScheduleOnly = false;
  Frequency _frequency = Frequency.monthly;
  ScheduleType _scheduleType = ScheduleType.fixedDate;
  int? _selectedWeekday;
  bool _adjustForHolidays = false;
  int? _holdingTenureMonths;
  double? _gainAmount;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _type = t.type;
      _amount = t.amount;
      _title = t.title;
      _category = t.category;
      _date = t.date;
      _time = TimeOfDay.fromDateTime(t.date);
      _selectedAccountId = t.accountId;
      _toAccountId = t.toAccountId;
      _titleController.text = t.title;
      _amountController.text = t.amount.toStringAsFixed(2);
      _holdingTenureMonths = t.holdingTenureMonths;
      _gainAmount = t.gainAmount;
    } else {
      _type = widget.initialType;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider);

    final sortedCategories =
        _prepareSortedCategories(categories, transactionsAsync);
    _ensureValidCategory(sortedCategories);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.transactionToEdit == null
              ? 'Add Transaction'
              : 'Edit Transaction')),
      body: accountsAsync.when(
        data: (accounts) {
          final allTxns = transactionsAsync.asData?.value ?? [];
          final sortedAccounts = _prepareSortedAccounts(accounts, allTxns);
          return _buildForm(
              sortedAccounts, sortedCategories, allTxns, accounts);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) =>
            Center(child: Text('Error: $e')), // coverage:ignore-line
      ),
    );
  }

  // --- Data Preparation ---

  List<Category> _prepareSortedCategories(List<Category> categories,
      AsyncValue<List<Transaction>> transactionsAsync) {
    final filteredCategories = categories.where((c) {
      if (_type == TransactionType.income) {
        return c.usage == CategoryUsage.income || c.usage == CategoryUsage.both;
      } else if (_type == TransactionType.expense) {
        return c.usage == CategoryUsage.expense ||
            c.usage == CategoryUsage.both;
      }
      return true;
    }).toList();

    final allTxns = transactionsAsync.asData?.value ?? [];
    final cutoff = DateTime.now().subtract(const Duration(days: 360));
    final matchingTxns =
        allTxns.where((t) => !t.isDeleted && t.date.isAfter(cutoff));

    final catFreq = <String, int>{};
    for (var t in matchingTxns) {
      if (t.type == _type) {
        // coverage:ignore-line
        catFreq[t.category] =
            (catFreq[t.category] ?? 0) + 1; // coverage:ignore-line
      }
    }

    return filteredCategories
      ..sort((a, b) {
        final fA = catFreq[a.name] ?? 0;
        final fB = catFreq[b.name] ?? 0;
        if (fA != fB) return fB.compareTo(fA);
        return a.name.compareTo(b.name);
      });
  }

  void _ensureValidCategory(List<Category> sortedCategories) {
    if (_category == null && sortedCategories.isNotEmpty) {
      _category = sortedCategories.first.name;
    } else if (_category != null &&
        !sortedCategories.any((c) => c.name == _category)) {
      _category =
          sortedCategories.isNotEmpty ? sortedCategories.first.name : null;
    }
  }

  List<Account> _prepareSortedAccounts(
      List<Account> accounts, List<Transaction> allTxns) {
    final cutoff = DateTime.now().subtract(const Duration(days: 360));
    final matchingTxns =
        allTxns.where((t) => !t.isDeleted && t.date.isAfter(cutoff));

    final accFreq = <String, int>{};
    for (var t in matchingTxns) {
      if (t.accountId != null) {
        // coverage:ignore-line
        accFreq[t.accountId!] =
            (accFreq[t.accountId!] ?? 0) + 1; // coverage:ignore-line
      }
      if (t.toAccountId != null) {
        // coverage:ignore-line
        accFreq[t.toAccountId!] =
            (accFreq[t.toAccountId!] ?? 0) + 1; // coverage:ignore-line
      }
    }

    return accounts.toList()
      ..sort((a, b) {
        final fA = accFreq[a.id] ?? 0;
        final fB = accFreq[b.id] ?? 0;
        if (fA != fB) return fB.compareTo(fA);
        return a.name.compareTo(b.name);
      });
  }

  // --- Form Building ---

  Widget _buildForm(
      List<Account> sortedAccounts,
      List<Category> sortedCategories,
      List<Transaction> allTxns,
      List<Account> accounts) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTypeSelector(),
          const SizedBox(height: 24),
          if (_type != TransactionType.transfer) ...[
            _buildCategoryDropdown(sortedCategories),
            const SizedBox(height: 16),
            if (_isCapitalGainCategory(sortedCategories)) ...[
              _buildCapitalGainFields(accounts),
              const SizedBox(height: 16),
            ],
          ],
          _buildDescriptionField(),
          const SizedBox(height: 16),
          _buildAccountDropdown(sortedAccounts, allTxns),
          if (_type == TransactionType.transfer) ...[
            const SizedBox(height: 16),
            _buildToAccountDropdown(sortedAccounts, allTxns),
          ],
          const SizedBox(height: 16),
          _buildAmountField(accounts),
          const SizedBox(height: 16),
          _buildDateTimePickers(),
          if (widget.transactionToEdit == null) _buildRecurringToggle(),
          if (_isRecurring) _buildRecurringOptions(),
          const SizedBox(height: 32),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<TransactionType>(
      segments: [
        ButtonSegment(
            value: TransactionType.expense,
            label: const Text('Expense'),
            icon: PureIcons.expense()),
        ButtonSegment(
            value: TransactionType.income,
            label: const Text('Income'),
            icon: PureIcons.income()),
        ButtonSegment(
            value: TransactionType.transfer,
            label: const Text('Transfer'),
            icon: PureIcons.transfer()),
      ],
      selected: {_type},
      onSelectionChanged: (Set<TransactionType> newSelection) {
        setState(() => _type = newSelection.first);
      },
    );
  }

  Widget _buildCategoryDropdown(List<Category> sortedCategories) {
    return DropdownButtonFormField<String?>(
      key: const Key('category_dropdown'),
      initialValue: _category,
      decoration: const InputDecoration(
          labelText: 'Category', border: OutlineInputBorder()),
      items: sortedCategories
          .map((c) => DropdownMenuItem<String?>(
              value: c.name,
              child: Row(
                children: [
                  if (c.iconCode != 0) ...[
                    PureIcons.categoryIcon(c.iconCode,
                        size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                  ],
                  Text(c.name),
                  if (c.tag != CategoryTag.none) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTagLabel(c.tag),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ],
              )))
          .toList(),
      onChanged: (v) => setState(() => _category = v!),
    );
  }

  bool _isCapitalGainCategory(List<Category> sortedCategories) {
    return sortedCategories
        .any((c) => c.name == _category && c.tag == CategoryTag.capitalGain);
  }

  Widget _buildCapitalGainFields(List<Account> accounts) {
    return Column(
      children: [
        TextFormField(
          initialValue: _gainAmount?.toString(),
          decoration: InputDecoration(
            labelText: 'Gain / Profit Amount',
            border: const OutlineInputBorder(),
            prefixText:
                '${CurrencyUtils.getSymbol(ref.watch(currencyProvider))} ',
            prefixStyle: AppTheme.offlineSafeTextStyle,
            helperText: _getGainHelperText(),
            helperStyle: TextStyle(color: _getGainHelperColor()),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.negativeAmountExp),
          ],
          onChanged: (v) => setState(() => _gainAmount = double.tryParse(v)),
          onSaved: (v) => _gainAmount = v == null || v.isEmpty
              ? null
              : CurrencyUtils.roundTo2Decimals(double.parse(v)),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _holdingTenureMonths?.toString(),
          decoration: const InputDecoration(
            labelText: 'Holding Tenure (Months)',
            hintText: 'e.g., 12',
            border: OutlineInputBorder(),
            helperText: 'Enter months held (Long-term: 12+ months for stocks)',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) =>
              _holdingTenureMonths = int.tryParse(v), // coverage:ignore-line
        ),
      ],
    );
  }

  String _getGainHelperText() {
    if (_amount > 0 && (_gainAmount ?? 0) != 0) {
      final type = (_gainAmount ?? 0) > 0 ? "Profit" : "Loss";
      final amountStr = CurrencyUtils.getFormatter(ref.read(currencyProvider))
          .format(_gainAmount!.abs());
      final costStr = CurrencyUtils.getFormatter(ref.read(currencyProvider))
          .format(_amount - (_gainAmount ?? 0));
      return '$type: $amountStr (Purchase Cost: $costStr)';
    }
    return 'Enter the profit (positive) or loss (negative)';
  }

  Color? _getGainHelperColor() {
    if ((_gainAmount ?? 0) > 0) return Colors.greenAccent;
    if ((_gainAmount ?? 0) < 0) return Colors.redAccent;
    return null;
  }

  Widget _buildDescriptionField() {
    final transactionsAsync = ref.watch(transactionsProvider);
    return RawAutocomplete<String>(
      textEditingController: _titleController,
      focusNode: _titleFocusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final txns = transactionsAsync.asData?.value ?? [];
        final filteredTxns = txns.where((t) =>
            _type == TransactionType.transfer ||
            t.category == _category); // coverage:ignore-line
        if (textEditingValue.text.isEmpty) {
          return filteredTxns.map((t) => t.title).toSet().take(5);
        }
        return filteredTxns
            .map((t) => t.title)
            .toSet()
            .where((title) => title
                .toLowerCase() // coverage:ignore-line
                .contains(textEditingValue.text
                    .toLowerCase())) // coverage:ignore-line
            .toList();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v!.isEmpty ? 'Required' : null,
          onSaved: (v) => _title = v!,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        // coverage:ignore-line
        return Align(
          // coverage:ignore-line
          alignment: Alignment.topLeft,
          child: Material(
            // coverage:ignore-line
            elevation: 4.0,
            // coverage:ignore-start
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              child: ListView.builder(
                // coverage:ignore-end
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                // coverage:ignore-start
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(option),
                    onTap: () => onSelected(option),
                    // coverage:ignore-end
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountDropdown(
      List<Account> sortedAccounts, List<Transaction> allTxns) {
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      initialValue: _selectedAccountId,
      decoration: InputDecoration(
        labelText:
            _type == TransactionType.transfer ? 'From Account' : 'Account',
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
            value: null, child: Text('No Account (Manual)')),
        ...sortedAccounts.map((a) => DropdownMenuItem<String?>(
              value: a.id,
              child: Text('${a.name} (${_formatAccountBalance(a, allTxns)})'),
            )),
      ],
      onChanged: (v) {
        setState(() {
          _selectedAccountId = v;
          if (_selectedAccountId == _toAccountId) {
            _toAccountId = null; // coverage:ignore-line
          }
        });
      },
    );
  }

  Widget _buildToAccountDropdown(
      List<Account> sortedAccounts, List<Transaction> allTxns) {
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      initialValue: _toAccountId,
      decoration: const InputDecoration(
        labelText: 'To Account',
        border: OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<String?>>[
        if (_toAccountId == null)
          const DropdownMenuItem<String?>(
              value: null, child: Text('Select Recipient')),
        ...sortedAccounts
            .where((a) => a.id != _selectedAccountId)
            .map((a) => DropdownMenuItem<String?>(
                  value: a.id,
                  child:
                      Text('${a.name} (${_formatAccountBalance(a, allTxns)})'),
                )),
      ],
      onChanged: (v) => setState(() => _toAccountId = v),
      validator: (v) => v == null ? 'Required' : null,
    );
  }

  Widget _buildAmountField(List<Account> accounts) {
    return TextFormField(
      controller: _amountController,
      decoration: InputDecoration(
        labelText: 'Amount',
        prefixText:
            '${CurrencyUtils.getSymbol(_selectedAccountId == null || accounts.isEmpty ? "en_IN" : accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => accounts.first).currency)} ',
        prefixStyle: AppTheme.offlineSafeTextStyle,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp)
      ],
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      validator: (v) =>
          (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid Amount' : null,
      onSaved: (v) =>
          _amount = CurrencyUtils.roundTo2Decimals(double.parse(v!)),
    );
  }

  Widget _buildDateTimePickers() {
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            icon: PureIcons.calendar(),
            label: Text(DateFormat('yyyy-MM-dd').format(_date)),
            // coverage:ignore-start
            onPressed: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030));
              if (d != null) setState(() => _date = d);
              // coverage:ignore-end
            },
          ),
        ),
        Expanded(
          child: TextButton.icon(
            icon: PureIcons.timer(),
            label: Text(_time.format(context)),
            onPressed: () async {
              // coverage:ignore-line
              final t = await showTimePicker(
                  context: context, initialTime: _time); // coverage:ignore-line
              if (t != null) setState(() => _time = t); // coverage:ignore-line
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecurringToggle() {
    final holidays = ref.watch(holidaysProvider);
    return Column(
      children: [
        const Divider(),
        SwitchListTile(
          title: const Text('Make Recurring'),
          subtitle: const Text('Repeat this transaction automatically'),
          value: _isRecurring,
          onChanged: (v) => setState(() => _isRecurring = v),
        ),
        if (_isRecurring) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recurring Action',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: false,
                        label: const Text('Pay & Schedule'),
                        icon: PureIcons.income()),
                    ButtonSegment(
                        value: true,
                        label: const Text('Just Schedule'),
                        icon: PureIcons.calendar()),
                  ],
                  selected: {_isScheduleOnly},
                  onSelectionChanged: (Set<bool> newSelection) {
                    // coverage:ignore-line
                    setState(() => _isScheduleOnly =
                        newSelection.first); // coverage:ignore-line
                  },
                ),
                if (_isScheduleOnly) ...[
                  const SizedBox(height: 12),
                  _buildFirstExecutionInfo(holidays), // coverage:ignore-line
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFirstExecutionInfo(List<DateTime> holidays) {
    // coverage:ignore-line
    return Container(
      // coverage:ignore-line
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // coverage:ignore-start
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        // coverage:ignore-end
      ),
      child: Row(
        // coverage:ignore-line
        children: [
          // coverage:ignore-line
          const Icon(Icons.info_outline, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          // coverage:ignore-start
          Expanded(
            child: Text(
              "First Execution: ${DateFormat('EEE, MMM d, y').format(RecurrenceUtils.findFirstOccurrence(baseDate: _date, frequency: _frequency, scheduleType: _scheduleType, selectedWeekday: _selectedWeekday, adjustForHolidays: _adjustForHolidays, holidays: holidays))}",
              // coverage:ignore-end
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          DropdownButtonFormField<Frequency>(
            key: const Key('frequency_dropdown'),
            isExpanded: true,
            initialValue: _frequency,
            decoration: const InputDecoration(
                labelText: 'Frequency', border: OutlineInputBorder()),
            items: Frequency.values
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f.name.toUpperCase()),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() {
                _frequency = v!;
                _adjustFrequencyScheduleType();
              });
            },
          ),
          if (_frequency == Frequency.monthly) ...[
            const SizedBox(height: 16),
            _buildScheduleTypeDropdown(),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Adjust for Holidays'),
            subtitle: const Text(
                'Schedule a day earlier if it lands on a holiday/weekend'),
            value: _adjustForHolidays,
            onChanged: (v) =>
                setState(() => _adjustForHolidays = v), // coverage:ignore-line
            contentPadding: EdgeInsets.zero,
          ),
          if (_scheduleType == ScheduleType.specificWeekday) ...[
            const SizedBox(height: 16),
            _buildWeekdayDropdown(),
          ],
        ],
      ),
    );
  }

  void _adjustFrequencyScheduleType() {
    if (_frequency == Frequency.daily || _frequency == Frequency.yearly) {
      _scheduleType = ScheduleType.fixedDate; // coverage:ignore-line
    } else if (_frequency == Frequency.weekly) {
      _scheduleType = ScheduleType.specificWeekday;
      _selectedWeekday ??= _date.weekday;
    } else if (_frequency == Frequency.monthly) {
      // coverage:ignore-line
      _scheduleType = ScheduleType.fixedDate; // coverage:ignore-line
    }
  }

  Widget _buildScheduleTypeDropdown() {
    return DropdownButtonFormField<ScheduleType>(
      key: const Key('schedule_type_dropdown'),
      isExpanded: true,
      initialValue: _scheduleType,
      decoration: const InputDecoration(
          labelText: 'Schedule Type', border: OutlineInputBorder()),
      items: ScheduleType.values
          .where((s) {
            return [
              ScheduleType.fixedDate,
              ScheduleType.everyWeekend,
              ScheduleType.lastWeekend,
              ScheduleType.lastDayOfMonth,
              ScheduleType.lastWorkingDay,
              ScheduleType.firstWorkingDay,
              ScheduleType.specificWeekday
            ].contains(s);
          })
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(_getScheduleLabel(s)),
              ))
          .toList(),
      onChanged: (v) =>
          setState(() => _scheduleType = v!), // coverage:ignore-line
    );
  }

  Widget _buildWeekdayDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedWeekday ?? 1,
      decoration: const InputDecoration(
          labelText: 'Select Weekday', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 1, child: Text('Monday')),
        DropdownMenuItem(value: 2, child: Text('Tuesday')),
        DropdownMenuItem(value: 3, child: Text('Wednesday')),
        DropdownMenuItem(value: 4, child: Text('Thursday')),
        DropdownMenuItem(value: 5, child: Text('Friday')),
        DropdownMenuItem(value: 6, child: Text('Saturday')),
        DropdownMenuItem(value: 7, child: Text('Sunday')),
      ],
      onChanged: (v) =>
          setState(() => _selectedWeekday = v), // coverage:ignore-line
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(
          widget.transactionToEdit == null
              ? 'Save Transaction'
              : 'Update Transaction',
          style: const TextStyle(fontSize: 18)),
    );
  }

  // --- Save Logic ---

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (!_validateTransferAccounts()) return;
    if (!_validateScheduleDate()) return;

    final dateTime =
        DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final storage = ref.read(storageServiceProvider);

    await _handleCategoryChange(storage);

    final txn = _createTransaction(dateTime, storage);
    await _saveTransactionAndRecurring(txn, dateTime, storage);

    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(recurringTransactionsProvider);
    if (mounted) Navigator.pop(context);
  }

  bool _validateTransferAccounts() {
    if (_type == TransactionType.transfer &&
        _selectedAccountId != null &&
        _selectedAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        // coverage:ignore-line
        const SnackBar(
          content: Text('Source and Target accounts cannot be the same.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateScheduleDate() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(_date.year, _date.month, _date.day);

    if (_isRecurring &&
        // coverage:ignore-start
        _isScheduleOnly &&
        selectedDateOnly.isBefore(todayStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        // coverage:ignore-end
        const SnackBar(
          content: Text(
              '"Just Schedule" is only allowed for Today or Future dates.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _handleCategoryChange(dynamic storage) async {
    if (widget.transactionToEdit == null) return;
    if (_category == null) return;
    if (widget.transactionToEdit!.category == _category) return;
    if (widget.transactionToEdit!.title.trim().toLowerCase() !=
        _title.trim().toLowerCase()) {
      return;
    }

    final oldCount = await storage.getSimilarTransactionCount(_title,
        widget.transactionToEdit!.category, widget.transactionToEdit!.id);
    if (oldCount <= 0) return;
    if (!mounted) return;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Similar Transactions?'),
        content: Text(
            'Found $oldCount other transactions with title "$_title" and category "${widget.transactionToEdit!.category}". Do you want to update their category to "$_category" as well?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // coverage:ignore-line
            child: const Text('NO, Just this one'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, Update All'),
          ),
        ],
      ),
    );
    if (shouldUpdate == true) {
      await storage.bulkUpdateCategory(
          _title, widget.transactionToEdit!.category, _category!);
    }
  }

  Transaction _createTransaction(DateTime dateTime, dynamic storage) {
    final selectedCat = storage.getCategories().firstWhere(
        (c) => c.name == _category,
        orElse: () => Category(id: '', name: '', usage: CategoryUsage.both));

    final profileId = ref.read(activeProfileIdProvider);
    return Transaction(
      id: widget.transactionToEdit?.id ?? const Uuid().v4(),
      title: _title,
      amount: _amount,
      date: dateTime,
      type: _type,
      category: _type == TransactionType.transfer ? 'Transfer' : _category!,
      accountId: _selectedAccountId,
      toAccountId: _toAccountId,
      profileId: profileId,
      holdingTenureMonths: selectedCat.tag == CategoryTag.capitalGain
          ? _holdingTenureMonths
          : null,
      gainAmount:
          selectedCat.tag == CategoryTag.capitalGain ? _gainAmount : null,
    );
  }

  Future<void> _saveTransactionAndRecurring(
      Transaction txn, DateTime dateTime, dynamic storage) async {
    if (!_isScheduleOnly) {
      await storage.saveTransaction(txn);
      if (widget.recurringId != null) {
        await storage.advanceRecurringTransactionDate(
            widget.recurringId!); // coverage:ignore-line
        final _ =
            ref.refresh(recurringTransactionsProvider); // coverage:ignore-line
      }
      ref.read(txnsSinceBackupProvider.notifier).refresh();
    }
    if (_isRecurring) {
      // coverage:ignore-start
      final profileId = ref.read(activeProfileIdProvider);
      final recurring = RecurringTransaction.create(
        title: _title,
        amount: _amount,
        category: _type == TransactionType.transfer ? 'Transfer' : _category!,
        accountId: _selectedAccountId,
        frequency: _frequency,
        byMonthDay: (_frequency == Frequency.monthly &&
                _scheduleType == ScheduleType.fixedDate)
            ? dateTime.day
            // coverage:ignore-end
            : null,
        startDate: _isScheduleOnly // coverage:ignore-line
            ? RecurrenceUtils.findFirstOccurrence(
                // coverage:ignore-line
                baseDate: dateTime,
                // coverage:ignore-start
                frequency: _frequency,
                scheduleType: _scheduleType,
                selectedWeekday: _selectedWeekday,
                adjustForHolidays: _adjustForHolidays,
                holidays: ref.read(holidaysProvider))
            // coverage:ignore-end
            : dateTime,
        // coverage:ignore-start
        scheduleType: _scheduleType,
        selectedWeekday: _selectedWeekday,
        adjustForHolidays: _adjustForHolidays,
        // coverage:ignore-end
        profileId: profileId,
        type: _type, // coverage:ignore-line
      );
      await storage.saveRecurringTransaction(recurring); // coverage:ignore-line
    }
  }

  // --- Utility Methods ---

  String _getScheduleLabel(ScheduleType type) {
    switch (type) {
      case ScheduleType.fixedDate:
        return 'Exact Date Each Month';
      case ScheduleType.everyWeekend:
        return 'Every Weekend (Sat or Sun)';
      case ScheduleType.lastWeekend:
        return 'Last Weekend of Month';
      case ScheduleType.specificWeekday:
        return 'Specific Weekday';
      case ScheduleType.lastDayOfMonth:
        return 'Last Day of Month';
      case ScheduleType.lastWorkingDay:
        return 'Last Working Day of Month';
      case ScheduleType.firstWorkingDay:
        return 'First Working Day of Month';
    }
  }

  String _getTagLabel(CategoryTag tag) {
    switch (tag) {
      case CategoryTag.none:
        return '';
      case CategoryTag.capitalGain:
        return 'Capital Gain';
      case CategoryTag.directTax: // coverage:ignore-line
        return 'Direct Tax';
      case CategoryTag.budgetFree: // coverage:ignore-line
        return 'Budget Free';
      case CategoryTag.taxFree: // coverage:ignore-line
        return 'Tax Free';
    }
  }

  String _formatAccountBalance(Account a, List<Transaction> allTxns) {
    if (a.type == AccountType.creditCard) {
      // coverage:ignore-start
      final now = DateTime.now();
      final storage = ref.read(storageServiceProvider);
      final unbilled = BillingHelper.calculateUnbilledAmount(a, allTxns, now);
      final billed = BillingHelper.calculateBilledAmount(
          a, allTxns, now, storage.getLastRollover(a.id));
      final currentDebt = a.balance + billed + unbilled;
      // coverage:ignore-end

      // coverage:ignore-start
      if (a.creditLimit != null && a.creditLimit! > 0) {
        final available = a.creditLimit! - currentDebt;
        return 'Avail: ${CurrencyUtils.getSmartFormat(available, a.currency)}';
        // coverage:ignore-end
      } else {
        return 'Usage: ${CurrencyUtils.getSmartFormat(currentDebt, a.currency)}'; // coverage:ignore-line
      }
    }
    return 'Bal: ${CurrencyUtils.getSmartFormat(a.balance, a.currency)}';
  }
}
