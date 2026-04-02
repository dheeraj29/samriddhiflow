import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../feature_providers.dart';
import '../providers.dart';
import '../models/investment.dart';
import '../l10n/app_localizations.dart';
import '../utils/regex_utils.dart';

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
  }

  bool get _showCodeName =>
      _type == InvestmentType.stock || _type == InvestmentType.mutualFund;
  bool get _showQuantity =>
      _type != InvestmentType.fixedSavings &&
      _type != InvestmentType.otherFixed;

  // coverage:ignore-start
  void _save() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final investment = _prepareInvestment();
      ref.read(investmentsProvider.notifier).saveInvestment(investment);
      Navigator.pop(context);
      // coverage:ignore-end
    }
  }

  // coverage:ignore-start
  Investment _prepareInvestment() {
    if (widget.investmentToEdit != null) {
      return widget.investmentToEdit!.copyWith(
        name: _name,
        codeName: _codeName,
        type: _type,
        mfCategory: _type == InvestmentType.mutualFund ? _mfCategory : null,
        acquisitionDate: _acquisitionDate,
        acquisitionPrice: _acquisitionPrice,
        quantity: _showQuantity ? _quantity : 1.0,
        currentPrice: _currentPrice ?? _acquisitionPrice,
        fixedInterestRate: _fixedInterestRate,
        customLongTermThresholdYears: _thresholdYears,
        isRecurringEnabled: _isRecurringEnabled,
        isRecurringPaused: _isRecurringPaused,
        recurringAmount: _isRecurringEnabled ? _recurringAmount : null,
        nextRecurringDate: _isRecurringEnabled ? _nextRecurringDate : null,
        // coverage:ignore-end
      );
    }

    // coverage:ignore-start
    return Investment.create(
      name: _name,
      codeName: _codeName,
      type: _type,
      mfCategory: _type == InvestmentType.mutualFund ? _mfCategory : null,
      acquisitionDate: _acquisitionDate,
      acquisitionPrice: _acquisitionPrice,
      quantity: _showQuantity ? _quantity : 1.0,
      currentPrice: _currentPrice ?? 0.0,
      fixedInterestRate: _fixedInterestRate,
      customLongTermThresholdYears: _thresholdYears,
      profileId: ref.read(activeProfileIdProvider),
      isRecurringEnabled: _isRecurringEnabled,
      isRecurringPaused: _isRecurringPaused,
      recurringAmount: _isRecurringEnabled ? _recurringAmount : null,
      nextRecurringDate: _isRecurringEnabled ? _nextRecurringDate : null,
      // coverage:ignore-end
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
            _buildFinancialFields(l10n),
            const SizedBox(height: 16),
            _buildRecurringSection(l10n),
            const SizedBox(height: 32),
            _buildActionButtons(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoFields(AppLocalizations l10n) {
    return TextFormField(
      initialValue: _name,
      decoration: InputDecoration(
        labelText: l10n.investmentName,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.label_important_outline),
      ),
      validator: (v) =>
          v!.isEmpty ? l10n.requiredError : null, // coverage:ignore-line
      onSaved: (v) => _name = v!, // coverage:ignore-line
    );
  }

  Widget _buildTypeSpecificFields(AppLocalizations l10n) {
    return Column(
      children: [
        if (_showCodeName) ...[
          TextFormField(
            initialValue: _codeName,
            decoration: InputDecoration(
              labelText: l10n.investmentCodeName,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.tag),
            ),
            onSaved: (v) => _codeName = v, // coverage:ignore-line
          ),
          const SizedBox(height: 16),
        ],
        if (_type == InvestmentType.mutualFund) ...[
          // coverage:ignore-start
          DropdownButtonFormField<MutualFundCategory>(
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
                      child:
                          Text(c.localizedName(l10n)), // coverage:ignore-line
                    ))
                // coverage:ignore-start
                .toList(),
            onChanged: (v) => setState(() => _mfCategory = v),
            validator: (v) => v == null ? l10n.requiredError : null,
            // coverage:ignore-end
          ),
          const SizedBox(height: 16),
        ],
      ],
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

  Widget _buildFinancialFields(AppLocalizations l10n) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _acquisitionPrice.toString(),
                decoration: InputDecoration(
                  labelText: l10n.acquisitionPriceLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegexUtils.amountExp)
                ],
                // coverage:ignore-start
                onSaved: (v) =>
                    _acquisitionPrice = double.tryParse(v ?? '') ?? 0,
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                    ? l10n.invalidPriceError
                    // coverage:ignore-end
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: (_currentPrice ?? _acquisitionPrice).toString(),
                decoration: InputDecoration(
                  labelText: l10n.currentPriceLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegexUtils.amountExp)
                ],
                // coverage:ignore-start
                onSaved: (v) => _currentPrice = double.tryParse(v ?? ''),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) < 0
                    ? l10n.invalidPriceError
                    // coverage:ignore-end
                    : null,
              ),
            ),
            if (_showQuantity) ...[
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: _quantity.toString(),
                  decoration: InputDecoration(
                    labelText: l10n.quantityLabel,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegexUtils.amountExp)
                  ],
                  // coverage:ignore-start
                  onSaved: (v) => _quantity = double.tryParse(v ?? '') ?? 1,
                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                      ? l10n.invalidQuantityError
                      // coverage:ignore-end
                      : null,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (!_showQuantity) ...[
          TextFormField(
            initialValue: _fixedInterestRate?.toString(),
            decoration: InputDecoration(
              labelText: l10n.interestRateLabel,
              helperText: l10n.notAutoCalculated,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.percent),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp)
            ],
            onSaved: (v) => _fixedInterestRate =
                double.tryParse(v ?? ''), // coverage:ignore-line
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          initialValue: _thresholdYears.toString(),
          decoration: InputDecoration(
            labelText: l10n.thresholdLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.timer_outlined),
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSaved: (v) => _thresholdYears =
              int.tryParse(v ?? '1') ?? 1, // coverage:ignore-line
        ),
      ],
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

  Widget _buildRecurringSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecurringHeader(l10n),
        if (_isRecurringEnabled) _buildRecurringForm(l10n),
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

  Widget _buildRecurringForm(AppLocalizations l10n) {
    return Column(
      children: [
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _recurringAmount?.toString(),
          decoration: InputDecoration(
            labelText: l10n.recurringAmountLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.currency_rupee),
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
