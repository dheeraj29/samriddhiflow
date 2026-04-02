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
import '../l10n/app_localizations.dart';

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
  bool _hideBalance = true; // default hidden for privacy during drops

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
              ? AppLocalizations.of(context)!.addTransactionTitle
              : AppLocalizations.of(context)!.editTransactionTitle)),
      body: accountsAsync.when(
        data: (accounts) {
          final allTxns = transactionsAsync.asData?.value ?? [];
          final sortedAccounts = _prepareSortedAccounts(accounts, allTxns);
          return _buildForm(
              sortedAccounts, sortedCategories, allTxns, accounts);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        // coverage:ignore-start
        error: (e, s) => Center(
            child: Text(AppLocalizations.of(context)!
                .errorLabelWithDetails(e.toString()))),
        // coverage:ignore-end
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
            label: Text(AppLocalizations.of(context)!.expenseType),
            icon: PureIcons.expense()),
        ButtonSegment(
            value: TransactionType.income,
            label: Text(AppLocalizations.of(context)!.incomeType),
            icon: PureIcons.income()),
        ButtonSegment(
            value: TransactionType.transfer,
            label: Text(AppLocalizations.of(context)!.transferType),
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
      key: ValueKey('category_dropdown_$_type'),
      initialValue: _category,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.categoryLabel,
          border: const OutlineInputBorder()),
      items: sortedCategories
          .map((c) => DropdownMenuItem<String?>(
              value: c.name,
              child: Row(
                children: [
                  if (c.iconCode != 0) ...[
                    PureIcons.categoryIcon(c.iconCode, // coverage:ignore-line
                        size: 18,
                        color: Colors.blueGrey),
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
                        _getTagLabel(context, c.tag),
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
      onChanged: (v) {
        FocusScope.of(context).unfocus();
        setState(() => _category = v!);
      },
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
            labelText: AppLocalizations.of(context)!.capitalGainProfitAmount,
            border: const OutlineInputBorder(),
            prefixText:
                '${CurrencyUtils.getSymbol(ref.watch(currencyProvider))} ',
            prefixStyle: AppTheme.offlineSafeTextStyle,
            helperText: _getGainHelperText(context),
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
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.holdingTenureMonths,
            hintText: AppLocalizations.of(context)!.holdingTenureHint,
            border: const OutlineInputBorder(),
            helperText: AppLocalizations.of(context)!.holdingTenureHelper,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) =>
              _holdingTenureMonths = int.tryParse(v), // coverage:ignore-line
        ),
      ],
    );
  }

  String _getGainHelperText(BuildContext context) {
    if (_amount > 0 && (_gainAmount ?? 0) != 0) {
      final type = (_gainAmount ?? 0) > 0
          ? AppLocalizations.of(context)!.profitLabel
          : AppLocalizations.of(context)!.lossLabel; // coverage:ignore-line
      final amountStr = CurrencyUtils.getFormatter(ref.read(currencyProvider))
          .format(_gainAmount!.abs());
      final costStr = CurrencyUtils.getFormatter(ref.read(currencyProvider))
          .format(_amount - (_gainAmount ?? 0));
      return '$type: $amountStr (${AppLocalizations.of(context)!.purchaseCostLabel}: $costStr)';
    }
    return AppLocalizations.of(context)!.gainAmountHelper;
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
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.descriptionLabel,
            border: const OutlineInputBorder(),
          ),
          validator: (v) =>
              v!.isEmpty ? AppLocalizations.of(context)!.requiredError : null,
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
      key: ValueKey('account_dropdown_$_type'),
      isExpanded: true,
      initialValue: _selectedAccountId,
      decoration: InputDecoration(
        labelText: _type == TransactionType.transfer
            ? AppLocalizations.of(context)!.fromAccountLabel
            : AppLocalizations.of(context)!.accountLabel,
        border: const OutlineInputBorder(),
        prefixIcon: IconButton(
          icon: Icon(_hideBalance ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(
              () => _hideBalance = !_hideBalance), // coverage:ignore-line
        ),
      ),
      items: <DropdownMenuItem<String?>>[
        DropdownMenuItem<String?>(
            value: null,
            child: Text(AppLocalizations.of(context)!.noAccountManual)),
        ...sortedAccounts.map((a) => DropdownMenuItem<String?>(
              value: a.id,
              child: Text('${a.name} (${_formatAccountBalance(a, allTxns)})'),
            )),
      ],
      onChanged: (v) {
        FocusScope.of(context).unfocus();
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
      key: ValueKey('to_account_dropdown_$_type-$_selectedAccountId'),
      isExpanded: true,
      initialValue: _toAccountId,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.toAccountLabel,
        border: const OutlineInputBorder(),
        prefixIcon: IconButton(
          icon: Icon(_hideBalance ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(
              () => _hideBalance = !_hideBalance), // coverage:ignore-line
        ),
      ),
      items: <DropdownMenuItem<String?>>[
        if (_toAccountId == null)
          DropdownMenuItem<String?>(
              value: null,
              child: Text(AppLocalizations.of(context)!.selectRecipient)),
        ...sortedAccounts
            .where((a) => a.id != _selectedAccountId)
            .map((a) => DropdownMenuItem<String?>(
                  value: a.id,
                  child:
                      Text('${a.name} (${_formatAccountBalance(a, allTxns)})'),
                )),
      ],
      onChanged: (v) {
        FocusScope.of(context).unfocus();
        setState(() => _toAccountId = v);
      },
      validator: (v) => v == null
          ? AppLocalizations.of(context)!.requiredError
          : null, // coverage:ignore-line
    );
  }

  Widget _buildAmountField(List<Account> accounts) {
    return TextFormField(
      controller: _amountController,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.amountLabel,
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
      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
          ? AppLocalizations.of(context)!.invalidAmountError
          : null,
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
          title: Text(AppLocalizations.of(context)!.makeRecurring),
          subtitle: Text(AppLocalizations.of(context)!.repeatAutomatically),
          value: _isRecurring,
          onChanged: (v) => setState(() => _isRecurring = v),
        ),
        if (_isRecurring) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.recurringAction,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: false,
                        label:
                            Text(AppLocalizations.of(context)!.payAndSchedule),
                        icon: PureIcons.income()),
                    ButtonSegment(
                        value: true,
                        label: Text(AppLocalizations.of(context)!.justSchedule),
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
              AppLocalizations.of(context)!.firstExecution(
                  DateFormat('EEE, MMM d, y')
                      .format(RecurrenceUtils.findFirstOccurrence(
                          baseDate: _date,
                          frequency: _frequency,
                          scheduleType: _scheduleType,
                          selectedWeekday: _selectedWeekday,
                          adjustForHolidays: _adjustForHolidays,
                          // coverage:ignore-end
                          holidays: holidays))),
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
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.frequencyDropdownLabel,
                border: const OutlineInputBorder()),
            items: Frequency.values
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(_getFrequencyLabel(context, f)),
                    ))
                .toList(),
            onChanged: (v) {
              FocusScope.of(context).unfocus();
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
            title: Text(AppLocalizations.of(context)!.adjustForHolidays),
            subtitle: Text(AppLocalizations.of(context)!.adjustForHolidaysDesc),
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
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.scheduleTypeLabel,
          border: const OutlineInputBorder()),
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
                child: Text(_getScheduleLabelLocalized(context, s)),
              ))
          .toList(),
      // coverage:ignore-start
      onChanged: (v) {
        FocusScope.of(context).unfocus();
        setState(() => _scheduleType = v!);
        // coverage:ignore-end
      },
    );
  }

  Widget _buildWeekdayDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedWeekday ?? 1,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.selectWeekdayLabel,
          border: const OutlineInputBorder()),
      items: [
        DropdownMenuItem(
            value: 1, child: Text(AppLocalizations.of(context)!.monday)),
        DropdownMenuItem(
            value: 2, child: Text(AppLocalizations.of(context)!.tuesday)),
        DropdownMenuItem(
            value: 3, child: Text(AppLocalizations.of(context)!.wednesday)),
        DropdownMenuItem(
            value: 4, child: Text(AppLocalizations.of(context)!.thursday)),
        DropdownMenuItem(
            value: 5, child: Text(AppLocalizations.of(context)!.friday)),
        DropdownMenuItem(
            value: 6, child: Text(AppLocalizations.of(context)!.saturday)),
        DropdownMenuItem(
            value: 7, child: Text(AppLocalizations.of(context)!.sunday)),
      ],
      // coverage:ignore-start
      onChanged: (v) {
        FocusScope.of(context).unfocus();
        setState(() => _selectedWeekday = v);
        // coverage:ignore-end
      },
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
              ? AppLocalizations.of(context)!.saveTransaction
              : AppLocalizations.of(context)!.updateTransaction,
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

    try {
      await _handleCategoryChange(storage);

      final txn = _createTransaction(dateTime, storage);
      await _saveTransactionAndRecurring(txn, dateTime, storage);

      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(recurringTransactionsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            // coverage:ignore-end
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _validateTransferAccounts() {
    if (_type == TransactionType.transfer &&
        _selectedAccountId != null &&
        _selectedAccountId == _toAccountId) {
      // coverage:ignore-start
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.sameAccountError),
          // coverage:ignore-end
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
        SnackBar(
          content: Text(AppLocalizations.of(context)!.futureScheduleOnlyError),
          // coverage:ignore-end
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _handleCategoryChange(dynamic storage) async {
    if (!_shouldShowCategoryChangeDialog()) return;

    final oldCount = await storage.getSimilarTransactionCount(_title,
        widget.transactionToEdit!.category, widget.transactionToEdit!.id);
    if (oldCount <= 0) return;
    if (!mounted) return;

    final shouldUpdate = await _showCategoryChangeDialog(oldCount);
    if (shouldUpdate == true) {
      await storage.bulkUpdateCategory(
          _title, widget.transactionToEdit!.category, _category!);
    }
  }

  bool _shouldShowCategoryChangeDialog() {
    if (widget.transactionToEdit == null) return false;
    if (_category == null) return false;
    if (widget.transactionToEdit!.category == _category) return false;
    return widget.transactionToEdit!.title.trim().toLowerCase() ==
        _title.trim().toLowerCase();
  }

  Future<bool?> _showCategoryChangeDialog(int oldCount) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.updateSimilarTitle),
        content: Text(AppLocalizations.of(context)!.updateSimilarMessage(
            oldCount, _title, widget.transactionToEdit!.category, _category!)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.noJustThisOne),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.yesUpdateAll),
          ),
        ],
      ),
    );
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
      category: _type == TransactionType.transfer
          ? AppLocalizations.of(context)!.transferCategory
          : _category!,
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
      if (!mounted) return;
      final recurring = _createRecurringTransaction(dateTime);
      await storage.saveRecurringTransaction(recurring);
      // coverage:ignore-end
    }
  }

  // coverage:ignore-start
  RecurringTransaction _createRecurringTransaction(DateTime dateTime) {
    final profileId = ref.read(activeProfileIdProvider);
    return RecurringTransaction.create(
      title: _title,
      amount: _amount,
      category: _type == TransactionType.transfer
          ? AppLocalizations.of(context)!.transferCategory
          : _category!,
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
  }

  // --- Utility Methods ---

  String _getFrequencyLabel(BuildContext context, Frequency frequency) {
    final l10n = AppLocalizations.of(context)!;
    switch (frequency) {
      case Frequency.daily:
        return l10n.daily;
      case Frequency.weekly:
        return l10n.weekly;
      case Frequency.monthly:
        return l10n.monthly;
      case Frequency.yearly:
        return l10n.yearly;
    }
  }

  String _getScheduleLabelLocalized(BuildContext context, ScheduleType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case ScheduleType.fixedDate:
        return l10n.fixedDate;
      case ScheduleType.everyWeekend:
        return l10n.everyWeekend;
      case ScheduleType.lastWeekend:
        return l10n.lastWeekend;
      case ScheduleType.specificWeekday:
        return l10n.specificWeekday;
      case ScheduleType.lastDayOfMonth:
        return l10n.lastDayOfMonth;
      case ScheduleType.lastWorkingDay:
        return l10n.lastWorkingDay;
      case ScheduleType.firstWorkingDay:
        return l10n.firstWorkingDay;
    }
  }

  String _getTagLabel(BuildContext context, CategoryTag tag) {
    final l10n = AppLocalizations.of(context)!;
    switch (tag) {
      case CategoryTag.none:
        return '';
      case CategoryTag.capitalGain:
        return l10n.capitalGainTag;
      // coverage:ignore-start
      case CategoryTag.directTax:
        return l10n.directTaxTag;
      case CategoryTag.budgetFree:
        return l10n.budgetFreeTag;
      case CategoryTag.taxFree:
        return l10n.taxFreeTag;
      // coverage:ignore-end
    }
  }

  String _formatAccountBalance(Account a, List<Transaction> allTxns) {
    if (a.type == AccountType.creditCard) {
      return _formatCreditCardBalance(a, allTxns); // coverage:ignore-line
    }
    return _formatStandardAccountBalance(a);
  }

  // coverage:ignore-start
  String _formatCreditCardBalance(Account a, List<Transaction> allTxns) {
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
      if (_hideBalance) {
        return AppLocalizations.of(context)!.availableShort('•••');
        // coverage:ignore-end
      }
      return AppLocalizations.of(context)! // coverage:ignore-line
          .availableShort(CurrencyUtils.getSmartFormat(
              available, a.currency)); // coverage:ignore-line
    } else {
      if (_hideBalance) {
        // coverage:ignore-line
        return AppLocalizations.of(context)!
            .usageShort('•••'); // coverage:ignore-line
      }
      return AppLocalizations.of(context)! // coverage:ignore-line
          .usageShort(CurrencyUtils.getSmartFormat(
              currentDebt, a.currency)); // coverage:ignore-line
    }
  }

  String _formatStandardAccountBalance(Account a) {
    if (_hideBalance) return AppLocalizations.of(context)!.balanceShort('•••');
    return AppLocalizations.of(context)! // coverage:ignore-line
        .balanceShort(CurrencyUtils.getSmartFormat(
            a.balance, a.currency)); // coverage:ignore-line
  }
}
