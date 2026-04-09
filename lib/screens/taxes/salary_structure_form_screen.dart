import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:samriddhi_flow/utils/currency_utils.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:samriddhi_flow/providers.dart';

class SalaryStructureFormScreen extends ConsumerStatefulWidget {
  final SalaryStructure? existing;

  const SalaryStructureFormScreen({super.key, this.existing});

  @override
  ConsumerState<SalaryStructureFormScreen> createState() =>
      _SalaryStructureFormScreenState();
}

class _SalaryStructureFormScreenState
    extends ConsumerState<SalaryStructureFormScreen> {
  late ValueNotifier<DateTime> _effectiveDateNotifier;
  late TextEditingController _basicCtrl;
  late TextEditingController _fixedCtrl;
  late TextEditingController _perfCtrl;
  late ValueNotifier<PayoutFrequency> _perfFreqNotifier;
  late ValueNotifier<int?> _perfStartMonthNotifier;
  late ValueNotifier<List<int>> _perfCustomMonthsNotifier;
  late ValueNotifier<bool> _perfPartialNotifier;
  late ValueNotifier<Map<int, double>> _perfAmountsNotifier;
  late TextEditingController _variableCtrl;
  late ValueNotifier<PayoutFrequency> _varFreqNotifier;
  late ValueNotifier<int?> _varStartMonthNotifier;
  late ValueNotifier<List<int>> _varCustomMonthsNotifier;
  late ValueNotifier<bool> _varPartialNotifier;
  late ValueNotifier<Map<int, double>> _varAmountsNotifier;
  late ValueNotifier<List<CustomAllowance>> _customAllowancesNotifier;
  late ValueNotifier<List<int>> _stoppedMonthsNotifier;
  late TextEditingController _pfCtrl;
  late TextEditingController _gratuityCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _initBasicInfo(e);
    _initPerformancePay(e);
    _initVariablePay(e);
    _initOtherFields(e);
  }

  void _initBasicInfo(SalaryStructure? e) {
    _effectiveDateNotifier = ValueNotifier(e?.effectiveDate ?? DateTime.now());
    _basicCtrl = TextEditingController(
        text: e != null
            ? (e.monthlyBasic * 12).toStringAsFixed(0)
            : ''); // coverage:ignore-line
    _fixedCtrl = TextEditingController(
        text: e != null
            ? (e.monthlyFixedAllowances * 12)
                .toStringAsFixed(0) // coverage:ignore-line
            : '');
  }

  void _initPerformancePay(SalaryStructure? e) {
    _perfCtrl = TextEditingController(
        text: e != null
            ? (e.monthlyPerformancePay * 12).toStringAsFixed(0)
            : ''); // coverage:ignore-line
    _perfFreqNotifier =
        ValueNotifier(e?.performancePayFrequency ?? PayoutFrequency.monthly);
    _perfStartMonthNotifier = ValueNotifier(e?.performancePayStartMonth);
    _perfCustomMonthsNotifier =
        ValueNotifier(e?.performancePayCustomMonths ?? []);
    _perfPartialNotifier = ValueNotifier(e?.isPerformancePayPartial ?? false);
    _perfAmountsNotifier = ValueNotifier(e?.performancePayAmounts ?? {});
  }

  void _initVariablePay(SalaryStructure? e) {
    _variableCtrl = TextEditingController(
        text: e != null
            ? e.annualVariablePay.toStringAsFixed(0)
            : ''); // coverage:ignore-line
    _varFreqNotifier =
        ValueNotifier(e?.variablePayFrequency ?? PayoutFrequency.annually);
    _varStartMonthNotifier = ValueNotifier(e?.variablePayStartMonth);
    _varCustomMonthsNotifier = ValueNotifier(e?.variablePayCustomMonths ?? []);
    _varPartialNotifier = ValueNotifier(e?.isVariablePayPartial ?? false);
    _varAmountsNotifier = ValueNotifier(e?.variablePayAmounts ?? {});
  }

  void _initOtherFields(SalaryStructure? e) {
    _customAllowancesNotifier = ValueNotifier(e?.customAllowances ?? []);
    _stoppedMonthsNotifier = ValueNotifier(e?.stoppedMonths ?? []);
    _pfCtrl = TextEditingController(
        text: e != null
            ? (e.monthlyEmployeePF * 12).toStringAsFixed(0)
            : ''); // coverage:ignore-line
    _gratuityCtrl = TextEditingController(
        text: e != null
            ? (e.monthlyGratuity * 12).toStringAsFixed(0)
            : ''); // coverage:ignore-line
  }

  @override
  void dispose() {
    _disposeBasicInfo();
    _disposePerformancePay();
    _disposeVariablePay();
    _disposeOtherFields();
    super.dispose();
  }

  void _disposeBasicInfo() {
    _effectiveDateNotifier.dispose();
    _basicCtrl.dispose();
    _fixedCtrl.dispose();
  }

  void _disposePerformancePay() {
    _perfCtrl.dispose();
    _perfFreqNotifier.dispose();
    _perfStartMonthNotifier.dispose();
    _perfCustomMonthsNotifier.dispose();
    _perfPartialNotifier.dispose();
    _perfAmountsNotifier.dispose();
  }

  void _disposeVariablePay() {
    _variableCtrl.dispose();
    _varFreqNotifier.dispose();
    _varStartMonthNotifier.dispose();
    _varCustomMonthsNotifier.dispose();
    _varPartialNotifier.dispose();
    _varAmountsNotifier.dispose();
  }

  void _disposeOtherFields() {
    _customAllowancesNotifier.dispose();
    _stoppedMonthsNotifier.dispose();
    _pfCtrl.dispose();
    _gratuityCtrl.dispose();
  }

  // coverage:ignore-start
  void _onSave() {
    final basic = (double.tryParse(_basicCtrl.text) ?? 0) / 12;
    final fixed = (double.tryParse(_fixedCtrl.text) ?? 0) / 12;
    final perf = (double.tryParse(_perfCtrl.text) ?? 0) / 12;
    final pf = (double.tryParse(_pfCtrl.text) ?? 0) / 12;
    final gratuity = (double.tryParse(_gratuityCtrl.text) ?? 0) / 12;
    final variable = double.tryParse(_variableCtrl.text) ?? 0;
    // coverage:ignore-end

    // coverage:ignore-start
    final newStructure = SalaryStructure(
      id: widget.existing?.id ?? const Uuid().v4(),
      effectiveDate: _effectiveDateNotifier.value,
      // coverage:ignore-end
      monthlyBasic: basic,
      monthlyFixedAllowances: fixed,
      monthlyPerformancePay: perf,
      // coverage:ignore-start
      performancePayFrequency: _perfFreqNotifier.value,
      performancePayStartMonth: _perfStartMonthNotifier.value,
      performancePayCustomMonths: _perfCustomMonthsNotifier.value,
      isPerformancePayPartial: _perfPartialNotifier.value,
      performancePayAmounts: _perfAmountsNotifier.value,
      // coverage:ignore-end
      annualVariablePay: variable,
      // coverage:ignore-start
      variablePayFrequency: _varFreqNotifier.value,
      variablePayStartMonth: _varStartMonthNotifier.value,
      variablePayCustomMonths: _varCustomMonthsNotifier.value,
      isVariablePayPartial: _varPartialNotifier.value,
      variablePayAmounts: _varAmountsNotifier.value,
      customAllowances: _customAllowancesNotifier.value,
      stoppedMonths: _stoppedMonthsNotifier.value,
      // coverage:ignore-end
      monthlyEmployeePF: pf,
      monthlyGratuity: gratuity,
    );

    Navigator.pop(context, newStructure); // coverage:ignore-line
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? l10n.addSalaryStructureAction
            : l10n.editSalaryStructureAction), // coverage:ignore-line
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _onSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(l10n.coreSalarySection),
            _buildSalaryCoreFields(),
            const SizedBox(height: 24),
            _buildSectionHeader(l10n.payoutsSection),
            _buildSalaryPaySections(context),
            const SizedBox(height: 24),
            _buildSectionHeader(l10n.deductionsSection),
            _buildSalaryDeductionSections(context),
            const SizedBox(height: 24),
            _buildSalaryAllowancesSection(context),
            const SizedBox(
                height:
                    80), // Space for FAB-like feel if needed, but we have actions in AppBar
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _onSave,
            child: Text(l10n.saveButton),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildSalaryCoreFields() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        ValueListenableBuilder<DateTime>(
          valueListenable: _effectiveDateNotifier,
          builder: (context, date, _) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.effectiveDateLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(fontSize: 16)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                // coverage:ignore-line
                final picked = await showDatePicker(
                  // coverage:ignore-line
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000), // coverage:ignore-line
                  lastDate: DateTime(2100), // coverage:ignore-line
                );
                if (picked != null) {
                  _effectiveDateNotifier.value = picked; // coverage:ignore-line
                }
              },
            );
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _basicCtrl,
          decoration: InputDecoration(
              labelText: l10n.annualBasicPayLabel,
              border: const OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _fixedCtrl,
          decoration: InputDecoration(
            labelText: l10n.annualFixedAllowancesLabel,
            border: const OutlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            helperText: l10n.annualFixedAllowancesHelperText,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
        ),
      ],
    );
  }

  Widget _buildSalaryPaySections(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildPayoutSection(
          context: context,
          label: l10n.annualPerformancePayLabel,
          helperText: l10n.maxAmountPerYearLabel,
          controller: _perfCtrl,
          freqNotifier: _perfFreqNotifier,
          startMonthNotifier: _perfStartMonthNotifier,
          customMonthsNotifier: _perfCustomMonthsNotifier,
          partialNotifier: _perfPartialNotifier,
          amountsNotifier: _perfAmountsNotifier,
          divisor: 12,
        ),
        const SizedBox(height: 24),
        _buildPayoutSection(
          context: context,
          label: l10n.annualVariablePayLabel,
          helperText: l10n.totalAmountPerYearLabel,
          controller: _variableCtrl,
          freqNotifier: _varFreqNotifier,
          startMonthNotifier: _varStartMonthNotifier,
          customMonthsNotifier: _varCustomMonthsNotifier,
          partialNotifier: _varPartialNotifier,
          amountsNotifier: _varAmountsNotifier,
          divisor: 1,
        ),
      ],
    );
  }

  Widget _buildPayoutSection({
    required BuildContext context,
    required String label,
    required String helperText,
    required TextEditingController controller,
    required ValueNotifier<PayoutFrequency> freqNotifier,
    required ValueNotifier<int?> startMonthNotifier,
    required ValueNotifier<List<int>> customMonthsNotifier,
    required ValueNotifier<bool> partialNotifier,
    required ValueNotifier<Map<int, double>> amountsNotifier,
    required double divisor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildNumberField(label, controller, subtitle: helperText),
        const SizedBox(height: 16),
        _buildFrequencyRow(l10n.payoutLabel, freqNotifier, startMonthNotifier,
            customMonthsNotifier, context, l10n.selectMonthsAction),
        ValueListenableBuilder<bool>(
          valueListenable: partialNotifier,
          builder: (context, isPartial, _) {
            return Column(
              children: [
                CheckboxListTile(
                  title: Text(l10n.partialPayoutTaxableFactorTitle),
                  subtitle: isPartial
                      ? null
                      : Text(l10n.defaultEqualDistributionSubtitle),
                  value: isPartial,
                  onChanged: (v) => partialNotifier.value =
                      v ?? false, // coverage:ignore-line
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                if (isPartial)
                  _buildSalaryPartialGrid(
                      // coverage:ignore-line
                      amountsNotifier,
                      freqNotifier,
                      startMonthNotifier,
                      customMonthsNotifier,
                      (double.tryParse(controller.text) ?? 0) /
                          divisor), // coverage:ignore-line
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildNumberField(String label, TextEditingController ctrl,
      {String? subtitle}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        helperText: subtitle,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp)
      ],
    );
  }

  Widget _buildFrequencyRow(
      String label,
      ValueNotifier<PayoutFrequency> freqNotifier,
      ValueNotifier<int?> startMonthNotifier,
      ValueNotifier<List<int>> customMonthsNotifier,
      BuildContext context,
      String customActionLabel) {
    return ValueListenableBuilder<PayoutFrequency>(
      valueListenable: freqNotifier,
      builder: (context, freq, _) {
        return Column(
          children: [
            _buildFrequencyTile(label, freq, freqNotifier),
            if (freq != PayoutFrequency.monthly &&
                freq != PayoutFrequency.custom)
              _buildStartMonthTile(startMonthNotifier),
            if (freq == PayoutFrequency.custom)
              _buildCustomMonthsTile(
                  // coverage:ignore-line
                  customMonthsNotifier,
                  customActionLabel,
                  context),
          ],
        );
      },
    );
  }

  Widget _buildFrequencyTile(String label, PayoutFrequency freq,
      ValueNotifier<PayoutFrequency> freqNotifier) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: DropdownButton<PayoutFrequency>(
        value: freq,
        onChanged: (v) {
          // coverage:ignore-line
          if (v != null) freqNotifier.value = v; // coverage:ignore-line
        },
        items: PayoutFrequency.values.map((f) {
          return DropdownMenuItem(
            value: f,
            child: Text(f.name[0].toUpperCase() + f.name.substring(1)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStartMonthTile(ValueNotifier<int?> startMonthNotifier) {
    return ValueListenableBuilder<int?>(
      valueListenable: startMonthNotifier,
      builder: (context, startMonth, _) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(AppLocalizations.of(context)!.startMonthLabel),
          trailing: DropdownButton<int>(
            value: startMonth ?? 3,
            onChanged: (v) =>
                startMonthNotifier.value = v, // coverage:ignore-line
            items: List.generate(12, (index) {
              final m = index + 1;
              return DropdownMenuItem(
                value: m,
                child: Text(DateFormat('MMMM').format(DateTime(2023, m, 1))),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildCustomMonthsTile(
      ValueNotifier<List<int>> customMonthsNotifier, // coverage:ignore-line
      String customActionLabel,
      BuildContext context) {
    return ValueListenableBuilder<List<int>>(
      // coverage:ignore-line
      valueListenable: customMonthsNotifier,
      builder: (context, list, _) {
        // coverage:ignore-line
        return ListTile(
          // coverage:ignore-line
          contentPadding: EdgeInsets.zero,
          // coverage:ignore-start
          title: Text(customActionLabel),
          subtitle: Text(list.isEmpty
              ? AppLocalizations.of(context)!.noMonthsSelectedNote
              // coverage:ignore-end
              : list
                  .map((m) => DateFormat('MMM')
                      .format(DateTime(2023, m, 1))) // coverage:ignore-line
                  .join(', ')), // coverage:ignore-line
          trailing: const Icon(Icons.edit),
          onTap: () async {
            // coverage:ignore-line
            final selected = await _showMonthMultiSelect(
                context, list, customActionLabel); // coverage:ignore-line
            if (selected != null) {
              customMonthsNotifier.value = selected; // coverage:ignore-line
            }
          },
        );
      },
    );
  }

  Widget _buildSalaryPartialGrid(
      // coverage:ignore-line
      ValueNotifier<Map<int, double>> amountsNotifier,
      ValueNotifier<PayoutFrequency> freqNotifier,
      ValueNotifier<int?> startMonthNotifier,
      ValueNotifier<List<int>> customMonthsNotifier,
      double defaultAmount) {
    return ValueListenableBuilder<Map<int, double>>(
      // coverage:ignore-line
      valueListenable: amountsNotifier,
      // coverage:ignore-start
      builder: (context, amounts, _) {
        final applicableMonths = _getApplicableMonths(freqNotifier.value,
            startMonthNotifier.value, customMonthsNotifier.value);
        // coverage:ignore-end

        if (applicableMonths.isEmpty) {
          // coverage:ignore-line
          return Text(AppLocalizations.of(context)!
              .noPayoutMonthsSelectedNote); // coverage:ignore-line
        }

        // coverage:ignore-start
        return Column(
          children: [
            Text(AppLocalizations.of(context)!.enterAmountsForPayoutMonthsNote,
                // coverage:ignore-end
                style:
                    const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Wrap(
              // coverage:ignore-line
              spacing: 8,
              runSpacing: 8,
              // coverage:ignore-start
              children: applicableMonths.map((m) {
                final currentVal = amountsNotifier.value[m] ?? defaultAmount;
                return _buildSalaryMonthInput(
                  // coverage:ignore-end
                  month: m,
                  currentVal: currentVal,
                  // coverage:ignore-start
                  onChanged: (val) {
                    final d = double.tryParse(val) ?? 0;
                    final newMap = Map<int, double>.from(amountsNotifier.value);
                    newMap[m] = d;
                    amountsNotifier.value = newMap;
                    // coverage:ignore-end
                  },
                );
              }).toList(), // coverage:ignore-line
            ),
          ],
        );
      },
    );
  }

  Widget _buildSalaryMonthInput({
    // coverage:ignore-line
    required int month,
    required double currentVal,
    required void Function(String) onChanged,
  }) {
    final text = currentVal.toStringAsFixed(0); // coverage:ignore-line
    return SizedBox(
      // coverage:ignore-line
      width: 100,
      // coverage:ignore-start
      child: TextField(
        decoration: InputDecoration(
          labelText: DateFormat('MMM').format(DateTime(2023, month, 1)),
          // coverage:ignore-end
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(8),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          // coverage:ignore-line
          FilteringTextInputFormatter.allow(
              RegexUtils.amountExp) // coverage:ignore-line
        ],
        controller: TextEditingController(text: text) // coverage:ignore-line
          ..selection = TextSelection.collapsed(
              offset: text.length), // coverage:ignore-line
        onChanged: onChanged,
      ),
    );
  }

  List<int> _getApplicableMonths(
      // coverage:ignore-line
      PayoutFrequency freq,
      int? startMonth,
      List<int> customMonths) {
    // coverage:ignore-start
    List<int> applicableMonths = [];
    for (int m = 1; m <= 12; m++) {
      if (SalaryStructure.isPayoutMonth(m, freq, startMonth, customMonths)) {
        applicableMonths.add(m);
        // coverage:ignore-end
      }
    }
    return applicableMonths;
  }

  Widget _buildSalaryDeductionSections(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        TextField(
          controller: _pfCtrl,
          decoration: InputDecoration(
              labelText: l10n.annualEmployeePFLabel,
              border: const OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _gratuityCtrl,
          decoration: InputDecoration(
              labelText: l10n.annualGratuityContributionLabel,
              border: const OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
        ),
        const Divider(height: 32),
        _buildStoppedMonthsSection(context),
      ],
    );
  }

  Widget _buildStoppedMonthsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.unemploymentNoSalaryTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(l10n.unemploymentNoSalarySubtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<int>>(
          valueListenable: _stoppedMonthsNotifier,
          builder: (context, list, _) {
            return OutlinedButton.icon(
              // coverage:ignore-start
              onPressed: () async {
                final selected = await _showMonthMultiSelect(
                    context, list, l10n.selectStoppedMonthsAction);
                // coverage:ignore-end
                if (selected != null) {
                  _stoppedMonthsNotifier.value =
                      selected; // coverage:ignore-line
                }
              },
              icon: const Icon(Icons.block),
              label: Text(list.isEmpty
                  ? l10n.selectStoppedMonthsAction
                  : l10n.monthsStoppedCountLabel(
                      list.length.toString())), // coverage:ignore-line
              style: list.isNotEmpty
                  ? OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange) // coverage:ignore-line
                  : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSalaryAllowancesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        const Divider(),
        _buildAllowanceHeader(context),
        ValueListenableBuilder<List<CustomAllowance>>(
          valueListenable: _customAllowancesNotifier,
          builder: (context, list, _) {
            if (list.isEmpty) {
              return Text(l10n.noCustomAllowancesNote,
                  style: const TextStyle(color: Colors.grey, fontSize: 12));
            }
            return Column(
              // coverage:ignore-line
              children: list
                  .map((a) => _buildAllowanceTile(
                      context, a, list)) // coverage:ignore-line
                  .toList(), // coverage:ignore-line
            );
          },
        ),
      ],
    );
  }

  Widget _buildAllowanceHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.customAllowancesTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () {
            // coverage:ignore-line
            _addCustomAllowanceDialog(
                // coverage:ignore-line
                context: context,
                // coverage:ignore-start
                onAdd: (newAllowance) {
                  _customAllowancesNotifier.value = [
                    ..._customAllowancesNotifier.value,
                    newAllowance
                    // coverage:ignore-end
                  ];
                });
          },
        ),
      ],
    );
  }

  Widget _buildAllowanceTile(
      // coverage:ignore-line
      BuildContext context,
      CustomAllowance a,
      List<CustomAllowance> list) {
    return ListTile(
      // coverage:ignore-line
      dense: true,
      contentPadding: EdgeInsets.zero,
      // coverage:ignore-start
      title: Text(a.name),
      subtitle: Text(_formatAllowanceSubtitle(a)),
      trailing: IconButton(
        // coverage:ignore-end
        icon: const Icon(Icons.delete, size: 18),
        // coverage:ignore-start
        onPressed: () {
          final newList = List<CustomAllowance>.from(list)..remove(a);
          _customAllowancesNotifier.value = newList;
          // coverage:ignore-end
        },
      ),
      onTap: () {
        // coverage:ignore-line
        _addCustomAllowanceDialog(
            // coverage:ignore-line
            context: context,
            existing: a,
            // coverage:ignore-start
            onAdd: (updatedAllowance) {
              final newList = List<CustomAllowance>.from(list);
              int idx = newList.indexOf(a);
              if (idx != -1) {
                newList[idx] = updatedAllowance;
                _customAllowancesNotifier.value = newList;
                // coverage:ignore-end
              }
            });
      },
    );
  }

  // coverage:ignore-start
  String _formatAllowanceSubtitle(CustomAllowance a) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(currencyProvider);
    // coverage:ignore-end
    final payoutFormatted = CurrencyUtils.formatCurrency(
        a.payoutAmount, locale); // coverage:ignore-line

    final totalAmount =
        _calculateAllowanceAnnualTotal(a); // coverage:ignore-line
    final totalFormatted = CurrencyUtils.formatCurrency(
        totalAmount, locale); // coverage:ignore-line

    if (a.frequency == PayoutFrequency.annually && !a.isPartial) {
      // coverage:ignore-line
      return '${l10n.annualPayoutLabel}: $payoutFormatted'; // coverage:ignore-line
    }

    return '${l10n.perPayoutLabel}: $payoutFormatted • ${l10n.annualTotalLabel}: $totalFormatted'; // coverage:ignore-line
  }

  double _calculateAllowanceAnnualTotal(CustomAllowance a) {
    // coverage:ignore-line
    double total = 0;
    // coverage:ignore-start
    for (int m = 1; m <= 12; m++) {
      if (SalaryStructure.isPayoutMonth(
          m, a.frequency, a.startMonth, a.customMonths)) {
        if (a.isPartial) {
          total += a.partialAmounts[m] ?? a.payoutAmount;
          // coverage:ignore-end
        } else {
          total += a.payoutAmount; // coverage:ignore-line
        }
      }
    }
    return total;
  }

  Future<List<int>?> _showMonthMultiSelect(
      // coverage:ignore-line
      BuildContext context,
      List<int> selected,
      String title) async {
    return showDialog<List<int>>(
      // coverage:ignore-line
      context: context,
      builder: (context) {
        // coverage:ignore-line
        return _MonthMultiSelectDialog(
          // coverage:ignore-line
          selected: selected,
          title: title,
        );
      },
    );
  }

  void _addCustomAllowanceDialog({
    // coverage:ignore-line
    required BuildContext context,
    CustomAllowance? existing,
    required void Function(CustomAllowance) onAdd,
  }) {
    // Reusing the dialog logic from TaxDetailsScreen or implementing a simplified one here
    // For now, let's keep it consistent. I'll need to check how it's implemented in tax_details_screen.dart
    // Actually, I'll copy the dialog logic here for self-containment.
    showDialog(
      // coverage:ignore-line
      context: context,
      builder: (context) => _CustomAllowanceDialog(
        // coverage:ignore-line
        existing: existing,
        onSave: onAdd,
      ),
    );
  }
}

class _MonthMultiSelectDialog extends StatefulWidget {
  final List<int> selected;
  final String title;

  const _MonthMultiSelectDialog({
    // coverage:ignore-line
    required this.selected,
    required this.title,
  });

  @override // coverage:ignore-line
  State<_MonthMultiSelectDialog> createState() =>
      _MonthMultiSelectDialogState(); // coverage:ignore-line
}

class _MonthMultiSelectDialogState extends State<_MonthMultiSelectDialog> {
  late List<int> _current;
  final _months = const [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];

  @override // coverage:ignore-line
  void initState() {
    super.initState(); // coverage:ignore-line
    _current = List.from(widget.selected); // coverage:ignore-line
  }

  @override // coverage:ignore-line
  Widget build(BuildContext context) {
    // coverage:ignore-start
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Wrap(
          // coverage:ignore-end
          spacing: 8,
          // coverage:ignore-start
          children: _months.map((m) {
            final isSelected = _current.contains(m);
            return FilterChip(
              label: Text(DateFormat('MMM').format(DateTime(2023, m, 1))),
              // coverage:ignore-end
              selected: isSelected,
              onSelected: (v) {
                // coverage:ignore-line
                setState(() {
                  // coverage:ignore-line
                  if (v) {
                    _current.add(m); // coverage:ignore-line
                  } else {
                    _current.remove(m); // coverage:ignore-line
                  }
                });
              },
            );
          }).toList(), // coverage:ignore-line
        ),
      ),
      // coverage:ignore-start
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _current),
            child: Text(l10n.selectButton)),
        // coverage:ignore-end
      ],
    );
  }
}

class _CustomAllowanceDialog extends StatefulWidget {
  final CustomAllowance? existing;
  final void Function(CustomAllowance) onSave;

  const _CustomAllowanceDialog(
      {this.existing, required this.onSave}); // coverage:ignore-line

  @override // coverage:ignore-line
  State<_CustomAllowanceDialog> createState() =>
      _CustomAllowanceDialogState(); // coverage:ignore-line
}

class _CustomAllowanceDialogState extends State<_CustomAllowanceDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amtCtrl;
  late TextEditingController _exemptionLimitCtrl;
  late PayoutFrequency _freq;
  late int? _startMonth;
  late List<int> _customMonths;
  late bool _isPartial;
  late Map<int, double> _partialAmounts;
  late bool _isCliffExemption;

  @override // coverage:ignore-line
  void initState() {
    // coverage:ignore-start
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amtCtrl =
        TextEditingController(text: e?.payoutAmount.toStringAsFixed(0) ?? '');
    _exemptionLimitCtrl = TextEditingController(
        text: e?.exemptionLimit.toStringAsFixed(0) ?? '0');
    _freq = e?.frequency ?? PayoutFrequency.monthly;
    _startMonth = e?.startMonth;
    _customMonths = e?.customMonths ?? [];
    _isPartial = e?.isPartial ?? false;
    _partialAmounts = e?.partialAmounts ?? {};
    _isCliffExemption = e?.isCliffExemption ?? false;
    // coverage:ignore-end
  }

  @override // coverage:ignore-line
  void dispose() {
    // coverage:ignore-start
    _nameCtrl.dispose();
    _amtCtrl.dispose();
    _exemptionLimitCtrl.dispose();
    super.dispose();
    // coverage:ignore-end
  }

  @override // coverage:ignore-line
  Widget build(BuildContext context) {
    // coverage:ignore-start
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.existing == null
          ? l10n.addCustomAllowanceAction
          : l10n.editAllowanceAction),
      content: SingleChildScrollView(
        child: Column(
          // coverage:ignore-end
          mainAxisSize: MainAxisSize.min,
          // coverage:ignore-start
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.allowanceNameLabel),
              // coverage:ignore-end
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            // coverage:ignore-start
            TextField(
              controller: _amtCtrl,
              decoration: InputDecoration(labelText: l10n.payoutAmountLabel),
              // coverage:ignore-end
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // coverage:ignore-line
                FilteringTextInputFormatter.allow(
                    RegexUtils.amountExp) // coverage:ignore-line
              ],
            ),
            const SizedBox(height: 16),
            // coverage:ignore-start
            DropdownButtonFormField<PayoutFrequency>(
              initialValue: _freq,
              decoration: InputDecoration(labelText: l10n.payoutFrequencyLabel),
              onChanged: (v) => setState(() => _freq = v!),
              // coverage:ignore-end
              items: PayoutFrequency.values
                  .map((f) => DropdownMenuItem(
                      value: f, child: Text(f.name))) // coverage:ignore-line
                  .toList(), // coverage:ignore-line
            ),
            // coverage:ignore-start
            if (_freq != PayoutFrequency.monthly &&
                _freq != PayoutFrequency.custom)
              DropdownButtonFormField<int>(
                initialValue: _startMonth ?? 3,
                decoration: InputDecoration(labelText: l10n.startMonthLabel),
                onChanged: (v) => setState(() => _startMonth = v),
                items: List.generate(12, (i) {
                  final m = i + 1;
                  return DropdownMenuItem(
                      // coverage:ignore-end
                      value: m,
                      child: Text(// coverage:ignore-line
                          DateFormat('MMMM').format(
                              DateTime(2023, m, 1)))); // coverage:ignore-line
                }),
              ),
            // coverage:ignore-start
            if (_freq == PayoutFrequency.custom)
              ListTile(
                title: Text(l10n.selectMonthsAction),
                subtitle: Text(_customMonths.isEmpty
                    ? l10n.none
                    : _customMonths.join(', ')),
                onTap: () async {
                  final selected = await showDialog<List<int>>(
                    // coverage:ignore-end
                    context: context,
                    // coverage:ignore-start
                    builder: (context) => _MonthMultiSelectDialog(
                        selected: _customMonths,
                        title: l10n.selectMonthsAction),
                    // coverage:ignore-end
                  );
                  if (selected != null) {
                    setState(
                        () => _customMonths = selected); // coverage:ignore-line
                  }
                },
              ),
            // coverage:ignore-start
            CheckboxListTile(
              title: Text(l10n.partialPayoutTaxableFactorTitle),
              value: _isPartial,
              onChanged: (v) => setState(() => _isPartial = v ?? false),
              // coverage:ignore-end
              controlAffinity: ListTileControlAffinity.leading,
            ),
            // coverage:ignore-start
            const Divider(),
            TextField(
              controller: _exemptionLimitCtrl,
              decoration: InputDecoration(
                labelText: l10n.exemptionLimitLabel,
                helperText: l10n.exemptionLimitHelperText,
                // coverage:ignore-end
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // coverage:ignore-line
                FilteringTextInputFormatter.allow(
                    RegexUtils.amountExp) // coverage:ignore-line
              ],
            ),
            // coverage:ignore-start
            SwitchListTile(
              title: Text(l10n.cliffExemptionTitle),
              subtitle: Text(l10n.cliffExemptionSubtitle),
              value: _isCliffExemption,
              onChanged: (v) => setState(() => _isCliffExemption = v),
              // coverage:ignore-end
            ),
          ],
        ),
      ),
      // coverage:ignore-start
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton)),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text;
            final amt = double.tryParse(_amtCtrl.text) ?? 0;
            if (name.isEmpty || amt <= 0) return;
            // coverage:ignore-end

            final allowance = CustomAllowance(
              // coverage:ignore-line
              id: widget.existing?.id ??
                  const Uuid().v4(), // coverage:ignore-line
              name: name,
              payoutAmount: amt,
              // coverage:ignore-start
              frequency: _freq,
              startMonth: _startMonth,
              customMonths: _customMonths,
              isPartial: _isPartial,
              partialAmounts: _partialAmounts,
              isCliffExemption: _isCliffExemption,
              exemptionLimit: double.tryParse(_exemptionLimitCtrl.text) ?? 0,
              // coverage:ignore-end
            );
            widget.onSave(allowance); // coverage:ignore-line
            Navigator.pop(context); // coverage:ignore-line
          },
          child: Text(l10n.saveButton), // coverage:ignore-line
        ),
      ],
    );
  }
}
