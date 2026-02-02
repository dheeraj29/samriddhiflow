import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import 'storage_service.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/loan.dart';
import '../models/category.dart';
import '../models/profile.dart';
import '../utils/currency_utils.dart';
import 'file_service.dart';
import '../utils/excel_utils.dart';

class ExcelService {
  final StorageService _storage;
  final FileService _fileService;
  ExcelService(this._storage, this._fileService);

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
    final existingAccounts = _storage.getAccounts(); // Pass ref to keep updated

    // 0. Pre-process Profiles
    if (excel.tables.containsKey('Profiles')) {
      await _importProfiles(excel.tables['Profiles']!, resultCounts);
    }

    // Process Sheets
    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      if (sheet.maxRows <= 1) continue;
      final sheetName = table.toUpperCase();

      if (sheetName.contains('LOAN') && sheetName.contains('TRANSACTION')) {
        foundAnyValidSection = true;
        await _importLoanTransactions(sheet, resultCounts, loanTxnsMap);
      } else if (sheetName.contains('ACCOUNT')) {
        foundAnyValidSection = true;
        await _importAccounts(
            sheet, resultCounts, activeProfileId, existingAccounts);
      } else if (sheetName.contains('LOAN')) {
        foundAnyValidSection = true;
        await _importLoans(sheet, resultCounts, activeProfileId);
      } else if (sheetName.contains('CATEGOR')) {
        foundAnyValidSection = true;
        await _importCategories(sheet, resultCounts, activeProfileId);
      } else if (sheetName.contains('TRANSACTION')) {
        foundAnyValidSection = true;
        await _importTransactions(
            sheet, resultCounts, activeProfileId, existingAccounts);
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
      resultCounts['status'] = total == 0 ? 0 : 1;
    }

