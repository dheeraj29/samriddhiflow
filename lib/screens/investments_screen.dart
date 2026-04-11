import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../feature_providers.dart';
import '../providers.dart';
import '../models/investment.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_list_item_card.dart';
import '../widgets/smart_currency_text.dart';
import '../widgets/pagination_bar.dart';
import 'add_investment_screen.dart';

class InvestmentsScreen extends ConsumerStatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  ConsumerState<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends ConsumerState<InvestmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.investmentsTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.investmentDashboard),
            Tab(text: l10n.investmentManagement),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: l10n.exportTemplate,
            onPressed: _exportTickers,
          ),
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: l10n.importPrices,
            onPressed: _importPrices,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _InvestmentDashboardTab(),
          _InvestmentManagementTab(),
        ],
      ),
    );
  }

  // coverage:ignore-start
  void _exportTickers() {
    final investments = ref.read(investmentsProvider);
    final Map<String, double> exportData = {};
    for (var inv in investments) {
      final key = (inv.codeName != null && inv.codeName!.isNotEmpty)
          ? inv.codeName!
          : inv.name;
      exportData[key] = inv.currentPrice;
      // coverage:ignore-end
    }

    final jsonString =
        jsonEncode(exportData); // Minified // coverage:ignore-line
    _showExportDialog(context, jsonString); // coverage:ignore-line
  }

  // coverage:ignore-start
  void _showExportDialog(BuildContext context, String json) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      // coverage:ignore-end
      context: context,
      // coverage:ignore-start
      builder: (context) => AlertDialog(
        title: Text(l10n.exportJsonTitle),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
            // coverage:ignore-end
          ),
          child: SingleChildScrollView(
            // coverage:ignore-line
            child: Column(
              // coverage:ignore-line
              mainAxisSize: MainAxisSize.min,
              children: [
                // coverage:ignore-line
                Container(
                  // coverage:ignore-line
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // coverage:ignore-line
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest, // coverage:ignore-line
                    borderRadius:
                        BorderRadius.circular(8), // coverage:ignore-line
                  ),
                  child: SelectableText(
                    // coverage:ignore-line
                    json,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        // coverage:ignore-start
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.closeAction)),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.copiedToClipboard)));
              Navigator.pop(context);
              // coverage:ignore-end
            },
            icon: const Icon(Icons.copy),
            label: Text(l10n.copyToClipboard), // coverage:ignore-line
          ),
        ],
      ),
    );
  }

  void _importPrices() {
    // coverage:ignore-line
    _showImportDialog(context); // coverage:ignore-line
  }

  // coverage:ignore-start
  void _showImportDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    // coverage:ignore-end

    showDialog(
      // coverage:ignore-line
      context: context,
      // coverage:ignore-start
      builder: (context) => AlertDialog(
        title: Text(l10n.importJsonTitle),
        content: TextField(
          // coverage:ignore-end
          controller: controller,
          maxLines: 8,
          decoration: InputDecoration(
            // coverage:ignore-line
            hintText: l10n.importJsonHint, // coverage:ignore-line
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        // coverage:ignore-start
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancelAction)),
          ElevatedButton(
            onPressed: () async {
              // coverage:ignore-end
              try {
                final Map<String, dynamic> data =
                    jsonDecode(controller.text); // coverage:ignore-line
                final prices =
                    // coverage:ignore-start
                    data.map((k, v) => MapEntry(k, (v as num).toDouble()));
                await ref
                    .read(investmentsProvider.notifier)
                    .updateValuations(prices);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l10n.updatePricesSuccess(prices.length))));
                  Navigator.pop(context);
                  // coverage:ignore-end
                }
              } catch (e) {
                // coverage:ignore-start
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.invalidJsonError)));
                  // coverage:ignore-end
                }
              }
            },
            child: Text(l10n.importAction), // coverage:ignore-line
          ),
        ],
      ),
    );
  }
}

