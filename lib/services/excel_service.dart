import 'package:excel/excel.dart';
import 'storage_service.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/loan.dart';
import '../models/category.dart';
import '../models/profile.dart';
import '../utils/currency_utils.dart';
import 'package:uuid/uuid.dart';
import 'file_service.dart';

class ExcelService {
  final StorageService _storage;
  final FileService _fileService;
  ExcelService(this._storage, this._fileService);

  String _getVal(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final val = cell.value;
    if (val is TextCellValue) return val.value.text?.trim() ?? '';
    if (val is IntCellValue) return val.value.toString();
    if (val is DoubleCellValue) return val.value.toString();
    if (val is BoolCellValue) return val.value.toString();
    if (val is DateCellValue) return val.toString().trim();
    return val.toString().trim();
  }

  Future<List<int>> exportData({bool allProfiles = false}) async {
    final excel = Excel.createExcel();

    // 0. Profiles
    if (allProfiles) {
      final Sheet profSheet = excel['Profiles'];
      profSheet.appendRow([
        TextCellValue('ID'),
        TextCellValue('Name'),
        TextCellValue('Currency Locale'),
        TextCellValue('Monthly Budget')
      ]);
      for (var p in _storage.getProfiles()) {
        profSheet.appendRow([
          TextCellValue(p.id),
          TextCellValue(p.name),
          TextCellValue(p.currencyLocale),
          DoubleCellValue(p.monthlyBudget)
        ]);
      }
    }

    // 1. Accounts
    final Sheet accSheet = excel['Accounts'];
    final accHeaders = [
      TextCellValue('ID'),
      TextCellValue('Name'),
      TextCellValue('Type'),
      TextCellValue('Balance'),
      TextCellValue('Currency'),
      TextCellValue('Credit Limit'),
      TextCellValue('Billing Cycle Day'),
      TextCellValue('Payment Due Date Day')
    ];
    if (allProfiles) accHeaders.add(TextCellValue('Profile ID'));
    accSheet.appendRow(accHeaders);

    final accounts =
        allProfiles ? _storage.getAllAccounts() : _storage.getAccounts();
    for (var acc in accounts) {
      final row = [
        TextCellValue(acc.id),
        TextCellValue(acc.name),
        TextCellValue(acc.type.name),
        DoubleCellValue(acc.balance),
        TextCellValue(acc.currency),
        acc.creditLimit != null ? DoubleCellValue(acc.creditLimit!) : null,
        acc.billingCycleDay != null ? IntCellValue(acc.billingCycleDay!) : null,
        acc.paymentDueDateDay != null
            ? IntCellValue(acc.paymentDueDateDay!)
            : null
      ];
      if (allProfiles) row.add(TextCellValue(acc.profileId ?? 'default'));
      accSheet.appendRow(row);
    }

    // 2. Loans
    final Sheet loanSheet = excel['Loans'];
    final loanHeaders = [
      TextCellValue('ID'),
      TextCellValue('Name'),
      TextCellValue('Type'),
      TextCellValue('Total Principal'),
      TextCellValue('Remaining Principal'),
      TextCellValue('Interest Rate'),
      TextCellValue('Tenure Months'),
      TextCellValue('EMI Amount'),
      TextCellValue('EMI Day'),
      TextCellValue('Start Date'),
      TextCellValue('First EMI Date')
    ];
    if (allProfiles) loanHeaders.add(TextCellValue('Profile ID'));
    loanSheet.appendRow(loanHeaders);

    final loans = allProfiles ? _storage.getAllLoans() : _storage.getLoans();
    for (var loan in loans) {
      final row = [
        TextCellValue(loan.id),
        TextCellValue(loan.name),
        TextCellValue(loan.type.name),
        DoubleCellValue(loan.totalPrincipal),
        DoubleCellValue(loan.remainingPrincipal),
        DoubleCellValue(loan.interestRate),
        IntCellValue(loan.tenureMonths),
        DoubleCellValue(loan.emiAmount),
        IntCellValue(loan.emiDay),
        TextCellValue(loan.startDate.toIso8601String()),
        TextCellValue(loan.firstEmiDate.toIso8601String())
      ];
      if (allProfiles) row.add(TextCellValue(loan.profileId ?? 'default'));
      loanSheet.appendRow(row);
    }

    // 3. Categories
    final Sheet catSheet = excel['Categories'];
    final catHeaders = [
      TextCellValue('ID'),
      TextCellValue('Name'),
      TextCellValue('Usage'),
      TextCellValue('Tag'),
      TextCellValue('Icon Code')
    ];
    if (allProfiles) catHeaders.add(TextCellValue('Profile ID'));
    catSheet.appendRow(catHeaders);

    final categories =
        allProfiles ? _storage.getAllCategories() : _storage.getCategories();
    for (var cat in categories) {
      final row = [
        TextCellValue(cat.id),
        TextCellValue(cat.name),
        TextCellValue(cat.usage.name),
        TextCellValue(cat.tag.name),
        IntCellValue(cat.iconCode)
      ];
      if (allProfiles) row.add(TextCellValue(cat.profileId ?? 'default'));
      catSheet.appendRow(row);
    }

    // 4. Transactions
    final Sheet txnSheet = excel['Transactions'];
    final txnHeaders = [
      TextCellValue('ID'),
      TextCellValue('Date'),
      TextCellValue('Title'),
      TextCellValue('Amount'),
      TextCellValue('Type'),
      TextCellValue('Category'),
      TextCellValue('Account ID'),
      TextCellValue('Account Name'),
      TextCellValue('To Account ID'),
      TextCellValue('Loan ID'),
      TextCellValue('Gain Amount'),
      TextCellValue('Holding Tenure (Months)'),
      TextCellValue('Is Recurring'),
      TextCellValue('Is Deleted')
    ];
    if (allProfiles) txnHeaders.add(TextCellValue('Profile ID'));
    txnSheet.appendRow(txnHeaders);

    final txns = allProfiles
        ? _storage.getAllTransactions()
        : _storage.getTransactions();
    final allAccounts = _storage.getAllAccounts();
    for (var txn in txns) {
      final accName = allAccounts.where((a) => a.id == txn.accountId).isNotEmpty
          ? allAccounts.firstWhere((a) => a.id == txn.accountId).name
          : 'Unknown';
      final row = [
        TextCellValue(txn.id),
        TextCellValue(txn.date.toIso8601String()),
        TextCellValue(txn.title),
        DoubleCellValue(txn.amount),
        TextCellValue(txn.type.name),
        TextCellValue(txn.category),
        TextCellValue(txn.accountId ?? 'manual'),
        TextCellValue(accName),
        txn.toAccountId != null ? TextCellValue(txn.toAccountId!) : null,
        txn.loanId != null ? TextCellValue(txn.loanId!) : null,
        txn.gainAmount != null ? DoubleCellValue(txn.gainAmount!) : null,
        txn.holdingTenureMonths != null
            ? IntCellValue(txn.holdingTenureMonths!)
            : null,
        BoolCellValue(txn.isRecurringInstance),
        BoolCellValue(txn.isDeleted)
      ];
      if (allProfiles) row.add(TextCellValue(txn.profileId ?? 'default'));
      txnSheet.appendRow(row);
    }

    // 5. Loan Transactions
    final Sheet loanTxnSheet = excel['Loan Transactions'];
    loanTxnSheet.appendRow([
      TextCellValue('Loan ID'),
      TextCellValue('ID'),
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Amount'),
      TextCellValue('Principal Component'),
      TextCellValue('Interest Component'),
      TextCellValue('Resultant Principal')
    ]);
    for (var loan in loans) {
      for (var txn in loan.transactions) {
        loanTxnSheet.appendRow([
          TextCellValue(loan.id),
          TextCellValue(txn.id),
          TextCellValue(txn.date.toIso8601String()),
          TextCellValue(txn.type.name),
          DoubleCellValue(txn.amount),
          DoubleCellValue(txn.principalComponent),
          DoubleCellValue(txn.interestComponent),
          DoubleCellValue(txn.resultantPrincipal)
        ]);
      }
    }

    excel.delete('Sheet1'); // Remove default sheet
    return excel.encode()!;
  }

