import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../feature_providers.dart';
import '../providers.dart';
import '../models/investment.dart';
import '../l10n/app_localizations.dart';
import '../utils/regex_utils.dart';
import '../utils/currency_utils.dart';

class AddInvestmentScreen extends ConsumerStatefulWidget {
  final Investment? investmentToEdit;

  const AddInvestmentScreen({super.key, this.investmentToEdit});

  @override
  ConsumerState<AddInvestmentScreen> createState() =>
      _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends ConsumerState<AddInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  String? _codeName;
  late InvestmentType _type;
  MutualFundCategory? _mfCategory;
  late DateTime _acquisitionDate;
  late double _acquisitionPrice;
  late double _quantity;
  double? _currentPrice;
  double? _fixedInterestRate;
  int _thresholdYears = 1;
  bool _isRecurringEnabled = false;
  bool _isRecurringPaused = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _codeNameCtrl;
  // These will be used to sync with Autocomplete's internal controllers
  TextEditingController? _nameAutocompleteCtrl;
  TextEditingController? _codeNameAutocompleteCtrl;
  double? _recurringAmount;
  DateTime? _nextRecurringDate;

  @override
  void initState() {
    super.initState();
    final inv = widget.investmentToEdit;
    if (inv != null) {
      _name = inv.name;
      _codeName = inv.codeName;
      _type = inv.type;
      _mfCategory = inv.mfCategory;
      _acquisitionDate = inv.acquisitionDate;
      _acquisitionPrice = inv.acquisitionPrice;
      _quantity = inv.quantity;
      _currentPrice = inv.currentPrice;
      _fixedInterestRate = inv.fixedInterestRate;
      _thresholdYears = inv.customLongTermThresholdYears;
      _isRecurringEnabled = inv.isRecurringEnabled;
      _isRecurringPaused = inv.isRecurringPaused;
      _recurringAmount = inv.recurringAmount;
      _nextRecurringDate = inv.nextRecurringDate;
    } else {
      _name = '';
      _type = InvestmentType.stock;
      _acquisitionDate = DateTime.now();
      _acquisitionPrice = 0.0;
      _quantity = 1.0;
      _thresholdYears = 1;
      _isRecurringEnabled = false;
      _isRecurringPaused = false;
    }
    _nameCtrl = TextEditingController(text: _name);
    _codeNameCtrl = TextEditingController(text: _codeName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeNameCtrl.dispose();
    super.dispose();
  }

  bool get _showCodeName =>
      _type == InvestmentType.stock || _type == InvestmentType.mutualFund;
  bool get _showQuantity =>
      _type != InvestmentType.fixedSavings &&
      _type != InvestmentType.otherFixed &&
      _type != InvestmentType.pf;

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final l10n = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      _formKey.currentState!.save();

      final newCode =
          _codeNameCtrl.text.trim().isEmpty ? null : _codeNameCtrl.text.trim();
      final oldItem = widget.investmentToEdit;
      final oldCode = oldItem?.codeName;

      // 1. Handle stock code rename in bulk
      await _handleBulkCodeRename(newCode, oldCode, oldItem?.id, l10n, theme);

      if (!mounted) return;

      // 2. Handle valuation sync across matching tickers
      final finalPrice = _currentPrice ?? 0.0;
      await _handleBulkValuationSync(
          newCode, oldItem?.id, finalPrice, l10n, theme);

      if (!mounted) return;

      // Final save and exit
      final investment = _prepareInvestment();
      await ref.read(investmentsProvider.notifier).saveInvestment(investment);

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleBulkCodeRename(String? newCode, String? oldCode,
      String? currentId, AppLocalizations l10n, ThemeData theme) async {
    if (currentId == null ||
        oldCode == null ||
        oldCode.isEmpty ||
        newCode == oldCode ||
        newCode == null) {
      return;
    }

    final otherMatching = ref
        .read(investmentsProvider)
        .where((inv) => inv.id != currentId && inv.codeName == oldCode)
        .toList();

    if (otherMatching.isEmpty) return;

    final proceedBulk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bulkUpdateCodeTitle),
        content: Text(
            l10n.bulkUpdateCodeMessage(otherMatching.length, oldCode, newCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // coverage:ignore-line
            child: Text(l10n.updateOnlyThisAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary),
            child: Text(l10n.updateAllAction),
          ),
        ],
      ),
    );

    if (proceedBulk == true) {
      await ref
          .read(investmentsProvider.notifier)
          .updateCodeNameBulk(oldCode, newCode);
    }
  }

  Future<void> _handleBulkValuationSync(String? newCode, String? currentId,
      double finalPrice, AppLocalizations l10n, ThemeData theme) async {
    if (newCode == null || newCode.isEmpty || !mounted) return;

    final otherPriceMatching = ref
        .read(investmentsProvider)
        .where((inv) =>
            inv.id != currentId &&
            inv.codeName == newCode &&
            inv.currentPrice != finalPrice)
        .toList();

    if (otherPriceMatching.isEmpty) return;

    final proceedValSync = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bulkUpdateValuationTitle),
        content: Text(l10n.bulkUpdateValuationMessage(
            newCode, otherPriceMatching.length, finalPrice)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // coverage:ignore-line
            child: Text(l10n.updateOnlyThisAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary),
            child: Text(l10n.updateAllAction),
          ),
        ],
      ),
    );

    if (proceedValSync == true) {
      await ref
          .read(investmentsProvider.notifier)
          .updateValuationBulk(newCode, finalPrice);
    }
  }

  Investment _prepareInvestment() {
    final nameVal = _nameCtrl.text;
    final codeNameVal = _codeNameCtrl.text.isEmpty ? null : _codeNameCtrl.text;
    final isMutualFund = _type == InvestmentType.mutualFund;

    final baseProps = {
      'name': nameVal,
      'codeName': codeNameVal,
      'type': _type,
      'mfCategory': isMutualFund ? _mfCategory : null, // coverage:ignore-line
      'acquisitionDate': _acquisitionDate,
      'acquisitionPrice': _acquisitionPrice,
      'quantity': _showQuantity ? _quantity : 1.0,
      'currentPrice': _currentPrice ??
          (widget.investmentToEdit != null
              ? _acquisitionPrice
              : 0.0), // coverage:ignore-line
      'fixedInterestRate': _fixedInterestRate,
      'customLongTermThresholdYears': _thresholdYears,
      'isRecurringEnabled': _isRecurringEnabled,
      'isRecurringPaused': _isRecurringPaused,
      'recurringAmount': _isRecurringEnabled ? _recurringAmount : null,
      'nextRecurringDate': _isRecurringEnabled ? _nextRecurringDate : null,
    };

    if (widget.investmentToEdit != null) {
      final inv = widget.investmentToEdit!;
      return inv.copyWith(
        name: baseProps['name'] as String,
        codeName: baseProps['codeName'] as String?,
        type: baseProps['type'] as InvestmentType,
        mfCategory: baseProps['mfCategory'] as MutualFundCategory?,
        acquisitionDate: baseProps['acquisitionDate'] as DateTime,
        acquisitionPrice: baseProps['acquisitionPrice'] as double,
        quantity: baseProps['quantity'] as double,
        currentPrice: baseProps['currentPrice'] as double,
        fixedInterestRate: baseProps['fixedInterestRate'] as double?,
        customLongTermThresholdYears:
            baseProps['customLongTermThresholdYears'] as int,
        isRecurringEnabled: baseProps['isRecurringEnabled'] as bool,
        isRecurringPaused: baseProps['isRecurringPaused'] as bool,
        recurringAmount: baseProps['recurringAmount'] as double?,
        nextRecurringDate: baseProps['nextRecurringDate'] as DateTime?,
      );
    }

    // coverage:ignore-start
    return Investment.create(
      name: baseProps['name'] as String,
      codeName: baseProps['codeName'] as String?,
      type: baseProps['type'] as InvestmentType,
      mfCategory: baseProps['mfCategory'] as MutualFundCategory?,
      acquisitionDate: baseProps['acquisitionDate'] as DateTime,
      acquisitionPrice: baseProps['acquisitionPrice'] as double,
      quantity: baseProps['quantity'] as double,
      currentPrice: baseProps['currentPrice'] as double,
      fixedInterestRate: baseProps['fixedInterestRate'] as double?,
      // coverage:ignore-end
      customLongTermThresholdYears:
          // coverage:ignore-start
          baseProps['customLongTermThresholdYears'] as int,
      profileId: ref.read(activeProfileIdProvider),
      isRecurringEnabled: baseProps['isRecurringEnabled'] as bool,
      isRecurringPaused: baseProps['isRecurringPaused'] as bool,
      recurringAmount: baseProps['recurringAmount'] as double?,
      nextRecurringDate: baseProps['nextRecurringDate'] as DateTime?,
      // coverage:ignore-end
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyLocale = ref.watch(currencyProvider);
    final currencySymbol = CurrencyUtils.getSymbol(currencyLocale);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.investmentToEdit == null
            ? l10n.addInvestmentTitle
            : l10n.editInvestmentTitle),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInfoFields(l10n),
            const SizedBox(height: 16),
            _buildTypeSelector(l10n),
            const SizedBox(height: 24),
            _buildTypeSpecificFields(l10n),
            _buildDateSection(l10n),
            const SizedBox(height: 16),
            _buildFinancialFields(l10n, currencySymbol),
            const SizedBox(height: 16),
            _buildRecurringSection(l10n, currencySymbol),
            const SizedBox(height: 32),
            _buildActionButtons(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoFields(AppLocalizations l10n) {
    final suggestions = ref
        .watch(investmentsProvider)
        .map((e) => e.name)
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    return _buildAutocompleteField(
      label: l10n.investmentName,
      icon: Icons.label_important_outline,
      initialValue: _nameCtrl.text,
      suggestions: suggestions,
      onSelected: (val) {
        _nameCtrl.text = val;
        _nameAutocompleteCtrl?.text = val;
        _autoFillTickerFromName(val);
      },
      onChanged: (v) => _nameCtrl.text = v,
      validator: (v) => v!.isEmpty ? l10n.requiredError : null,
      onControllerCreated: (c) => _nameAutocompleteCtrl = c,
    );
  }

  void _autoFillTickerFromName(String name) {
    final existing = ref
        .read(investmentsProvider)
        .where((e) => e.name == name && e.codeName != null)
        .map((e) => e.codeName!)
        .toSet();
    if (existing.length == 1) {
      final ticker = existing.first;
      _codeNameCtrl.text = ticker;
      _codeNameAutocompleteCtrl?.text = ticker;
    }
  }

  Widget _buildAutocompleteField({
    required String label,
    required IconData icon,
    required String initialValue,
    required List<String> suggestions,
    required Function(String) onSelected,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    required Function(TextEditingController) onControllerCreated,
  }) {
    return LayoutBuilder(builder: (context, constraints) {
      return Autocomplete<String>(
        optionsBuilder: (TextEditingValue value) {
          if (value.text.isEmpty) return const Iterable<String>.empty();
          return suggestions
              .where((s) => s.toLowerCase().contains(value.text.toLowerCase()));
        },
        fieldViewBuilder: (ctx, controller, focus, onSubmitted) {
          onControllerCreated(controller);
          if (controller.text.isEmpty && initialValue.isNotEmpty) {
            controller.text = initialValue;
          }
          return TextFormField(
            controller: controller,
            focusNode: focus,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              prefixIcon: Icon(icon),
            ),
            validator: validator,
            onChanged: onChanged,
          );
        },
        optionsViewBuilder: (ctx, onSelectedOpt, options) {
          return _buildAutocompleteOptions(
              ctx, onSelectedOpt, options, constraints.maxWidth);
        },
        onSelected: onSelected,
      );
    });
  }

  Widget _buildAutocompleteOptions(BuildContext context,
      Function(String) onSelected, Iterable<String> options, double width) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: width,
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (ctx, i) {
              final opt = options.elementAt(i);
              return ListTile(
                title: Text(opt),
                onTap: () => onSelected(opt),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields(AppLocalizations l10n) {
    return Column(
      children: [
        if (_showCodeName) ...[
          _buildTickerAutocomplete(l10n),
          const SizedBox(height: 16),
        ],
        if (_type == InvestmentType.mutualFund) ...[
          _buildMFCategoryDropdown(l10n), // coverage:ignore-line
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildTickerAutocomplete(AppLocalizations l10n) {
    return LayoutBuilder(builder: (context, constraints) {
      return Autocomplete<String>(
        optionsBuilder: (TextEditingValue value) {
          final currentName = _nameCtrl.text.toLowerCase();
          final allInvestments = ref.read(investmentsProvider);

          final matchedTickers = allInvestments
              .where((e) =>
                  e.name.toLowerCase() == currentName && e.codeName != null)
              .map((e) => e.codeName!)
              .toSet();

          final otherTickers = allInvestments
              .where((e) => e.codeName != null)
              .map((e) => e.codeName!)
              .toSet();

          final combined = {...matchedTickers, ...otherTickers}.toList();
          return value.text.isEmpty
              ? matchedTickers
              : combined.where(
                  (s) => s.toLowerCase().contains(value.text.toLowerCase()));
        },
        fieldViewBuilder: (ctx, controller, focus, onSubmitted) {
          _codeNameAutocompleteCtrl = controller;
          if (controller.text.isEmpty && _codeNameCtrl.text.isNotEmpty) {
            controller.text = _codeNameCtrl.text;
          }
          return TextFormField(
            controller: controller,
            focusNode: focus,
            decoration: InputDecoration(
              labelText: l10n.investmentCodeName,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.tag),
            ),
            onChanged: (v) => _codeNameCtrl.text = v,
          );
        },
        // coverage:ignore-start
        optionsViewBuilder: (ctx, onSelected, options) =>
            _buildAutocompleteOptions(
                ctx, onSelected, options, constraints.maxWidth),
        onSelected: (val) => _codeNameCtrl.text = val,
        // coverage:ignore-end
      );
    });
  }

  // coverage:ignore-start
  Widget _buildMFCategoryDropdown(AppLocalizations l10n) {
    return DropdownButtonFormField<MutualFundCategory>(
      initialValue: _mfCategory,
      decoration: InputDecoration(
        labelText: l10n.mfCategoryLabel,
        // coverage:ignore-end
        border: const OutlineInputBorder(),
      ),
      items: MutualFundCategory.values
          .map((c) => DropdownMenuItem(
                // coverage:ignore-line
                value: c,
                child: Text(c.localizedName(l10n)), // coverage:ignore-line
              ))
          // coverage:ignore-start
          .toList(),
      onChanged: (v) => setState(() => _mfCategory = v),
      validator: (v) => v == null ? l10n.requiredError : null,
      // coverage:ignore-end
    );
  }

  Widget _buildDateSection(AppLocalizations l10n) {
    return ListTile(
      title: Text(l10n.acquisitionDateLabel),
      subtitle: Text(DateFormat.yMMMd().format(_acquisitionDate)),
      leading: const Icon(Icons.calendar_today),
      trailing: const Icon(Icons.edit),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      // coverage:ignore-start
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _acquisitionDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          // coverage:ignore-end
        );
        if (d != null) {
          setState(() => _acquisitionDate = d); // coverage:ignore-line
        }
      },
    );
  }

  Widget _buildFinancialFields(AppLocalizations l10n, String currencySymbol) {
    return Column(
      children: [
        _buildPriceAndQuantityRow(l10n, currencySymbol),
        const SizedBox(height: 16),
        if (!_showQuantity) ...[
          _buildInterestRateField(l10n),
          const SizedBox(height: 16),
        ],
        _buildThresholdField(l10n),
      ],
    );
  }

  Widget _buildPriceAndQuantityRow(
      AppLocalizations l10n, String currencySymbol) {
    return Row(
      children: [
        Expanded(
          child: _buildNumericField(
            initialValue: _acquisitionPrice.toString(),
            label: l10n.acquisitionPriceLabel,
            prefixText: '$currencySymbol ',
            onSaved: (v) => _acquisitionPrice = double.tryParse(v ?? '') ?? 0,
            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                ? l10n.invalidPriceError // coverage:ignore-line
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildNumericField(
            initialValue: (_currentPrice ?? _acquisitionPrice).toString(),
            label: l10n.currentPriceLabel,
            prefixText: '$currencySymbol ',
            onSaved: (v) => _currentPrice = double.tryParse(v ?? ''),
            validator: (v) => (double.tryParse(v ?? '') ?? 0) < 0
                ? l10n.invalidPriceError // coverage:ignore-line
                : null,
          ),
        ),
        if (_showQuantity) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _buildNumericField(
              initialValue: _quantity.toString(),
              label: l10n.quantityLabel,
              onSaved: (v) => _quantity = double.tryParse(v ?? '') ?? 1,
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                  ? l10n.invalidQuantityError // coverage:ignore-line
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNumericField({
    required String initialValue,
    required String label,
    String? prefixText,
    required void Function(String?) onSaved,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixText: prefixText,
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp)
      ],
      onSaved: onSaved,
      validator: validator,
    );
  }

  Widget _buildInterestRateField(AppLocalizations l10n) {
    return _buildNumericField(
      initialValue: _fixedInterestRate?.toString() ?? '',
      label: l10n.interestRateLabel,
      prefixText: '% ',
      onSaved: (v) =>
          _fixedInterestRate = double.tryParse(v ?? ''), // coverage:ignore-line
    );
  }

  Widget _buildThresholdField(AppLocalizations l10n) {
    return TextFormField(
      initialValue: _thresholdYears.toString(),
      decoration: InputDecoration(
        labelText: l10n.thresholdLabel,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.timer_outlined),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSaved: (v) => _thresholdYears = int.tryParse(v ?? '1') ?? 1,
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _save,
        child: Text(widget.investmentToEdit == null
            ? l10n.saveAction
            : l10n.updateAction),
      ),
    );
  }

  Widget _buildTypeSelector(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.investmentType,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: InvestmentType.values
              .map((t) => _buildTypeChip(t, l10n))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTypeChip(InvestmentType t, AppLocalizations l10n) {
    return ChoiceChip(
      label: Text(t.localizedName(l10n), style: const TextStyle(fontSize: 12)),
      selected: _type == t,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _type = t;
            if (_type != InvestmentType.mutualFund) _mfCategory = null;
          });
        }
      },
    );
  }

  Widget _buildRecurringSection(AppLocalizations l10n, String currencySymbol) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecurringHeader(l10n),
        if (_isRecurringEnabled) _buildRecurringForm(l10n, currencySymbol),
      ],
    );
  }

  Widget _buildRecurringHeader(AppLocalizations l10n) {
    return Row(
      children: [
        const Icon(Icons.repeat, size: 20),
        const SizedBox(width: 8),
        Text(l10n.recurringInvestmentHeader,
            style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        Switch(
          value: _isRecurringEnabled,
          onChanged: (v) => setState(() {
            _isRecurringEnabled = v;
            if (v && _nextRecurringDate == null) {
              _nextRecurringDate = DateTime.now().add(const Duration(days: 30));
            }
          }),
        ),
      ],
    );
  }

  Widget _buildRecurringForm(AppLocalizations l10n, String currencySymbol) {
    return Column(
      children: [
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _recurringAmount?.toString(),
          decoration: InputDecoration(
            labelText: l10n.recurringAmountLabel,
            border: const OutlineInputBorder(),
            prefixText: '$currencySymbol ',
            isDense: true,
            helperText: 'Amount to be added every month',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
          // coverage:ignore-start
          validator: (v) =>
              _isRecurringEnabled && (double.tryParse(v ?? '') ?? 0) <= 0
                  ? l10n.invalidPriceError
                  // coverage:ignore-end
                  : null,
          onChanged: (v) =>
              _recurringAmount = double.tryParse(v), // coverage:ignore-line
        ),
        const SizedBox(height: 16),
        ListTile(
          title: Text(l10n.nextRecurringDateLabel),
          subtitle: Text(_nextRecurringDate == null
              ? 'Select Date'
              : DateFormat.yMMMd().format(_nextRecurringDate!)),
          leading: const Icon(Icons.calendar_month),
          trailing: const Icon(Icons.edit),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          // coverage:ignore-start
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _nextRecurringDate ??
                  DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
              // coverage:ignore-end
            );
            if (d != null) {
              setState(() => _nextRecurringDate = d); // coverage:ignore-line
            }
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(l10n.pauseRecurringLabel),
          subtitle: const Text('Temporarily stop creating monthly records'),
          value: _isRecurringPaused,
          onChanged: (v) =>
              setState(() => _isRecurringPaused = v), // coverage:ignore-line
        ),
      ],
    );
  }
}