    return resultCounts;
  }

  Future<void> _importProfiles(
      Sheet sheet, Map<String, int> resultCounts) async {
    if (sheet.maxRows <= 1) return;
    final headers = sheet.rows.first;
    final idIdx = ExcelUtils.findColumn(headers, ['id']);
    final nameIdx = ExcelUtils.findColumn(headers, ['name']);
    final localeIdx =
        ExcelUtils.findColumn(headers, ['currencylocale', 'locale']);
    final budgetIdx =
        ExcelUtils.findColumn(headers, ['monthlybudget', 'budget']);

    final existingProfiles = _storage.getProfiles().map((p) => p.id).toSet();

    for (var row in sheet.rows.skip(1)) {
      final id = idIdx != -1 ? ExcelUtils.getCellValue(row[idIdx]) : '';
      if (id.isEmpty || existingProfiles.contains(id)) continue;

      final name = nameIdx != -1
          ? ExcelUtils.getCellValue(row[nameIdx])
          : 'Restored Profile';
      final profile = Profile(
        id: id,
        name: name,
        currencyLocale:
            localeIdx != -1 ? ExcelUtils.getCellValue(row[localeIdx]) : 'en_IN',
        monthlyBudget: budgetIdx != -1
            ? double.tryParse(ExcelUtils.getCellValue(row[budgetIdx])) ?? 0.0
            : 0.0,
      );
      await _storage.saveProfile(profile);
      resultCounts['profiles'] = resultCounts['profiles']! + 1;
    }
  }

  Future<void> _importAccounts(Sheet sheet, Map<String, int> resultCounts,
      String activeProfileId, List<Account> existingAccountsMutex) async {
    final headers = sheet.rows.first;
    final existingIds = existingAccountsMutex.map((e) => e.id).toSet();

    final idIdx = ExcelUtils.findColumn(headers, ['id', 'accountid', 'accid']);
    final nameIdx =
        ExcelUtils.findColumn(headers, ['name', 'accountname', 'title']);
    if (nameIdx == -1) return;

    final typeIdx = ExcelUtils.findColumn(headers, ['type', 'accounttype']);
    final balanceIdx = ExcelUtils.findColumn(headers, ['balance', 'amount']);
    final currIdx = ExcelUtils.findColumn(headers, ['currency']);
    final limitIdx = ExcelUtils.findColumn(headers, ['creditlimit', 'limit']);
    final billingIdx =
        ExcelUtils.findColumn(headers, ['billingcycleday', 'billingday']);
    final dueIdx =
        ExcelUtils.findColumn(headers, ['paymentduedateday', 'duedateday']);
    final profileIdx = ExcelUtils.findColumn(headers, ['profileid']);

    for (var row in sheet.rows.skip(1)) {
      try {
        if (row.length <= nameIdx) continue;
        final id = idIdx != -1 && idIdx < row.length
            ? ExcelUtils.getCellValue(row[idIdx])
            : '';
        if (id.isNotEmpty && existingIds.contains(id)) continue;

        final name = ExcelUtils.getCellValue(row[nameIdx]);
        if (name.isEmpty) continue;

        final typeStr = typeIdx != -1 && typeIdx < row.length
            ? ExcelUtils.getCellValue(row[typeIdx]).toLowerCase()
            : 'savings';
        final balance = balanceIdx != -1 && balanceIdx < row.length
            ? CurrencyUtils.roundTo2Decimals(double.tryParse(
                    ExcelUtils.getCellValue(row[balanceIdx])
                        .replaceAll(',', '')) ??
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
              ? ExcelUtils.getCellValue(row[currIdx])
              : '',
          creditLimit: limitIdx != -1 && limitIdx < row.length
              ? double.tryParse(ExcelUtils.getCellValue(row[limitIdx]))
              : null,
          billingCycleDay: billingIdx != -1 && billingIdx < row.length
              ? int.tryParse(ExcelUtils.getCellValue(row[billingIdx]))
              : null,
          paymentDueDateDay: dueIdx != -1 && dueIdx < row.length
              ? int.tryParse(ExcelUtils.getCellValue(row[dueIdx]))
              : null,
          profileId: profileIdx != -1 && profileIdx < row.length
              ? ExcelUtils.getCellValue(row[profileIdx])
              : activeProfileId,
        );
        await _storage.saveAccount(acc);
        existingAccountsMutex.add(acc); // Keep generic list updated
        resultCounts['accounts'] = resultCounts['accounts']! + 1;
      } catch (_) {}
    }
  }

  Future<void> _importLoans(Sheet sheet, Map<String, int> resultCounts,
      String activeProfileId) async {
    final headers = sheet.rows.first;
    final existingLoans = _storage.getLoans().map((e) => e.id).toSet();

    final idIdx = ExcelUtils.findColumn(headers, ['id', 'loanid']);
    final nameIdx = ExcelUtils.findColumn(headers, ['name', 'loanname']);
    if (nameIdx == -1) return;

    final typeIdx = ExcelUtils.findColumn(headers, ['type']);
    final principalIdx =
        ExcelUtils.findColumn(headers, ['totalprincipal', 'principal']);
    final remPrincipalIdx =
        ExcelUtils.findColumn(headers, ['remainingprincipal', 'balance']);
    final rateIdx = ExcelUtils.findColumn(headers, ['interestrate', 'rate']);
    final tenureIdx =
        ExcelUtils.findColumn(headers, ['tenuremonths', 'tenure']);
    final emiIdx = ExcelUtils.findColumn(headers, ['emiamount', 'emi']);
    final emiDayIdx = ExcelUtils.findColumn(headers, ['emiday', 'day']);
    final startIdx = ExcelUtils.findColumn(headers, ['startdate', 'date']);
    final firstEmiIdx =
        ExcelUtils.findColumn(headers, ['firstemidate', 'firstdate']);
    final accIdIdx = ExcelUtils.findColumn(headers, ['accountid']);
    final profileIdx = ExcelUtils.findColumn(headers, ['profileid']);

    for (var row in sheet.rows.skip(1)) {
      try {
        if (row.length <= nameIdx) continue;
        final id = idIdx != -1 && idIdx < row.length
            ? ExcelUtils.getCellValue(row[idIdx])
            : '';
        if (id.isNotEmpty && existingLoans.contains(id)) continue;

        final name = ExcelUtils.getCellValue(row[nameIdx]);
        if (name.isEmpty) continue;

        final loan = Loan(
          id: id.isEmpty ? const Uuid().v4() : id,
          name: name,
          type: LoanType.values.firstWhere(
              (e) =>
                  e.name.toLowerCase() ==
                  (typeIdx != -1
                      ? ExcelUtils.getCellValue(row[typeIdx]).toLowerCase()
                      : 'personal'),
              orElse: () => LoanType.personal),
          totalPrincipal: principalIdx != -1
              ? ExcelUtils.getDoubleValue(row[principalIdx])
              : 0.0,
          remainingPrincipal: remPrincipalIdx != -1
              ? ExcelUtils.getDoubleValue(row[remPrincipalIdx])
              : 0.0,
          interestRate:
              rateIdx != -1 ? ExcelUtils.getDoubleValue(row[rateIdx]) : 0.0,
          tenureMonths: tenureIdx != -1
              ? int.tryParse(ExcelUtils.getCellValue(row[tenureIdx])) ?? 0
              : 0,
          emiAmount:
              emiIdx != -1 ? ExcelUtils.getDoubleValue(row[emiIdx]) : 0.0,
          emiDay: emiDayIdx != -1
              ? int.tryParse(ExcelUtils.getCellValue(row[emiDayIdx])) ?? 1
              : 1,
          startDate: ExcelUtils.getDateTimeValue(
                  startIdx != -1 ? row[startIdx] : null) ??
              DateTime.now(),
          firstEmiDate: ExcelUtils.getDateTimeValue(
                  firstEmiIdx != -1 ? row[firstEmiIdx] : null) ??
              DateTime.now(),
          accountId:
              accIdIdx != -1 ? ExcelUtils.getCellValue(row[accIdIdx]) : null,
          transactions: [],
          profileId: profileIdx != -1 && profileIdx < row.length
              ? ExcelUtils.getCellValue(row[profileIdx])
              : activeProfileId,
        );
        if (loan.accountId?.isEmpty ?? false) loan.accountId = null;
        await _storage.saveLoan(loan);
        resultCounts['loans'] = resultCounts['loans']! + 1;
      } catch (_) {}
    }
  }

  Future<void> _importCategories(Sheet sheet, Map<String, int> resultCounts,
      String activeProfileId) async {
    final headers = sheet.rows.first;
    final existingCats = _storage
        .getCategories()
        .map((c) => c.name.toLowerCase().trim())
        .toSet();

    final nameIdx = ExcelUtils.findColumn(headers, ['name', 'categoryname']);
    if (nameIdx == -1) return;

    final usageIdx = ExcelUtils.findColumn(headers, ['usage', 'type']);
    final tagIdx = ExcelUtils.findColumn(headers, ['tag']);
    final idIdx = ExcelUtils.findColumn(headers, ['id']);
    final iconIdx = ExcelUtils.findColumn(headers, ['iconcode']);
    final profileIdx = ExcelUtils.findColumn(headers, ['profileid']);

    for (var row in sheet.rows.skip(1)) {
      try {
        if (row.length <= nameIdx) continue;
        final name = ExcelUtils.getCellValue(row[nameIdx]);
        if (name.isEmpty || existingCats.contains(name.toLowerCase())) continue;

        final usageStr = usageIdx != -1
            ? ExcelUtils.getCellValue(row[usageIdx]).toLowerCase()
            : 'both';
        final tagStr = tagIdx != -1
            ? ExcelUtils.getCellValue(row[tagIdx]).toLowerCase()
            : 'none';

        final cat = Category(
          id: idIdx != -1 && ExcelUtils.getCellValue(row[idIdx]).isNotEmpty
              ? ExcelUtils.getCellValue(row[idIdx])
              : const Uuid().v4(),
          name: name,
          usage: CategoryUsage.values.firstWhere(
              (e) => e.name.toLowerCase() == usageStr,
              orElse: () => CategoryUsage.both),
          tag: CategoryTag.values.firstWhere(
              (e) => e.name.toLowerCase() == tagStr,
              orElse: () => CategoryTag.none),
          iconCode: iconIdx != -1
              ? int.tryParse(ExcelUtils.getCellValue(row[iconIdx])) ?? 0
              : 0,
          profileId: profileIdx != -1 && profileIdx < row.length
              ? ExcelUtils.getCellValue(row[profileIdx])
              : activeProfileId,
        );
        await _storage.addCategory(cat);
        resultCounts['categories'] = resultCounts['categories']! + 1;
      } catch (_) {}
    }
  }

  Future<void> _importTransactions(Sheet sheet, Map<String, int> resultCounts,
      String activeProfileId, List<Account> accounts) async {
    final headers = sheet.rows.first;
    final titleIdx = ExcelUtils.findColumn(
        headers, ['title', 'description', 'narration', 'payee']);
    final amountIdx =
        ExcelUtils.findColumn(headers, ['amount', 'sum', 'value']);

    if (titleIdx == -1 || amountIdx == -1) return;

    final idIdx = ExcelUtils.findColumn(headers, ['id']);
    final dateIdx =
        ExcelUtils.findColumn(headers, ['date', 'datetime', 'time']);
    final typeIdx =
        ExcelUtils.findColumn(headers, ['type', 'transactiontype', 'txntype']);
    final catIdx = ExcelUtils.findColumn(headers, ['category', 'cat']);
    final accIdIdx = ExcelUtils.findColumn(headers, ['accountid', 'accid']);
    final accNameIdx =
        ExcelUtils.findColumn(headers, ['accountname', 'account']);
    final toAccIdx =
        ExcelUtils.findColumn(headers, ['toaccountid', 'toaccount']);
    final loanIdIdx = ExcelUtils.findColumn(headers, ['loanid']);
    final recurIdx = ExcelUtils.findColumn(
        headers, ['isrecurring', 'isrecurringinstance', 'recurring']);
    final delIdx = ExcelUtils.findColumn(headers, ['isdeleted', 'deleted']);
    final gainIdx = ExcelUtils.findColumn(headers, ['gainamount', 'gain']);
    final tenureIdx = ExcelUtils.findColumn(headers,
        ['holdingtenuremonths', 'holdingtenure', 'tenuremonths', 'tenure']);
    final profileIdx = ExcelUtils.findColumn(headers, ['profileid']);

    final List<Transaction> transactionsToSave = [];

    for (var row in sheet.rows.skip(1)) {
      try {
        if (row.length <= titleIdx || row.length <= amountIdx) continue;

        final title = ExcelUtils.getCellValue(row[titleIdx]);
        if (title.isEmpty) continue;

        final amount = ExcelUtils.getDoubleValue(row[amountIdx]);

        final typeStr = typeIdx != -1 && typeIdx < row.length
            ? ExcelUtils.getCellValue(row[typeIdx]).toLowerCase()
            : 'expense';

        final accountName = accNameIdx != -1 && accNameIdx < row.length
            ? ExcelUtils.getCellValue(row[accNameIdx])
            : 'Default Account';

        String finalAccountId = accIdIdx != -1 && accIdIdx < row.length
            ? ExcelUtils.getCellValue(row[accIdIdx])
            : '';

        // Account Resolution Logic
        if (finalAccountId.isEmpty ||
            finalAccountId.toLowerCase() == 'manual' ||
            !accounts.any((a) => a.id == finalAccountId)) {
          final matchedAcc = accounts.firstWhere(
              (a) => a.name.toLowerCase() == accountName.toLowerCase(),
              orElse: () => Account.empty());

          if (matchedAcc.id.isNotEmpty) {
            finalAccountId = matchedAcc.id;
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

        final toAccountId = toAccIdx != -1 && toAccIdx < row.length
            ? ExcelUtils.getCellValue(row[toAccIdx])
            : null;

        // Type Logic
        final isTransferAuto = typeStr.contains('transfer') ||
            (toAccountId != null && toAccountId.isNotEmpty);
        final finalType = typeStr.contains('income')
            ? TransactionType.income
            : isTransferAuto
                ? TransactionType.transfer
                : TransactionType.expense;

        String finalId = idIdx != -1
            ? ExcelUtils.getCellValue(row[idIdx])
            : const Uuid().v4();
        if (finalId.isEmpty) finalId = const Uuid().v4();

        final txn = Transaction(
          id: finalId,
          title: title,
          amount: amount.abs(),
          date: ExcelUtils.getDateTimeValue(
                  dateIdx != -1 ? row[dateIdx] : null) ??
              DateTime.now(),
          type: finalType,
          category: catIdx != -1
              ? ExcelUtils.getCellValue(row[catIdx])
              : 'Miscellaneous',
          accountId: finalAccountId,
          toAccountId: toAccountId?.isEmpty == true ? null : toAccountId,
          loanId:
              loanIdIdx != -1 ? ExcelUtils.getCellValue(row[loanIdIdx]) : null,
          isRecurringInstance: recurIdx != -1 && recurIdx < row.length
              ? ExcelUtils.getCellValue(row[recurIdx]).toLowerCase() == 'true'
              : false,
          isDeleted: delIdx != -1 && delIdx < row.length
              ? ExcelUtils.getCellValue(row[delIdx]).toLowerCase() == 'true'
              : false,
          gainAmount:
              gainIdx != -1 ? ExcelUtils.getDoubleValue(row[gainIdx]) : null,
          holdingTenureMonths: tenureIdx != -1
              ? int.tryParse(ExcelUtils.getCellValue(row[tenureIdx]))
              : null,
          profileId: profileIdx != -1 && profileIdx < row.length
              ? ExcelUtils.getCellValue(row[profileIdx])
              : activeProfileId,
        );

        if (txn.type == TransactionType.transfer &&
            txn.accountId != null &&
            txn.accountId == txn.toAccountId) {
          resultCounts['skipped_selftransfer'] =
              (resultCounts['skipped_selftransfer'] ?? 0) + 1;
          continue;
        }

        transactionsToSave.add(txn);
        resultCounts['transactions'] = resultCounts['transactions']! + 1;
      } catch (_) {
        resultCounts['skipped_error'] =
            (resultCounts['skipped_error'] ?? 0) + 1;
      }
    }
    await _storage.saveTransactions(transactionsToSave, applyImpact: false);
  }

  Future<void> _importLoanTransactions(
      Sheet sheet,
      Map<String, int> resultCounts,
      Map<String, List<LoanTransaction>> loanTxnsMap) async {
    final headers = sheet.rows.first;
    final loanIdIdx = ExcelUtils.findColumn(headers, ['loanid']);
    if (loanIdIdx == -1) return;

    final idIdx = ExcelUtils.findColumn(headers, ['id', 'txnid']);
    final dateIdx = ExcelUtils.findColumn(headers, ['date']);
    final typeIdx = ExcelUtils.findColumn(headers, ['type']);
    final amountIdx = ExcelUtils.findColumn(headers, ['amount']);
    final prinIdx = ExcelUtils.findColumn(headers, ['principalcomponent']);
    final intIdx = ExcelUtils.findColumn(headers, ['interestcomponent']);
    final resIdx = ExcelUtils.findColumn(headers, ['resultantprincipal']);

    for (var row in sheet.rows.skip(1)) {
      try {
        if (row.length <= loanIdIdx) continue;
        final loanId = ExcelUtils.getCellValue(row[loanIdIdx]);
        if (loanId.isEmpty) continue;

        final typeStr = typeIdx != -1 && typeIdx < row.length
            ? ExcelUtils.getCellValue(row[typeIdx]).toLowerCase()
            : 'emi';

        final rawId = idIdx != -1 ? ExcelUtils.getCellValue(row[idIdx]) : '';
        final validId = rawId.isEmpty ? const Uuid().v4() : rawId;

        final txn = LoanTransaction(
          id: validId,
          date: ExcelUtils.getDateTimeValue(
                  dateIdx != -1 ? row[dateIdx] : null) ??
              DateTime.now(),
          amount:
              amountIdx != -1 ? ExcelUtils.getDoubleValue(row[amountIdx]) : 0.0,
          type: LoanTransactionType.values.firstWhere(
              (e) => e.name.toLowerCase() == typeStr,
              orElse: () => LoanTransactionType.emi),
          principalComponent:
              prinIdx != -1 ? ExcelUtils.getDoubleValue(row[prinIdx]) : 0.0,
          interestComponent:
              intIdx != -1 ? ExcelUtils.getDoubleValue(row[intIdx]) : 0.0,
          resultantPrincipal:
              resIdx != -1 ? ExcelUtils.getDoubleValue(row[resIdx]) : 0.0,
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
}