  Future<Map<String, int>> importData(
      {List<int>? fileBytes, bool allProfiles = false}) async {
    Map<String, int> resultCounts = {
      'status':
          0, // 0: no change, 1: success, -1: cancel, -2: error, -3: no sheets, -4: decode error
      'accounts': 0,
      'transactions': 0,
      'loans': 0,
      'loanTransactions': 0,
      'categories': 0,
      'profiles': 0,
    };

    final activeProfileId = _storage.getActiveProfileId();

    Excel excel;
    try {
      if (fileBytes == null) {
        final bytes = await _fileService.pickFile(allowedExtensions: ['xlsx']);

        if (bytes == null) {
          resultCounts['status'] = -1;
          return resultCounts;
        }
        fileBytes = bytes;
      }

      excel = Excel.decodeBytes(fileBytes);
    } catch (_) {
      resultCounts['status'] = -4;
      return resultCounts;
    }

    bool foundAnyValidSection = false;
    final Map<String, List<LoanTransaction>> loanTxnsMap = {};

    // Mapping helper
    int findColumn(List<Data?> headerRow, List<String> possibleNames) {
      // Pass 1: Exact Match (High Priority)
      for (var name in possibleNames) {
        final target = name
            .toLowerCase()
            .replaceAll(' ', '')
            .replaceAll('_', '')
            .replaceAll('-', '');
        for (int i = 0; i < headerRow.length; i++) {
          final cell = headerRow[i];
          if (cell == null) continue;
          final header = _getVal(cell)
              .toLowerCase()
              .replaceAll(' ', '')
              .replaceAll('_', '')
              .replaceAll('-', '');
          if (header == target) return i;
        }
      }

      // Pass 2: Partial Match (Fallback)
      for (var name in possibleNames) {
        final target = name
            .toLowerCase()
            .replaceAll(' ', '')
            .replaceAll('_', '')
            .replaceAll('-', '');
        for (int i = 0; i < headerRow.length; i++) {
          final cell = headerRow[i];
          if (cell == null) continue;
          final header = _getVal(cell)
              .toLowerCase()
              .replaceAll(' ', '')
              .replaceAll('_', '')
              .replaceAll('-', '');
          if (header.contains(target) || target.contains(header)) {
            if (header.length > 2 || target == header) return i;
          }
        }
      }
      return -1;
    }

    // 0. Pre-process Profiles if present
    if (excel.tables.containsKey('Profiles')) {
      final profSheet = excel.tables['Profiles']!;
      if (profSheet.maxRows > 1) {
        final profHeaders = profSheet.rows.first;
        final idIdx = findColumn(profHeaders, ['id']);
        final nameIdx = findColumn(profHeaders, ['name']);
        final localeIdx = findColumn(profHeaders, ['currencylocale', 'locale']);
        final budgetIdx = findColumn(profHeaders, ['monthlybudget', 'budget']);

        final existingProfiles =
            _storage.getProfiles().map((p) => p.id).toSet();

        for (var row in profSheet.rows.skip(1)) {
          final id = idIdx != -1 ? _getVal(row[idIdx]) : '';
          if (id.isEmpty || existingProfiles.contains(id)) continue;
          final name =
              nameIdx != -1 ? _getVal(row[nameIdx]) : 'Restored Profile';
          final profile = Profile(
            id: id,
            name: name,
            currencyLocale: localeIdx != -1 ? _getVal(row[localeIdx]) : 'en_IN',
            monthlyBudget: budgetIdx != -1
                ? double.tryParse(_getVal(row[budgetIdx])) ?? 0.0
                : 0.0,
          );
          await _storage.saveProfile(profile);
          resultCounts['profiles'] = resultCounts['profiles']! + 1;
        }
      }
    }

    // Process Sheets
    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      if (sheet.maxRows <= 1) continue;

      final headerRow = sheet.rows.first;
      final rows = sheet.rows.skip(1).toList();
      final sheetName = table.toUpperCase();

      if (sheetName.contains('LOAN') && sheetName.contains('TRANSACTION')) {
        final loanIdIdx = findColumn(headerRow, ['loanid']);
        final idIdx = findColumn(headerRow, ['id', 'txnid']);
        final dateIdx = findColumn(headerRow, ['date']);
        final typeIdx = findColumn(headerRow, ['type']);
        final amountIdx = findColumn(headerRow, ['amount']);
        final prinIdx = findColumn(headerRow, ['principalcomponent']);
        final intIdx = findColumn(headerRow, ['interestcomponent']);
        final resIdx = findColumn(headerRow, ['resultantprincipal']);

        if (loanIdIdx != -1) {
          foundAnyValidSection = true;
          for (var row in rows) {
            try {
              if (row.length <= loanIdIdx) continue;
              final loanId = _getVal(row[loanIdIdx]);
              if (loanId.isEmpty) continue;

              final id = idIdx != -1 && idIdx < row.length
                  ? _getVal(row[idIdx])
                  : const Uuid().v4();
              if (id.isEmpty) continue;

              final dateStr = dateIdx != -1 && dateIdx < row.length
                  ? _getVal(row[dateIdx])
                  : '';
              final date = DateTime.tryParse(dateStr) ?? DateTime.now();

              final typeStr = typeIdx != -1 && typeIdx < row.length
                  ? _getVal(row[typeIdx]).toLowerCase()
                  : 'emi';

              final amount = amountIdx != -1 && amountIdx < row.length
                  ? double.tryParse(_getVal(row[amountIdx])) ?? 0
                  : 0.0;

              final pComp = prinIdx != -1 && prinIdx < row.length
                  ? double.tryParse(_getVal(row[prinIdx])) ?? 0
                  : 0.0;

              final iComp = intIdx != -1 && intIdx < row.length
                  ? double.tryParse(_getVal(row[intIdx])) ?? 0
                  : 0.0;

              final resPrin = resIdx != -1 && resIdx < row.length
                  ? double.tryParse(_getVal(row[resIdx])) ?? 0
                  : 0.0;

              final txn = LoanTransaction(
                id: id.isEmpty ? const Uuid().v4() : id,
                date: date,
                amount: amount,
                type: LoanTransactionType.values.firstWhere(
                    (e) => e.name.toLowerCase() == typeStr,
                    orElse: () => LoanTransactionType.emi),
                principalComponent: pComp,
                interestComponent: iComp,
                resultantPrincipal: resPrin,
              );

              if (!loanTxnsMap.containsKey(loanId)) {
                loanTxnsMap[loanId] = [];
              }
              loanTxnsMap[loanId]!.add(txn);
              resultCounts['loanTransactions'] =
                  resultCounts['loanTransactions']! + 1;
            } catch (_) {}
          }
        }
      } else if (sheetName.contains('ACCOUNT')) {
        final existingAccounts =
            _storage.getAccounts().map((e) => e.id).toSet();
        final idIdx = findColumn(headerRow, ['id', 'accountid', 'accid']);
        final nameIdx = findColumn(headerRow, ['name', 'accountname', 'title']);
        final typeIdx = findColumn(headerRow, ['type', 'accounttype']);
        final balanceIdx = findColumn(headerRow, ['balance', 'amount']);
        final currIdx = findColumn(headerRow, ['currency']);
        final limitIdx = findColumn(headerRow, ['creditlimit', 'limit']);
        final billingIdx =
            findColumn(headerRow, ['billingcycleday', 'billingday']);
        final dueIdx =
            findColumn(headerRow, ['paymentduedateday', 'duedateday']);

        if (nameIdx != -1) {
          foundAnyValidSection = true;
          for (var row in rows) {
            try {
              if (row.length <= nameIdx) continue;
              final id =
                  idIdx != -1 && idIdx < row.length ? _getVal(row[idIdx]) : '';
              if (id.isNotEmpty && existingAccounts.contains(id)) continue;

              final name = _getVal(row[nameIdx]);
              if (name.isEmpty) continue;

              final typeStr = typeIdx != -1 && typeIdx < row.length
                  ? _getVal(row[typeIdx]).toLowerCase()
                  : 'savings';
              final balance = balanceIdx != -1 && balanceIdx < row.length
                  ? CurrencyUtils.roundTo2Decimals(double.tryParse(
                          _getVal(row[balanceIdx]).replaceAll(',', '')) ??
                      0.0)
                  : 0.0;

              final acc = Account(
                id: id.isEmpty ? const Uuid().v4() : id,
                name: name,
                type: AccountType.values.firstWhere(
                    (e) => e.name.toLowerCase() == typeStr,
                    orElse: () => AccountType.savings),
                balance: balance,
                currency: currIdx != -1 && currIdx < row.length
                    ? _getVal(row[currIdx])
                    : 'USD',
                creditLimit: limitIdx != -1 && limitIdx < row.length
                    ? double.tryParse(_getVal(row[limitIdx]))
                    : null,
                billingCycleDay: billingIdx != -1 && billingIdx < row.length
                    ? int.tryParse(_getVal(row[billingIdx]))
                    : null,
                paymentDueDateDay: dueIdx != -1 && dueIdx < row.length
                    ? int.tryParse(_getVal(row[dueIdx]))
                    : null,
                profileId: findColumn(headerRow, ['profileid']) != -1 &&
                        findColumn(headerRow, ['profileid']) < row.length
                    ? _getVal(row[findColumn(headerRow, ['profileid'])])
                    : activeProfileId,
              );
              await _storage.saveAccount(acc);
              resultCounts['accounts'] = resultCounts['accounts']! + 1;
            } catch (_) {}
          }
        }
      } else if (sheetName.contains('LOAN')) {
        final existingLoans = _storage.getLoans().map((e) => e.id).toSet();
        final idIdx = findColumn(headerRow, ['id', 'loanid']);
        final nameIdx = findColumn(headerRow, ['name', 'loanname']);

        if (nameIdx != -1) {
          foundAnyValidSection = true;
          for (var row in rows) {
            try {
              if (row.length <= nameIdx) continue;
              final id =
                  idIdx != -1 && idIdx < row.length ? _getVal(row[idIdx]) : '';
              if (id.isNotEmpty && existingLoans.contains(id)) continue;

              final name = _getVal(row[nameIdx]);
              if (name.isEmpty) continue;

              final loan = Loan(
                id: id.isEmpty ? const Uuid().v4() : id,
                name: name,
                type: LoanType.values.firstWhere(
                    (e) =>
                        e.name.toLowerCase() ==
                        (findColumn(headerRow, ['type']) != -1
                            ? _getVal(row[findColumn(headerRow, ['type'])])
                                .toLowerCase()
                            : 'personal'),
                    orElse: () => LoanType.personal),
                totalPrincipal: CurrencyUtils.roundTo2Decimals(double.tryParse(
                        _getVal(row[findColumn(
                                headerRow, ['totalprincipal', 'principal'])])
                            .replaceAll(',', '')) ??
                    0.0),
                remainingPrincipal: CurrencyUtils.roundTo2Decimals(
                    double.tryParse(_getVal(row[findColumn(
                                headerRow, ['remainingprincipal', 'balance'])])
                            .replaceAll(',', '')) ??
                        0.0),
                interestRate: CurrencyUtils.roundTo2Decimals(double.tryParse(
                        _getVal(row[findColumn(
                                headerRow, ['interestrate', 'rate'])])
                            .replaceAll(',', '')) ??
                    0.0),
                tenureMonths: int.tryParse(_getVal(row[
                        findColumn(headerRow, ['tenuremonths', 'tenure'])])) ??
                    0,
                emiAmount: CurrencyUtils.roundTo2Decimals(double.tryParse(
                        _getVal(row[
                                findColumn(headerRow, ['emiamount', 'emi'])])
                            .replaceAll(',', '')) ??
                    0.0),
                emiDay: int.tryParse(_getVal(
                        row[findColumn(headerRow, ['emiday', 'day'])])) ??
                    1,
                startDate: DateTime.tryParse(_getVal(
                        row[findColumn(headerRow, ['startdate', 'date'])])) ??
                    DateTime.now(),
                firstEmiDate: DateTime.tryParse(_getVal(row[findColumn(
                        headerRow, ['firstemidate', 'firstdate'])])) ??
                    DateTime.now(),
                accountId: findColumn(headerRow, ['accountid']) != -1
                    ? _getVal(row[findColumn(headerRow, ['accountid'])])
                    : null,
                transactions: [],
                profileId: findColumn(headerRow, ['profileid']) != -1 &&
                        findColumn(headerRow, ['profileid']) < row.length
                    ? _getVal(row[findColumn(headerRow, ['profileid'])])
                    : activeProfileId,
              );
              if (loan.accountId?.isEmpty ?? false) loan.accountId = null;
              await _storage.saveLoan(loan);
              resultCounts['loans'] = resultCounts['loans']! + 1;
            } catch (_) {}
          }
        }
      } else if (sheetName.contains('CATEGOR')) {
        final existingCats = _storage
            .getCategories()
            .map((c) => c.name.toLowerCase().trim())
            .toSet();
        final nameIdx = findColumn(headerRow, ['name', 'categoryname']);

        if (nameIdx != -1) {
          foundAnyValidSection = true;
          for (var row in rows) {
            try {
              if (row.length <= nameIdx) continue;
              final name = _getVal(row[nameIdx]);
              if (name.isEmpty || existingCats.contains(name.toLowerCase())) {
                continue;
              }

              final usageStr = findColumn(headerRow, ['usage', 'type']) != -1
                  ? _getVal(row[findColumn(headerRow, ['usage', 'type'])])
                      .toLowerCase()
                  : 'both';
              final tagStr = findColumn(headerRow, ['tag']) != -1
                  ? _getVal(row[findColumn(headerRow, ['tag'])]).toLowerCase()
                  : 'none';

              final cat = Category(
                id: findColumn(headerRow, ['id']) != -1 &&
                        _getVal(row[findColumn(headerRow, ['id'])]).isNotEmpty
                    ? _getVal(row[findColumn(headerRow, ['id'])])
                    : const Uuid().v4(),
                name: name,
                usage: CategoryUsage.values.firstWhere(
                    (e) => e.name.toLowerCase() == usageStr,
                    orElse: () => CategoryUsage.both),
                tag: CategoryTag.values.firstWhere(
                    (e) => e.name.toLowerCase() == tagStr,
                    orElse: () => CategoryTag.none),
                iconCode: findColumn(headerRow, ['iconcode']) != -1
                    ? int.tryParse(_getVal(
                            row[findColumn(headerRow, ['iconcode'])])) ??
                        0
                    : 0,
                profileId: findColumn(headerRow, ['profileid']) != -1 &&
                        findColumn(headerRow, ['profileid']) < row.length
                    ? _getVal(row[findColumn(headerRow, ['profileid'])])
                    : activeProfileId,
              );
              await _storage.addCategory(cat);
              resultCounts['categories'] = resultCounts['categories']! + 1;
            } catch (_) {}
          }
        }
      } else if (sheetName.contains('TRANSACTION')) {
        final accounts = _storage.getAccounts();

        // 1. Resolve Column Indices ONCE (Performance & Safety Refactor)
        final titleIdx = findColumn(
            headerRow, ['title', 'description', 'narration', 'payee']);
        final amountIdx = findColumn(headerRow, ['amount', 'sum', 'value']);

        final idIdx = findColumn(headerRow, ['id']);
        final dateIdx = findColumn(headerRow, ['date', 'datetime', 'time']);
        final typeIdx =
            findColumn(headerRow, ['type', 'transactiontype', 'txntype']);
        final catIdx = findColumn(headerRow, ['category', 'cat']);
        final accIdIdx = findColumn(headerRow, ['accountid', 'accid']);
        final accNameIdx = findColumn(headerRow, ['accountname', 'account']);
        final toAccIdx = findColumn(headerRow, ['toaccountid', 'toaccount']);
        final loanIdIdx = findColumn(headerRow, ['loanid']);
        final recurIdx = findColumn(
            headerRow, ['isrecurring', 'isrecurringinstance', 'recurring']);
        final delIdx = findColumn(headerRow, ['isdeleted', 'deleted']);
        final gainIdx = findColumn(headerRow, ['gainamount', 'gain']);
        final tenureIdx = findColumn(headerRow,
            ['holdingtenuremonths', 'holdingtenure', 'tenuremonths', 'tenure']);
        final profileIdx = findColumn(headerRow, ['profileid']);

        if (titleIdx != -1 && amountIdx != -1) {
          foundAnyValidSection = true;
          final List<Transaction> transactionsToSave = [];
          for (var row in rows) {
            try {
              // Basic Length Check
              if (row.length <= titleIdx || row.length <= amountIdx) continue;

              final title = _getVal(row[titleIdx]);
              if (title.isEmpty) continue;

              final amount = CurrencyUtils.roundTo2Decimals(double.tryParse(
                      _getVal(row[amountIdx]).replaceAll(',', '')) ??
                  0.0);

              // Safe extractions
              final id = (idIdx != -1 && idIdx < row.length)
                  ? _getVal(row[idIdx])
                  : const Uuid().v4();

              final dateStr = (dateIdx != -1 && dateIdx < row.length)
                  ? _getVal(row[dateIdx])
                  : null;
              final date = (dateStr != null && dateStr.isNotEmpty)
                  ? (DateTime.tryParse(dateStr) ?? DateTime.now())
                  : DateTime.now();

              final typeStr = (typeIdx != -1 && typeIdx < row.length)
                  ? _getVal(row[typeIdx]).toLowerCase()
                  : 'expense'; // Default

              final category = (catIdx != -1 && catIdx < row.length)
                  ? _getVal(row[catIdx])
                  : 'Miscellaneous';

              final accountId = (accIdIdx != -1 && accIdIdx < row.length)
                  ? _getVal(row[accIdIdx])
                  : '';

              final accountName = (accNameIdx != -1 && accNameIdx < row.length)
                  ? _getVal(row[accNameIdx])
                  : 'Default Account';

              // Account Resolution
              String finalAccountId = accountId;
              if (finalAccountId.isEmpty ||
                  finalAccountId.toLowerCase() == 'manual' ||
                  !accounts.any((a) => a.id == finalAccountId)) {
                if (accounts.any(
                    (a) => a.name.toLowerCase() == accountName.toLowerCase())) {
                  finalAccountId = accounts
                      .firstWhere((a) =>
                          a.name.toLowerCase() == accountName.toLowerCase())
                      .id;
                } else if (accountName.isNotEmpty &&
                    accountName.toLowerCase() != 'unknown') {
                  final newAcc = Account.create(
                      name: accountName,
                      type: AccountType.savings,
                      initialBalance: 0.0,
                      profileId: activeProfileId);
                  await _storage.saveAccount(newAcc);
                  accounts.add(newAcc);
                  finalAccountId = newAcc.id;
                } else if (accounts.isNotEmpty) {
                  finalAccountId = accounts.first.id;
                }
              }

              final toAccountId = (toAccIdx != -1 && toAccIdx < row.length)
                  ? _getVal(row[toAccIdx])
                  : null;

              final loanId = (loanIdIdx != -1 && loanIdIdx < row.length)
                  ? _getVal(row[loanIdIdx])
                  : null;

              final isRecurring = (recurIdx != -1 && recurIdx < row.length)
                  ? _getVal(row[recurIdx]).toLowerCase() == 'true'
                  : false;

              final isDeleted = (delIdx != -1 && delIdx < row.length)
                  ? _getVal(row[delIdx]).toLowerCase() == 'true'
                  : false;

              final gainAmount = (gainIdx != -1 && gainIdx < row.length)
                  ? double.tryParse(_getVal(row[gainIdx]))
                  : null;

              final holdingTenure = (tenureIdx != -1 && tenureIdx < row.length)
                  ? int.tryParse(_getVal(row[tenureIdx]))
                  : null;

              // Type Logic & Icon Fix
              final isTransferAuto = typeStr.contains('transfer') ||
                  (toAccountId != null && toAccountId.isNotEmpty);
              final finalType = typeStr.contains('income')
                  ? TransactionType.income
                  : isTransferAuto
                      ? TransactionType.transfer
                      : TransactionType.expense;

              // Debug Counters
              if (finalType == TransactionType.income) {
                resultCounts['type_income'] =
                    (resultCounts['type_income'] ?? 0) + 1;
              }
              if (finalType == TransactionType.expense) {
                resultCounts['type_expense'] =
                    (resultCounts['type_expense'] ?? 0) + 1;
              }
              if (finalType == TransactionType.transfer) {
                resultCounts['type_transfer'] =
                    (resultCounts['type_transfer'] ?? 0) + 1;
              }

              final txn = Transaction(
                id: id.isEmpty ? const Uuid().v4() : id,
                title: title,
                amount: amount.abs(),
                date: date,
                type: finalType,
                category: category,
                accountId: finalAccountId,
                toAccountId: toAccountId?.isEmpty == true
                    ? null
                    : toAccountId, // Clean up empty strings
                loanId: loanId?.isEmpty == true ? null : loanId,
                isRecurringInstance: isRecurring,
                isDeleted: isDeleted,
                gainAmount: gainAmount,
                holdingTenureMonths: holdingTenure,
                profileId: (profileIdx != -1 && profileIdx < row.length)
                    ? _getVal(row[profileIdx])
                    : activeProfileId,
              );

              // Skip Self-Transfers
              if (txn.type == TransactionType.transfer &&
                  txn.accountId != null &&
                  txn.accountId == txn.toAccountId) {
                resultCounts['skipped_selftransfer'] =
                    (resultCounts['skipped_selftransfer'] ?? 0) + 1;
                continue;
              }

              transactionsToSave.add(txn);
              resultCounts['transactions'] = resultCounts['transactions']! + 1;
            } catch (e) {
              resultCounts['skipped_error'] =
                  (resultCounts['skipped_error'] ?? 0) + 1;
            }
          }
          await _storage.saveTransactions(transactionsToSave,
              applyImpact: false);
        }
      }
    }

    // Post-process: Attach Loan Transactions
    if (loanTxnsMap.isNotEmpty) {
      final loans = _storage.getLoans();
      for (var loan in loans) {
        if (loanTxnsMap.containsKey(loan.id)) {
          final importedTxns = loanTxnsMap[loan.id]!;
          importedTxns.sort((a, b) => a.date.compareTo(b.date));
          loan.transactions = importedTxns;
          await _storage.saveLoan(loan);
        }
      }
    }

    if (!foundAnyValidSection) {
      resultCounts['status'] = -3;
    } else {
      int total = resultCounts['accounts']! +
          resultCounts['loans']! +
          resultCounts['categories']! +
          resultCounts['transactions']!;
      if (total == 0) {
        resultCounts['status'] = 0;
      } else {
        resultCounts['status'] = 1;
      }
    }

    return resultCounts;
  }
}