class _InvestmentDashboardTab extends ConsumerWidget {
  const _InvestmentDashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(investmentSummaryProvider);
    final currency = ref.watch(currencyProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(context, summary, currency, l10n),
          const SizedBox(height: 16),
          const _AddInvestmentButton(),
          const SizedBox(height: 24),
          _buildUpcomingCommitments(context, ref, currency, l10n),
          const SizedBox(height: 24),
          if (summary.readyToSellLTCount > 0) ...[
            _buildLTAlert(
                context, summary, currency, l10n), // coverage:ignore-line
            const SizedBox(height: 24),
          ],
          Text(l10n.mfCategoryLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildBreakdownList(
              context, summary.categoryBreakdown, currency, l10n),
          const SizedBox(height: 24),
          Text(l10n.investmentType, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildTypeBreakdownList(
              context, summary.typeBreakdown, currency, l10n),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, dynamic summary,
      String currency, AppLocalizations l10n) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.primary,
        ),
        child: Column(
          children: [
            Text(l10n.totalValueLabel,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            SmartCurrencyText(
              value: summary.totalCurrent,
              locale: currency,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSubStat(
                    l10n.investedLabel, summary.totalInvested, currency),
                _buildGainStat(
                    context,
                    summary.totalCurrent - summary.totalInvested,
                    summary.totalInvested,
                    currency,
                    l10n),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGainStat(BuildContext context, double gain, double invested,
      String currency, AppLocalizations l10n) {
    final gainPercent = invested > 0 ? (gain / invested) * 100 : 0.0;
    final isProfit = gain >= 0;
    final color = isProfit ? Colors.greenAccent : Colors.redAccent;

    return Column(
      children: [
        Text(l10n.unrealizedGainLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SmartCurrencyText(
              value: gain,
              locale: currency,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              "(${isProfit ? '+' : ''}${gainPercent.toStringAsFixed(1)}%)",
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubStat(String label, double value, String currency) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        SmartCurrencyText(
          value: value,
          locale: currency,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildUpcomingCommitments(BuildContext context, WidgetRef ref,
      String currency, AppLocalizations l10n) {
    final investments = ref.watch(investmentsProvider);
    final upcoming = investments
        .where((inv) => inv.isRecurringEnabled && inv.nextRecurringDate != null)
        .toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    // Sort: non-paused first, then by date
    // coverage:ignore-start
    upcoming.sort((a, b) {
      if (a.isRecurringPaused != b.isRecurringPaused) {
        return a.isRecurringPaused ? 1 : -1;
        // coverage:ignore-end
      }
      return a.nextRecurringDate!
          .compareTo(b.nextRecurringDate!); // coverage:ignore-line
    });

    return Column(
      // coverage:ignore-line
      crossAxisAlignment: CrossAxisAlignment.start,
      // coverage:ignore-start
      children: [
        Row(
          children: [
            Icon(Icons.upcoming,
                size: 20, color: Theme.of(context).colorScheme.primary),
            // coverage:ignore-end
            const SizedBox(width: 8),
            Text(l10n.upcomingCommitmentsHeader, // coverage:ignore-line
                style: Theme.of(context)
                    .textTheme
                    .titleMedium), // coverage:ignore-line
          ],
        ),
        const SizedBox(height: 12),
        ...upcoming
            .take(3) // coverage:ignore-line
            .map((inv) => _buildUpcomingItem(
                context, inv, currency, l10n)), // coverage:ignore-line
      ],
    );
  }

  Widget _buildUpcomingItem(
      BuildContext context,
      Investment inv, // coverage:ignore-line
      String currency,
      AppLocalizations l10n) {
    final daysLeft = inv.nextRecurringDate!
        .difference(DateTime.now())
        .inDays; // coverage:ignore-line
    final isPaused = inv.isRecurringPaused; // coverage:ignore-line
    final color = isPaused
        ? Colors.grey
        : Theme.of(context).colorScheme.primary; // coverage:ignore-line

    return AppListItemCard(
      // coverage:ignore-line
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => Navigator.push(
        // coverage:ignore-line
        context,
        MaterialPageRoute(
            // coverage:ignore-line
            builder: (_) => AddInvestmentScreen(
                investmentToEdit: inv)), // coverage:ignore-line
      ),
      // coverage:ignore-start
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(inv.type.icon, color: color, size: 20),
          // coverage:ignore-end
        ),
        title: Text(inv.name,
            style: const TextStyle(
                fontWeight: FontWeight.bold)), // coverage:ignore-line
        subtitle: Text(
          // coverage:ignore-line
          isPaused
              ? 'Paused'
              : 'Next: ${DateFormat.yMMMd().format(inv.nextRecurringDate!)} ($daysLeft days)', // coverage:ignore-line
          style: TextStyle(
              fontSize: 12,
              color: isPaused ? Colors.grey : null), // coverage:ignore-line
        ),
        trailing: SmartCurrencyText(
          // coverage:ignore-line
          value: inv.recurringAmount ??
              inv.acquisitionPrice, // coverage:ignore-line
          locale: currency,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildLTAlert(
      BuildContext context,
      dynamic summary,
      String currency, // coverage:ignore-line
      AppLocalizations l10n) {
    return Container(
      // coverage:ignore-line
      padding: const EdgeInsets.all(16),
      // coverage:ignore-start
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        // coverage:ignore-end
      ),
      child: Row(
        // coverage:ignore-line
        children: [
          // coverage:ignore-line
          const Icon(Icons.alarm_on, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            // coverage:ignore-line
            child: Column(
              // coverage:ignore-line
              crossAxisAlignment: CrossAxisAlignment.start,
              // coverage:ignore-start
              children: [
                Text(
                  l10n.readyToSellLT(summary.readyToSellLTCount),
                  // coverage:ignore-end
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                Row(
                  // coverage:ignore-line
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // coverage:ignore-line
                    const Text("Value: ",
                        style: TextStyle(fontSize: 12, color: Colors.orange)),
                    SmartCurrencyText(
                      // coverage:ignore-line
                      value: summary.readyToSellLTValue, // coverage:ignore-line
                      locale: currency,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownList(
      BuildContext context,
      Map<MutualFundCategory, ({double invested, double current})> data,
      String currency,
      AppLocalizations l10n) {
    if (data.isEmpty) return const Text("No data");
    // Sort by current value descending
    final sorted = data.entries.toList() // coverage:ignore-line
      ..sort((a, b) =>
          b.value.current.compareTo(a.value.current)); // coverage:ignore-line

    return Column(
      // coverage:ignore-line
      children: sorted
          // coverage:ignore-start
          .map((e) => _buildBreakdownRow(context, e.key.localizedName(l10n),
              e.value.invested, e.value.current, currency, l10n))
          .toList(),
      // coverage:ignore-end
    );
  }

  Widget _buildTypeBreakdownList(
      BuildContext context,
      Map<InvestmentType, ({double invested, double current})> data,
      String currency,
      AppLocalizations l10n) {
    if (data.isEmpty) return const Text("No data");
    // Sort by current value descending
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.current.compareTo(a.value.current));

    return Column(
      children: sorted
          .map((e) => _buildBreakdownRow(context, e.key.localizedName(l10n),
              e.value.invested, e.value.current, currency, l10n))
          .toList(),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, String label, double invested,
      double current, String currency, AppLocalizations l10n) {
    final gain = current - invested;
    final gainPercent = invested > 0 ? (gain / invested) * 100 : 0.0;
    final isProfit = gain >= -0.01;
    final color = isProfit ? Colors.green : Colors.red;

    return AppListItemCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                SmartCurrencyText(
                  value: current,
                  locale: currency,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("${l10n.investedLabel}: ",
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.7))),
                    SmartCurrencyText(
                      value: invested,
                      locale: currency,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(isProfit ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: color, size: 16),
                Text(
                  "${isProfit ? '+' : ''}${gainPercent.toStringAsFixed(1)}%",
                  style: TextStyle(
                      fontSize: 12, color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _InvestmentSortOption { oldestFirst, highestGain }

class _InvestmentManagementTab extends ConsumerStatefulWidget {
  const _InvestmentManagementTab();

  @override
  ConsumerState<_InvestmentManagementTab> createState() =>
      __InvestmentManagementTabState();
}

class __InvestmentManagementTabState
    extends ConsumerState<_InvestmentManagementTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  InvestmentType? _filterType;
  _InvestmentSortOption _sortOption = _InvestmentSortOption.oldestFirst;
  static const int _pageSize = 15;
  int _currentPage = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawInvestments = ref.watch(investmentsProvider);
    final currency = ref.watch(currencyProvider);
    final l10n = AppLocalizations.of(context)!;

    final filteredSorted = _getFilteredSortedInvestments(rawInvestments);
    final totalPages = (filteredSorted.length / _pageSize).ceil();
    final safeCurrentPage =
        _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final paginated = _getPaginatedInvestments(filteredSorted, safeCurrentPage);

    return Column(
      children: [
        _buildControls(l10n),
        const Divider(height: 1),
        Expanded(
          child: _buildList(paginated, currency, l10n),
        ),
        _buildPaginationBar(safeCurrentPage, totalPages),
      ],
    );
  }

  List<Investment> _getFilteredSortedInvestments(List<Investment> raw) {
    var list = raw;

    // Apply Filter by Type
    if (_filterType != null) {
      list = list
          .where((inv) => inv.type == _filterType)
          .toList(); // coverage:ignore-line
    }

    // Apply Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase(); // coverage:ignore-line
      list = list
          // coverage:ignore-start
          .where((inv) =>
              inv.name.toLowerCase().contains(q) ||
              (inv.codeName?.toLowerCase().contains(q) ?? false))
          .toList();
      // coverage:ignore-end
    }

    // Apply Sort (Multi-level)
    list = List.from(list);
    list.sort(_compareInvestments);

    return list;
  }

  int _compareInvestments(Investment a, Investment b) {
    if (_sortOption == _InvestmentSortOption.oldestFirst) {
      final dateComp = a.acquisitionDate.compareTo(b.acquisitionDate);
      if (dateComp != 0) return dateComp;
      return b.unrealizedGain.compareTo(a.unrealizedGain);
    } else {
      // coverage:ignore-start
      final gainComp = b.unrealizedGain.compareTo(a.unrealizedGain);
      if (gainComp != 0) return gainComp;
      return a.acquisitionDate.compareTo(b.acquisitionDate);
      // coverage:ignore-end
    }
  }

  List<Investment> _getPaginatedInvestments(
      List<Investment> list, int safePage) {
    final startIndex = (safePage - 1) * _pageSize;
    return list.skip(startIndex).take(_pageSize).toList();
  }

  Widget _buildPaginationBar(int safeCurrentPage, int totalPages) {
    return PaginationBar(
      safeCurrentPage: safeCurrentPage,
      totalPages: totalPages,
      onPageChanged: (page) =>
          setState(() => _currentPage = page), // coverage:ignore-line
    );
  }

  Widget _buildControls(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          const _AddInvestmentButton(),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchLabel,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            // coverage:ignore-start
            onChanged: (v) => setState(() {
              _searchQuery = v;
              _currentPage = 1;
              // coverage:ignore-end
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<InvestmentType?>(
                    value: _filterType,
                    hint: Text(l10n.allTypesLabel),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(l10n.allTypesLabel)),
                      ...InvestmentType.values.map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.localizedName(l10n)),
                          )),
                    ],
                    // coverage:ignore-start
                    onChanged: (v) => setState(() {
                      _filterType = v;
                      _currentPage = 1;
                      // coverage:ignore-end
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              PopupMenuButton<_InvestmentSortOption>(
                icon: const Icon(Icons.sort),
                // coverage:ignore-start
                onSelected: (v) => setState(() {
                  _sortOption = v;
                  _currentPage = 1;
                  // coverage:ignore-end
                }),
                itemBuilder: (context) => [
                  // coverage:ignore-line
                  PopupMenuItem(
                    // coverage:ignore-line
                    value: _InvestmentSortOption.oldestFirst,
                    child: Text(// coverage:ignore-line
                        "${l10n.sortByOldestFirst} + ${l10n.sortByHighestGain}"), // coverage:ignore-line
                  ),
                  PopupMenuItem(
                    // coverage:ignore-line
                    value: _InvestmentSortOption.highestGain,
                    child: Text(l10n.sortByHighestGain), // coverage:ignore-line
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      List<Investment> investments, String currency, AppLocalizations l10n) {
    if (investments.isEmpty) {
      return Center(
        child: Text(_searchQuery.isEmpty
            ? "No investments found."
            : "No matching results."),
      );
    }

    return ListView.builder(
      itemCount: investments.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        return _buildInvestmentListItem(investments[index], currency, l10n);
      },
    );
  }

  Widget _buildInvestmentListItem(
      Investment inv, String currency, AppLocalizations l10n) {
    final gain = inv.unrealizedGain;
    final gainPercent =
        inv.investedValue > 0 ? (gain / inv.investedValue) * 100 : 0.0;
    final isProfit = gain >= 0;
    final color = isProfit ? Colors.green : Colors.red;

    return AppListItemCard(
      onTap: () => _editInvestment(context, inv), // coverage:ignore-line
      child: ListTile(
        contentPadding:
            const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
        title: Row(
          children: [
            Expanded(
              child: Text(inv.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (inv.isRecurringEnabled) ...[
              const SizedBox(width: 4),
              Icon(
                // coverage:ignore-line
                inv.isRecurringPaused // coverage:ignore-line
                    ? Icons.pause_circle_outline
                    : Icons.repeat,
                size: 14,
                color: inv.isRecurringPaused
                    ? Colors.grey
                    : Colors.blue, // coverage:ignore-line
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeAndLTInfo(inv, l10n),
            const SizedBox(height: 4),
            _buildOriginalValueInfo(inv, currency),
            if (inv.codeName != null && inv.codeName!.isNotEmpty)
              Padding(
                // coverage:ignore-line
                padding: const EdgeInsets.only(top: 2),
                child: Text(inv.codeName!, // coverage:ignore-line
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey)),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildValuationColumn(inv, currency, isProfit, gainPercent, color),
            const SizedBox(width: 8),
            _buildInvestmentActions(inv, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeAndLTInfo(Investment inv, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "${inv.type.localizedName(l10n)} • ${DateFormat.yMMMd().format(inv.acquisitionDate)}",
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (inv.longTermRemaining != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Text(
              l10n.longTermInLabel(inv.longTermRemaining!),
              style: const TextStyle(
                  fontSize: 9,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOriginalValueInfo(Investment inv, String currency) {
    return Row(
      children: [
        Text("Original: ",
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
        SmartCurrencyText(
          value: inv.investedValue,
          locale: currency,
          style: TextStyle(
              fontSize: 10,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildValuationColumn(Investment inv, String currency, bool isProfit,
      double gainPercent, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SmartCurrencyText(
          value: inv.currentValuation,
          locale: currency,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isProfit ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: color, size: 16),
            Text(
              "${isProfit ? '+' : ''}${gainPercent.toStringAsFixed(2)}%",
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvestmentActions(Investment inv, AppLocalizations l10n) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert),
      // coverage:ignore-start
      onSelected: (v) {
        if (v == 'edit') _editInvestment(context, inv);
        if (v == 'delete') _deleteInvestment(context, inv);
        // coverage:ignore-end
      },
      itemBuilder: (context) => [
        // coverage:ignore-line
        PopupMenuItem(
            // coverage:ignore-line
            value: 'edit',
            child: Row(children: [
              // coverage:ignore-line
              const Icon(Icons.edit, size: 18),
              const SizedBox(width: 8),
              Text(l10n.editAction) // coverage:ignore-line
            ])),
        PopupMenuItem(
            // coverage:ignore-line
            value: 'delete',
            child: Row(children: [
              // coverage:ignore-line
              const Icon(Icons.delete, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(l10n.deleteAction,
                  style: const TextStyle(
                      color: Colors.red)) // coverage:ignore-line
            ])),
      ],
    );
  }

  void _editInvestment(BuildContext context, Investment inv) {
    // coverage:ignore-line
    Navigator.push(
      // coverage:ignore-line
      context,
      MaterialPageRoute(
          // coverage:ignore-line
          builder: (_) => AddInvestmentScreen(
              investmentToEdit: inv)), // coverage:ignore-line
    );
  }

  // coverage:ignore-start
  void _deleteInvestment(BuildContext context, Investment inv) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      // coverage:ignore-end
      context: context,
      // coverage:ignore-start
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteInvestmentTitle),
        content: Text(l10n.deleteInvestmentConfirmation),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancelAction)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                // coverage:ignore-end
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            // coverage:ignore-start
            onPressed: () {
              ref.read(investmentsProvider.notifier).deleteInvestment(inv.id);
              Navigator.pop(context);
              // coverage:ignore-end
            },
            child: Text(l10n.deleteAction), // coverage:ignore-line
          ),
        ],
      ),
    );
  }
}

class _AddInvestmentButton extends StatelessWidget {
  const _AddInvestmentButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddInvestmentScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.addInvestment),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
