// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override // coverage:ignore-line
  String get appTitle => 'Samriddhi Flow';

  @override
  String get mySamriddhi => 'My Samriddhi';

  @override
  String get defaultVal => 'Default';

  @override
  String profileLabel(String name) {
    return 'Profile: $name';
  }

  @override
  String get remindersTooltip => 'Reminders';

  @override // coverage:ignore-line
  String get lockAppTooltip => 'Lock App';

  @override
  String get logoutTooltip => 'Logout';

  @override
  String get quickActionsHeader => 'Quick Actions';

  @override
  String get recentTransactionsHeader => 'Recent Transactions';

  @override
  String get viewAllButton => 'View All';

  @override
  String get totalNetWorthLabel => 'Total Net Worth';

  @override
  String get currentSavingsLabel => 'Current Savings: ';

  @override
  String get ccBillUnpaidLabel => 'CC Bill (Unpaid)';

  @override
  String get ccUnbilledLabel => 'CC Unbilled';

  @override
  String get ccUsageLabel => 'CC Usage';

  @override // coverage:ignore-line
  String get totalLoanLiabilityLabel => 'Total Loan Liability';

  @override // coverage:ignore-line
  String debtFreeIn(String months, int days) {
    return 'Debt Free in ~$months months ($days days)'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get incomeMonthLabel => 'Income (Month)';

  @override // coverage:ignore-line
  String get budgetExpenseLabel => 'Budget Expense';

  @override
  String get monthlyBudgetProgress => 'Monthly Budget Progress';

  @override
  String get expLabel => 'Exp: ';

  @override
  String get remLabel => 'Rem: ';

  @override
  String get incomeAction => 'Income';

  @override
  String get transferAction => 'Transfer';

  @override
  String get payBillAction => 'Pay Bill';

  @override
  String get loansAction => 'Loans';

  @override
  String get taxesAction => 'Taxes';

  @override
  String get lendingAction => 'Lending';

  @override
  String get noTransactionsYet => 'No transactions yet.';

  @override
  String unsavedDataTitle(int count) {
    return 'Unsaved Data: $count transactions recorded since last backup.';
  }

  @override
  String get goToBackupButton => 'Go to Backup';

  @override
  String get dismissButton => 'Dismiss';

  @override
  String get homeTooltip => 'Home';

  @override
  String get accountsTooltip => 'Accounts';

  @override
  String get reportsTooltip => 'Reports';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get privacyPolicyTitle => 'Samriddhi Flow — Privacy Policy';

  @override
  String get privacyPolicyIntro =>
      'Your privacy is important to us. Here is how Samriddhi Flow handles your data:';

  @override
  String get localFirstTitle => 'Local-First Storage';

  @override
  String get localFirstDesc =>
      'All your financial data is stored locally on your device by default. Nothing leaves your device unless you choose to back up.';

  @override
  String get cloudBackupTitle => 'Cloud Backup';

  @override
  String get cloudBackupDesc =>
      'Secure your sensitive financial data (accounts, transactions, etc.) with a passcode. This passcode is NEVER stored and is required to restore.';

  @override
  String get optionalEncryptionTitle => 'Optional Encryption';

  @override
  String get optionalEncryptionDesc =>
      'When backing up to the cloud, you can encrypt your data with a passcode of your choice. This passcode is NEVER stored anywhere — only you know it. Without the passcode, your cloud data cannot be read.';

  @override
  String get noTrackingTitle => 'No Tracking or Analytics';

  @override
  String get noTrackingDesc =>
      'Samriddhi Flow does not collect, track, or transmit any usage analytics, personal information, or behavioral data.';

  @override
  String get dataControlTitle => 'Your Data, Your Control';

  @override
  String get dataControlDesc =>
      'You can export, restore, or delete all your data at any time from the Settings screen. We believe you should have full ownership of your financial information.';

  @override
  String get singleDeviceAccessTitle => 'Single Device Access';

  @override
  String get singleDeviceAccessDesc =>
      'When using cloud sync features, only one device is allowed per account for security. We maintain only a randomly generated session ID of your latest device for matching purpose, with no links to track your identity or behavior. This session ID is removed when you log out.';

  @override
  String get closeButton => 'Close';

  @override // coverage:ignore-line
  String switchProfileTooltip(String name) {
    return 'Switch Profile ($name)'; // coverage:ignore-line
  }

  @override
  String get myAccounts => 'My Accounts';

  @override
  String get extendedNumbersTooltip => 'Switch to Extended Numbers';

  @override
  String get compactNumbersTooltip => 'Switch to Compact Numbers';

  @override
  String get noAccountsFound => 'No accounts found.';

  @override
  String get addAccountButton => 'Add Account';

  @override
  String get pinnedAccountsHeader => 'Pinned Accounts';

  @override
  String get savingsAccountsHeader => 'Savings Accounts';

  @override
  String get creditCardsHeader => 'Credit Cards';

  @override
  String get walletsHeader => 'Wallets';

  @override
  String get noAccountsInSection => 'No accounts in this section.';

  @override
  String get addNewAccountButton => 'Add New Account';

  @override
  String get savingsAccountType => 'Savings Account';

  @override // coverage:ignore-line
  String get walletType => 'Wallet';

  @override // coverage:ignore-line
  String limitLabel(String value) {
    return 'Credit Limit: $value'; // coverage:ignore-line
  }

  @override
  String limitShort(String value) {
    return 'Limit: $value';
  }

  @override // coverage:ignore-line
  String availableLabel(String value) {
    return 'Available: $value'; // coverage:ignore-line
  }

  @override
  String availableShort(String value) {
    return 'Avail: $value';
  }

  @override // coverage:ignore-line
  String get billedChip => 'Billed';

  @override
  String get balanceChip => 'Balance';

  @override // coverage:ignore-line
  String get unbilledChip => 'Unbilled';

  @override // coverage:ignore-line
  String get calculatesOn => 'Calculates on';

  @override // coverage:ignore-line
  String get initialBillOn => 'Initial bill on';

  @override
  String percentUsed(String value) {
    return '$value% used';
  }

  @override // coverage:ignore-line
  String get unpinAccount => 'Unpin Account';

  @override
  String get pinAccount => 'Pin Account';

  @override
  String get viewTransactions => 'View Transactions';

  @override
  String get editAccount => 'Edit Account';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String lastBillDate(String date) {
    return 'Last Bill Date: $date';
  }

  @override
  String nextBillDate(String date) {
    return 'Next Bill Date: $date';
  }

  @override // coverage:ignore-line
  String get updateBillingCycle => 'Update Billing Cycle';

  @override // coverage:ignore-line
  String get updateBillingCycleDesc =>
      'Move to a new cycle day or due date safely';

  @override
  String get selectAllTooltip => 'Select All (Filtered)';

  @override
  String get allTransactionsTitle => 'All Transactions';

  @override
  String selectedCount(int count) {
    return '$count Selected';
  }

  @override
  String get selectTransactionsTooltip => 'Select Transactions';

  @override
  String get noAccountManual => 'No Account (Manual)';

  @override // coverage:ignore-line
  String get noMatchesFilter => 'No matches for this filter.';

  @override
  String deleteSelectedTitle(int count) {
    return 'Delete $count Transactions?';
  }

  @override
  String get itemsMoveToRecycleBin => 'Items will be moved to Recycle Bin.';

  @override
  String get transactionsMovedToRecycleBin =>
      'Transactions moved to Recycle Bin';

  @override // coverage:ignore-line
  String get deleteTransactionTitle => 'Delete Transaction?';

  @override // coverage:ignore-line
  String get movedToRecycleBin => 'Moved to Recycle Bin';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get deleteAction => 'Delete';

  @override
  String get salaryTab => 'Salary';

  @override
  String get housePropTab => 'House Prop';

  @override
  String get businessTab => 'Business';

  @override
  String get capGainsTab => 'Cap Gains';

  @override
  String get dividendTab => 'Dividend';

  @override
  String get taxPaidTab => 'Tax Paid';

  @override
  String get giftsTab => 'Gifts';

  @override
  String get agriTab => 'Agri';

  @override
  String get otherTab => 'Other';

  @override // coverage:ignore-line
  String categoryDataClearedStatus(String category) {
    return '$category data cleared.'; // coverage:ignore-line
  }

  @override
  String get taxDataClearedStatus =>
      'All tax data for the fiscal year has been cleared.';

  @override
  String get switchCategoryTitle => 'Switch Category';

  @override
  String get approxGrossIncomeLabel => 'Approx. Gross Income';

  @override
  String get unsavedChangesTitle => 'Unsaved Changes';

  @override
  String get unsavedChangesContent =>
      'You have unsaved changes. Do you want to discard them and leave?';

  @override // coverage:ignore-line
  String get discardAction => 'Discard';

  @override
  String get dividendIncomeBreakdownTitle => 'Dividend Income Breakdown';

  @override
  String get totalDividendIncomeLabel => 'Total Dividend Income';

  @override
  String get salaryStructuresTitle => 'Salary Structures';

  @override
  String get addStructureAction => 'Add Structure';

  @override
  String get effectiveLabel => 'Effective';

  @override
  String get exemptionsDeductionsTitle => 'Exemptions & Deductions (Yearly)';

  @override
  String get independentAllowancesTitle => 'Independent Allowances';

  @override
  String get noIndependentAllowancesNote => 'No independent allowances added.';

  @override
  String get addIndependentAllowanceAction => 'Add Independent Allowance';

  @override
  String get independentDeductionsTitle => 'Independent Deductions';

  @override
  String get noIndependentDeductionsNote => 'No independent deductions added.';

  @override
  String get addIndependentDeductionAction => 'Add Independent Deduction';

  @override
  String get netMonthlyLabel => 'NET MONTHLY';

  @override
  String get monthlyTakeHomeBreakdownTitle => 'Monthly Take-home Breakdown';

  @override
  String get housePropertiesTitle => 'House Properties';

  @override
  String get addPropertyAction => 'Add Property';

  @override
  String get totalRentReceivedLabel => 'Total Rent Received';

  @override
  String get totalInterestOnLoanLabel => 'Total Interest on Loan';

  @override
  String get noHousePropertiesNote =>
      'No house properties found for this year.';

  @override
  String get projectedAnnualIncomeTitle =>
      'Projected Annual Income (Interactive Summary)';

  @override
  String get totalGrossSalaryLabel => 'Total Gross Salary';

  @override
  String get lessStandardDeductionLabel => 'Less: Standard Deduction';

  @override // coverage:ignore-line
  String get lessStatutoryExemptionsLabel => 'Less: Statutory Exemptions';

  @override
  String get totalTaxableSalaryIncomeLabel => 'Total Taxable Salary Income';

  @override
  String get selfOccupiedLabel => 'Self Occupied';

  @override
  String get businessProfessionTitle => 'Business & Profession';

  @override
  String get addBusinessAction => 'Add Business';

  @override
  String get totalTurnoverLabel => 'Total Turnover';

  @override
  String get totalNetIncomeLabel => 'Total Net Income';

  @override
  String get taxableBusinessIncomeLabel => 'Taxable Business Income';

  @override
  String get noBusinessIncomeNote => 'No business income found for this year.';

  @override
  String get businessNameLabel => 'Business Name';

  @override
  String get grossTurnoverReceiptsLabel => 'Gross Turnover / Receipts';

  @override
  String get netIncomeProfitLabel => 'Net Income / Profit';

  @override
  String get actualProfitHelper => 'Actual net profit from business';

  @override
  String get taxationTypeLabel => 'Taxation Type';

  @override
  String get presumptiveTaxationHelper =>
      'Presumptive taxation allows computing tax on a percentage of turnover.';

  @override // coverage:ignore-line
  String turnoverExceedsLimitWarning(String limit) {
    return 'Turnover exceeds limit of $limit for presumptive taxation.'; // coverage:ignore-line
  }

  @override
  String get capitalGainsTitle => 'Capital Gains';

  @override
  String get netCapitalGainsSummaryTitle => 'Net Capital Gains Summary';

  @override
  String get longTermEquityLabel => 'Long Term (Equity)';

  @override
  String get longTermOtherLabel => 'Long Term (Other)';

  @override
  String get assetSoldLabel => 'Asset Sold';

  @override
  String get saleAmountLabel => 'Sale Amount';

  @override
  String get gainDateLabel => 'Gain Date';

  @override
  String get intendToReinvestLabel => 'Intend to Reinvest?';

  @override
  String get reinvestmentExemptionsSubtitle => 'Section 54/54F/54EC exemptions';

  @override // coverage:ignore-line
  String get reinvestmentDetailsTitle => 'Reinvestment Details';

  @override // coverage:ignore-line
  String get pendingNotDecidedLabel => 'Pending / Not Decided';

  @override // coverage:ignore-line
  String get amountInvestedLabel => 'Amount Invested';

  @override // coverage:ignore-line
  String get reinvestDateLabel => 'Reinvest Date';

  @override
  String get deleteButton => 'Delete';

  @override
  String get otherSourcesTitle => 'Other Sources';

  @override
  String get addOtherIncomeAction => 'Add Other Income';

  @override
  String get dividendsLabel => 'Dividends';

  @override
  String get taxableOtherIncomeLabel => 'Taxable Other Income';

  @override
  String get noOtherIncomeNote => 'No Other Income added.';

  @override
  String get incomeTypeLabel => 'Income Type';

  @override
  String grossAmountCurrencyLabel(String symbol) {
    return 'Gross Amount ($symbol)';
  }

  @override // coverage:ignore-line
  String get linkExemptionOptionalLabel => 'Link Exemption (Optional)';

  @override
  String get allFilterLabel => 'All';

  @override
  String get manualFilterLabel => 'Manual';

  @override
  String get syncedFilterLabel => 'Synced';

  @override
  String get advanceTaxScheduleHintsTitle => 'Advance Tax Schedule Hints';

  @override
  String advanceTaxBreakdownLabel(String base, String cess, String interest) {
    return 'Base: $base • Cess: $cess • Interest: $interest';
  }

  @override // coverage:ignore-line
  String advanceTaxBreakdownLabelNoInterest(String base, String cess) {
    return 'Base: $base • Cess: $cess'; // coverage:ignore-line
  }

  @override
  String get noEntriesFoundNote => 'No entries found.';

  @override
  String sourceLabel(String source) {
    return 'Source: $source';
  }

  @override
  String get sourceDescriptionLabel => 'Source/Description';

  @override
  String get cashGiftsTotalTitle => 'Cash Gifts (Total)';

  @override
  String get addGiftAction => 'Add Gift';

  @override
  String get totalGiftsReceivedLabel => 'Total Gifts Received';

  @override
  String get taxablePortionLabel => 'Taxable Portion';

  @override
  String get giftDescriptionSourceLabel => 'Gift Description / Source';

  @override
  String get giftTypeLabel => 'Gift Type';

  @override
  String get netAgriIncomeLabel => 'Net Agricultural Income';

  @override // coverage:ignore-line
  String get noEntriesMatchFilteringNote =>
      'No entries match the current filters.';

  @override // coverage:ignore-line
  String get payoutMonthLabel => 'Payout Month';

  @override
  String get startMonthLabel => 'Start Month';

  @override // coverage:ignore-line
  String get deductionNameLabel => 'Deduction Name';

  @override // coverage:ignore-line
  String get allowanceNameLabel => 'Allowance Name';

  @override // coverage:ignore-line
  String get annualDeductionAmountLabel => 'Annual Deduction Amount';

  @override // coverage:ignore-line
  String get annualPayoutAmountLabel => 'Annual Payout Amount';

  @override // coverage:ignore-line
  String get exemptionLimitLabel => 'Exemption Limit';

  @override // coverage:ignore-line
  String get monthlyAmountsLabel => 'Monthly Amounts';

  @override // coverage:ignore-line
  String get noPayoutMonthsSelectedNote => 'No payout months selected.';

  @override
  String get unemploymentNoSalaryTitle => 'Unemployment / No Salary Periods';

  @override
  String get effectiveDateLabel => 'Effective Date';

  @override
  String get annualBasicPayLabel => 'Annual Basic Pay (CTC)';

  @override
  String get annualFixedAllowancesLabel => 'Annual Fixed Allowances (CTC)';

  @override
  String get annualPerformancePayLabel => 'Annual Performance Pay';

  @override
  String get annualVariablePayLabel => 'Annual Variable Pay';

  @override
  String get payoutLabel => 'Payout';

  @override
  String get annualEmployeePFLabel => 'Annual Employee PF';

  @override
  String get annualGratuityContributionLabel => 'Annual Gratuity Contribution';

  @override
  String get customAllowancesTitle => 'Custom Allowances';

  @override
  String get noCustomAllowancesNote => 'No custom allowances';

  @override
  String get addTransactionTitle => 'Add Transaction';

  @override
  String get editTransactionTitle => 'Edit Transaction';

  @override
  String get expenseType => 'Expense';

  @override
  String get incomeType => 'Income';

  @override
  String get transferType => 'Transfer';

  @override
  String get categoryLabel => 'Category';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get requiredError => 'Required';

  @override
  String get fromAccountLabel => 'From Account';

  @override
  String get accountLabel => 'Account';

  @override
  String get toAccountLabel => 'To Account';

  @override
  String get selectRecipient => 'Select Recipient';

  @override
  String get amountLabel => 'Amount';

  @override
  String get invalidAmountError => 'Invalid Amount';

  @override
  String get makeRecurring => 'Make Recurring';

  @override
  String get repeatAutomatically => 'Repeat this transaction automatically';

  @override
  String get recurringAction => 'Recurring Action';

  @override
  String get payAndSchedule => 'Pay & Schedule';

  @override
  String get justSchedule => 'Just Schedule';

  @override // coverage:ignore-line
  String firstExecution(String date) {
    return 'First Execution: $date'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String frequencyLabel(String label) {
    return 'Frequency: $label'; // coverage:ignore-line
  }

  @override
  String get scheduleTypeLabel => 'Schedule Type';

  @override
  String get adjustForHolidays => 'Adjust for Holidays';

  @override
  String get adjustForHolidaysDesc =>
      'Schedule a day earlier if it lands on a holiday/weekend';

  @override
  String get selectWeekdayLabel => 'Select Weekday';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get saveTransaction => 'Save Transaction';

  @override
  String get updateTransaction => 'Update Transaction';

  @override
  String get capitalGainProfitAmount => 'Gain / Profit Amount';

  @override
  String get holdingTenureMonths => 'Holding Tenure (Months)';

  @override
  String get holdingTenureHint => 'e.g., 12';

  @override
  String get holdingTenureHelper =>
      'Enter months held (Long-term: 12+ months for stocks)';

  @override
  String get profitLabel => 'Profit';

  @override // coverage:ignore-line
  String get lossLabel => 'Loss';

  @override
  String get purchaseCostLabel => 'Purchase Cost';

  @override
  String get gainAmountHelper =>
      'Enter the profit (positive) or loss (negative)';

  @override
  String get noTransactionsFound => 'No transactions found.';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get fixedDate => 'Fixed Date';

  @override
  String get everyWeekend => 'Every Weekend';

  @override
  String get lastWeekend => 'Last Weekend';

  @override
  String get lastDayOfMonth => 'Last Day of Month';

  @override
  String get lastWorkingDay => 'Last Working Day';

  @override
  String get firstWorkingDay => 'First Working Day';

  @override
  String get specificWeekday => 'Specific Weekday';

  @override
  String get capitalGainTag => 'Capital Gain';

  @override // coverage:ignore-line
  String get directTaxTag => 'Direct Tax';

  @override // coverage:ignore-line
  String get budgetFreeTag => 'Budget Free';

  @override // coverage:ignore-line
  String get taxFreeTag => 'Tax Free';

  @override // coverage:ignore-line
  String usageShort(String amount) {
    return 'Usage: $amount'; // coverage:ignore-line
  }

  @override
  String balanceShort(String amount) {
    return 'Bal: $amount';
  }

  @override
  String get financialReportsTitle => 'Financial Reports';

  @override
  String get noDataAvailable => 'No data available.';

  @override
  String get noDataSelectedCriteria => 'No data for selected criteria.';

  @override
  String get spendingReport => 'Spending';

  @override
  String get incomeReport => 'Income';

  @override
  String get loanReport => 'Loan';

  @override
  String get periodLabel => 'Period';

  @override
  String get days30 => '30 Days';

  @override
  String get days90 => '90 Days';

  @override
  String get lastYear => 'Last Year';

  @override
  String get monthOption => 'Month';

  @override
  String get yearOption => 'Year';

  @override
  String get allTime => 'All Time';

  @override
  String get loanLabel => 'Loan';

  @override
  String get allLoans => 'All Loans';

  @override
  String get typeLabel => 'Type';

  @override
  String get allOption => 'All';

  @override
  String get allAccounts => 'All Accounts';

  @override
  String get manualNoAccount => 'Manual (No Account)';

  @override
  String get filterCategories => 'Filter Categories';

  @override
  String categoriesExcluded(int count) {
    return '$count Categories Excluded';
  }

  @override // coverage:ignore-line
  String get selectMonthLabel => 'Select Month';

  @override // coverage:ignore-line
  String get selectYearLabel => 'Select Year';

  @override
  String get totalLiability => 'Total Liability';

  @override
  String get emiPaid => 'EMI Paid';

  @override
  String get prepayment => 'Prepayment';

  @override // coverage:ignore-line
  String get totalPaid => 'Total Paid';

  @override
  String get totalLabel => 'Total';

  @override
  String get othersCategory => 'Others';

  @override
  String get capitalGainsRealized => 'Capital Gains (Realized)';

  @override // coverage:ignore-line
  String get capitalLossesRealized => 'Capital Losses (Realized)';

  @override
  String get expandCollapseTooltip => 'Expand/Collapse All';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get profileSettingsHeader => 'Profile Settings';

  @override // coverage:ignore-line
  String get globalSettingsHeader => 'Global App Settings';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get dashboardCustomizationSection => 'Dashboard Customization';

  @override
  String get cloudSyncSection => 'Cloud Sync';

  @override // coverage:ignore-line
  String get dataManagementSection => 'Data Management';

  @override
  String get profileDataSection => 'Data Cleanup & Recovery';

  @override
  String get globalDataSection => 'Local Backup & Export';

  @override
  String get featureManagementSection => 'Feature Management';

  @override // coverage:ignore-line
  String get profileManagementSection => 'Profile Management';

  @override
  String get preferencesSection => 'Preferences';

  @override
  String get authSection => 'Authentication';

  @override
  String get securitySection => 'Security';

  @override
  String get appInfoSection => 'App Info';

  @override
  String get themeModeLabel => 'Theme Mode';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get showIncomeExpenseLabel => 'Show Income & Expense';

  @override
  String get showIncomeExpenseDesc => 'Display monthly summary cards';

  @override
  String get showBudgetLabel => 'Show Budget Indicator';

  @override
  String get showBudgetDesc => 'Display monthly budget progress bar';

  @override // coverage:ignore-line
  String get connectionPaused => 'Connection Paused';

  @override // coverage:ignore-line
  String get offlineModeDesc =>
      'You are in Offline Mode. Cloud Sync is deferred.';

  @override // coverage:ignore-line
  String get retryConnection => 'Retry Connection';

  @override // coverage:ignore-line
  String get retryingConnection => 'Retrying connection...';

  @override // coverage:ignore-line
  String get internetRestored => 'Internet restored! Ready to sync.';

  @override // coverage:ignore-line
  String get stillOffline => 'Still offline. Check connection.';

  @override
  String get enableCloudSync => 'Enable Cloud Sync';

  @override
  String get enableCloudSyncDesc =>
      'Securely back up your data to the cloud and sync across devices.';

  @override
  String get loginToSetupCloud => 'Login to Setup Cloud';

  @override
  String accountLabelWithEmail(String email) {
    return 'Account: $email';
  }

  @override
  String get cloudSyncActive => 'Cloud Sync Active';

  @override
  String get categoriesEncryptionWarning =>
      'Note: Categories aren\'t encrypted in cloud currently.';

  @override
  String get migrateSyncNow => 'Migrate/Sync Now';

  @override
  String get recycleBinDesc => 'Restore deleted transactions';

  @override
  String get backupDataZipDesc => 'Export all data to a ZIP file';

  @override
  String get restoreDataZipDesc => 'Import data from a ZIP file';

  @override
  String get repairDataLabel => 'Repair Data';

  @override
  String get repairDataDesc => 'Fix data consistency issues';

  @override
  String get dataRepairTitle => 'Data Repair';

  @override
  String get runningRepair => 'Running repair...';

  @override
  String get manageRecurringPaymentsDesc => 'View or delete automated payments';

  @override
  String get holidayManagerDesc => 'Configure non-working days';

  @override
  String get manageCategoriesDesc => 'Add, edit, or delete categories';

  @override
  String get smartCalculatorLabel => 'Smart Calculator';

  @override
  String get smartCalculatorDesc => 'Enable Quick Sum Tracker on transactions';

  @override
  String get taxDashboardTitle => 'Tax Dashboard';

  @override
  String get taxYearLabel => 'Tax Year';

  @override // coverage:ignore-line
  String get capitalGains => 'Capital Gains';

  @override
  String get cessLabel => 'Cess';

  @override
  String get tdsTcsLabel => 'TDS / TCS Tracked';

  @override // coverage:ignore-line
  String get advanceTaxOverdue => 'Advance Tax Overdue!';

  @override
  String get manualLabel => 'Manual';

  @override // coverage:ignore-line
  String get autoLabel => 'Auto';

  @override // coverage:ignore-line
  String recurringPaymentCalendarDescription(String title) {
    return 'Recurring payment: $title'; // coverage:ignore-line
  }

  @override
  String get skipCycleTitle => 'Skip Cycle?';

  @override
  String skipCycleConfirmation(String title) {
    return 'Advance \"$title\" to the next cycle without recording a transaction?';
  }

  @override
  String get skipAction => 'SKIP';

  @override
  String get noTaxInstallmentsDue => 'No upcoming tax installments.';

  @override
  String get upcomingTaxInstallments => 'Upcoming Tax Installments';

  @override // coverage:ignore-line
  String daysLate(int days) {
    return '${days}d Late'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get dueToday => 'Due Today';

  @override
  String daysLeftLabel(int days) {
    return '$days d left';
  }

  @override
  String nextTaxInstallmentLabel(String amount, String date) {
    return 'Next: $amount due by $date';
  }

  @override // coverage:ignore-line
  String errorLabel(String message) {
    return 'Error: $message'; // coverage:ignore-line
  }

  @override
  String get upcomingAdvanceTax => 'Upcoming Advance Tax';

  @override
  String get insurancePortfolioTooltip => 'Insurance Portfolio';

  @override // coverage:ignore-line
  String get activeLabel => 'Active';

  @override // coverage:ignore-line
  String get tapToSwitchLabel => 'Tap to switch';

  @override
  String get copyCategoriesTooltip => 'Copy Categories from another profile';

  @override
  String get createProfileTitle => 'Create Profile';

  @override
  String get profileNameLabel => 'Profile Name';

  @override
  String get createButton => 'CREATE';

  @override
  String get currencyLabel => 'Currency';

  @override
  String get monthlyBudgetLabel => 'Monthly Budget';

  @override
  String get setMonthlyBudgetTitle => 'Set Monthly Budget';

  @override
  String get backupIntervalTitle => 'Backup Interval';

  @override
  String get updateApplicationDesc => 'Clear cache and reload latest version';

  @override // coverage:ignore-line
  String get installAppDesc => 'Add to Home Screen for Offline use';

  @override
  String get clearCloudDataDesc =>
      'Wipe current cloud backup while keeping your account connected for future syncs.';

  @override // coverage:ignore-line
  String get internetRequiredForUpdates =>
      'Internet connection required to check for updates.';

  @override // coverage:ignore-line
  String get checkingForUpdates => 'Checking for updates...';

  @override // coverage:ignore-line
  String get upToDateTitle => 'Up to Date';

  @override
  String get cloudSyncSuccess => 'Cloud Sync Success!';

  @override
  String syncErrorLabel(String error) {
    return 'Sync Error: $error';
  }

  @override // coverage:ignore-line
  String backupFailedLabel(String error) {
    return 'Backup Failed: $error'; // coverage:ignore-line
  }

  @override
  String get restoringFromZipTitle => 'Restoring from ZIP';

  @override
  String get areYouSure => 'Are you sure?';

  @override
  String get restoreZipWarning =>
      'This will PERMANENTLY WIPE all local data and replace it with the backup content.';

  @override
  String get restoreCompleteTitle => 'Restore Complete';

  @override
  String get restoredItemsLabel => 'Restored items:';

  @override // coverage:ignore-line
  String restoreFailedLabel(String error) {
    return 'Restore Failed: $error'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get cloudRestoreTitle => 'Cloud Restore';

  @override // coverage:ignore-line
  String get criticalWarningTitle => 'Critical Warning';

  @override // coverage:ignore-line
  String get useCloudRestoreQuestion => 'Use Cloud Restore?';

  @override
  String get clearCloudDataTitle => 'Clear Cloud Data (Keep Account)';

  @override // coverage:ignore-line
  String get clearButton => 'CLEAR';

  @override // coverage:ignore-line
  String get includePinInCloudBackup =>
      'Enter PIN to include it in your secure cloud backup.';

  @override // coverage:ignore-line
  String get includePinInZip => 'Enter PIN to include it in your backup ZIP.';

  @override
  String get backupReminderTitle => 'Backup Reminder';

  @override // coverage:ignore-line
  String get selectCreditCardTitle => 'Select Credit Card';

  @override // coverage:ignore-line
  String get claimOwnershipTitle => 'Claim Ownership?';

  @override // coverage:ignore-line
  String get claimOwnershipDesc =>
      'This account is currently active on another device. Taking ownership will allow you to Backup or Restore here, but will lock the other device out.';

  @override // coverage:ignore-line
  String get claimOwnershipAction => 'Claim Ownership';

  @override // coverage:ignore-line
  String get allCreditCardsLabel => 'All Credit Cards';

  @override
  String get loansScreenTitle => 'Loans';

  @override
  String monthsLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months left',
      one: '1 month left',
    );
    return '$_temp0';
  }

  @override // coverage:ignore-line
  String taxInitializationError(String error) {
    return 'Error initializing tax services: $error'; // coverage:ignore-line
  }

  @override
  String get taxableInsuranceAlertTitle => 'Taxable Insurance Payouts Detected';

  @override
  String taxableInsuranceAlertMessage(int year, int nextYear) {
    return 'Insurance policies crossing the 5L tax limit in FY $year-$nextYear have been detected. Ensure they are tracked for capital gains.';
  }

  @override
  String get viewPoliciesAction => 'View Policies';

  @override // coverage:ignore-line
  String get syncingStatus => 'Syncing data...';

  @override // coverage:ignore-line
  String get syncCompleteStatus => 'Data synchronized successfully!';

  @override // coverage:ignore-line
  String syncFailedStatus(String error) {
    return 'Sync failed: $error'; // coverage:ignore-line
  }

  @override
  String get capitalGainLabel => 'Capital Gain';

  @override // coverage:ignore-line
  String get expiredStatus => 'Expired';

  @override // coverage:ignore-line
  String get addReinvestmentTooltip => 'Add Reinvestment';

  @override // coverage:ignore-line
  String get capitalGainsTrackerTitle => 'Capital Gains Tracker';

  @override // coverage:ignore-line
  String capitalGainsTrackerSubtitle(double years) {
    return 'Tracking reinvestment deadlines for gains within $years years.'; // coverage:ignore-line
  }

  @override
  String get projectedTaxLiabilityTitle => 'Projected Tax Liability';

  @override
  String get grossIncomeLabel => 'Gross Income';

  @override
  String get capitalGainsLabel => 'Capital Gains';

  @override // coverage:ignore-line
  String get capitalGainsDeductionsLabel => 'Capital Gains Exemptions';

  @override
  String get deductionsLabel => 'Deductions';

  @override
  String get taxableIncomeLabel => 'Taxable Income';

  @override
  String get taxOnIncomeSlabLabel => 'Tax on Income (Slab)';

  @override
  String get taxOnCapitalGainsLabel => 'Tax on Capital Gains';

  @override
  String get totalTaxLiabilityLabel => 'Total Tax Liability';

  @override // coverage:ignore-line
  String get cessOnSalaryTdsLabel => 'Cess included in Salary TDS';

  @override // coverage:ignore-line
  String get cessOnOtherSlabLabel => 'Cess on Other Slab Tax';

  @override // coverage:ignore-line
  String get cessOnSpecialLabel => 'Capital Gains Cess';

  @override
  String get advanceTaxPaidLabel => 'Advance Tax Paid';

  @override // coverage:ignore-line
  String get taxShortfallInterestLabel => 'Tax Shortfall Interest';

  @override
  String get netTaxPayableLabel => 'Net Tax Payable';

  @override
  String suggestedItrLabel(String form) {
    return 'Suggested ITR form: $form';
  }

  @override
  String get advanceTaxOverdueTitle => 'Advance Tax OVERDUE';

  @override
  String get actionRequiredAdvanceTaxTitle => 'Action Required: Advance Tax';

  @override // coverage:ignore-line
  String get upcomingAdvanceTaxTitle => 'Upcoming Advance Tax';

  @override // coverage:ignore-line
  String advanceTaxNextDueMessage(String amount, String date) {
    return 'Next due: $amount by $date'; // coverage:ignore-line
  }

  @override
  String lateStatusDays(int days) {
    return '$days days late';
  }

  @override
  String get dueTodayStatus => 'DUE TODAY';

  @override
  String daysLeftStatus(int days) {
    return '$days days left';
  }

  @override // coverage:ignore-line
  String get taxRulesUpdatedStatus => 'Tax rules updated successfully.';

  @override
  String get addPolicyTitle => 'Add Insurance Policy';

  @override // coverage:ignore-line
  String get editPolicyTitle => 'Edit Insurance Policy';

  @override
  String get policyNameLabel => 'Policy Name';

  @override
  String annualPremiumLabel(String currency) {
    return 'Annual Premium ($currency)';
  }

  @override
  String sumAssuredLabel(String currency) {
    return 'Sum Assured ($currency)';
  }

  @override
  String get issueDateLabel => 'Issue Date';

  @override
  String get isUlipLabel => 'Is ULIP?';

  @override
  String get enableInstallmentLabel => 'Enable Installment?';

  @override // coverage:ignore-line
  String get installmentStartLabel => 'Installment Start';

  @override
  String get addToDashboardAction => 'Add to Dashboard';

  @override
  String get policiesListTab => 'Policies';

  @override
  String get taxRulesTab => 'Tax Rules';

  @override
  String get syncRecalculateTooltip => 'Recalculate Tax Status';

  @override
  String get yourPoliciesTitle => 'Your Policies';

  @override // coverage:ignore-line
  String get pendingCalcStatus => 'Pending Calculation';

  @override // coverage:ignore-line
  String get installmentsEnabledLabel => 'Installments Enabled';

  @override
  String get taxableStatus => 'Taxable';

  @override // coverage:ignore-line
  String get exemptStatus => 'Exempt';

  @override
  String get populateIncomeTooltip => 'Populate Taxable Income';

  @override
  String get populateTaxableIncomeTitle => 'Populate Taxable Income';

  @override
  String get taxHeadLabel => 'Tax Head';

  @override
  String get otherIncomeHead => 'Other Income';

  @override // coverage:ignore-line
  String get assetCategoryLabel => 'Asset Category';

  @override // coverage:ignore-line
  String get saleMaturityAmountLabel => 'Sale / Maturity Amount';

  @override
  String get costOfAcquisitionLabel => 'Cost of Acquisition';

  @override // coverage:ignore-line
  String get isLongTermLabel => 'Is Long Term?';

  @override // coverage:ignore-line
  String get incomeAlreadyAddedNote =>
      'Warning: Income for this year may already be present in Dashboard.';

  @override
  String incomeAddedSuccess(int year, int nextYear) {
    return 'Income for FY $year-$nextYear added to Dashboard targets.';
  }

  @override
  String get selectMonthsAction => 'Select Payout Months';

  @override
  String get coreSalarySection => 'Core Salary';

  @override
  String get payoutsSection => 'Irregular Payouts & Variable Pay';

  @override
  String get deductionsSection => 'Deductions & Unemployment';

  @override // coverage:ignore-line
  String get firstPayoutMonthLabel => 'First Payout Month';

  @override // coverage:ignore-line
  String get noMonthsSelectedNote => 'No months selected';

  @override // coverage:ignore-line
  String get addCustomAllowanceAction => 'Add Allowance';

  @override // coverage:ignore-line
  String get editAllowanceAction => 'Edit Allowance';

  @override // coverage:ignore-line
  String get payoutAmountLabel => 'Payout Amount';

  @override // coverage:ignore-line
  String get none => 'None';

  @override // coverage:ignore-line
  String get cliffExemptionTitle => 'Cliff-based Exemption';

  @override // coverage:ignore-line
  String get payoutFrequencyLabel => 'Payout Frequency';

  @override // coverage:ignore-line
  String get exemptionLimitHelperText =>
      'Income above this limit is fully taxable (no exemption applies).';

  @override // coverage:ignore-line
  String get cliffExemptionSubtitle =>
      'If checked, income above limit becomes fully taxable.';

  @override
  String get transactionDateLabel => 'Transaction Date';

  @override
  String get addEntryAction => 'Add Entry';

  @override // coverage:ignore-line
  String get adhocExemptionsLabel => 'Less: Ad-hoc Exemptions';

  @override // coverage:ignore-line
  String clearCategoryDataTitle(String category) {
    return 'Clear $category Data?'; // coverage:ignore-line
  }

  @override
  String get editDetailsAction => 'Edit Details';

  @override
  String get syncDataAction => 'Sync Data';

  @override
  String get taxConfigAction => 'Tax Config';

  @override
  String get syncTaxDataTitle => 'Sync Tax Data';

  @override // coverage:ignore-line
  String lastSyncedLabel(String date) {
    return 'Last synced: $date'; // coverage:ignore-line
  }

  @override
  String get syncPeriodYtdLabel => 'Sync Period (YTD)';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get syncNowAction => 'Sync Now';

  @override
  String get smartSyncTitle => 'Smart Sync (Merge)';

  @override
  String get smartSyncSubtitle =>
      'Updates existing data without overwriting manual changes.';

  @override
  String get forceResetTitle => 'Force Reset (Overwrite)';

  @override
  String get forceResetSubtitle =>
      'Overwrites all current fiscal year data with fresh synced data.';

  @override
  String interestRateShort(String rate) {
    return '$rate% Int.';
  }

  @override
  String get addLoanTitle => 'Add Loan';

  @override
  String get loanNameLabel => 'Loan Name';

  @override
  String get loanAmountLabel => 'Initial Principal';

  @override
  String get loanTenureLabel => 'Tenure (Months)';

  @override
  String get loanStartDateLabel => 'Start Date';

  @override
  String get loanTypeLabel => 'Loan Type';

  @override
  String get emiLabel => 'EMI';

  @override
  String get personalLoan => 'Personal Loan';

  @override
  String get homeLoan => 'Home Loan';

  @override
  String get carLoan => 'Car Loan';

  @override
  String get goldLoan => 'Gold Loan';

  @override
  String get educationLoan => 'Education Loan';

  @override
  String get businessLoan => 'Business Loan';

  @override
  String get otherLoan => 'Other';

  @override
  String get noActiveLoans => 'No active loans found.';

  @override // coverage:ignore-line
  String get remainingPrincipal => 'Remaining Principal';

  @override
  String get nextEmiDate => 'Next EMI';

  @override
  String get amountPaidLabel => 'Amount Paid';

  @override
  String get paymentDateLabel => 'Payment Date';

  @override // coverage:ignore-line
  String get principalComponent => 'Principal Component';

  @override // coverage:ignore-line
  String get interestComponent => 'Interest Component';

  @override
  String get renameLoanTitle => 'Rename Loan';

  @override
  String get calculateRateFromEmi => 'Calculate Rate from EMI?';

  @override
  String get interestRateAnnual => 'Interest Rate (Annual)';

  @override
  String get monthlyEmi => 'Monthly EMI';

  @override
  String get emiDay => 'EMI Day';

  @override
  String get defaultPaymentAccount => 'Default Payment Account (Optional)';

  @override
  String get selectSavingsAccountHelper =>
      'Select a savings account for EMI payments';

  @override // coverage:ignore-line
  String get maturityDate => 'Maturity Date';

  @override
  String get estimatedEmi => 'Estimated EMI';

  @override
  String totalInterestLabel(String amount) {
    return 'Total Interest: $amount';
  }

  @override // coverage:ignore-line
  String get projectedInterestSimple => 'Projected Interest (Simple)';

  @override // coverage:ignore-line
  String get interestPayableMaturity =>
      'Interest payable at maturity or renewal';

  @override // coverage:ignore-line
  String availLabel(String amount) {
    return 'Avail: $amount'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String balLabel(String amount) {
    return 'Bal: $amount'; // coverage:ignore-line
  }

  @override
  String get topUpLoanTooltip => 'Top-up Loan';

  @override
  String get moreOptionsTooltip => 'More options';

  @override
  String get renameLoanAction => 'Rename Loan';

  @override
  String get deleteLoanAction => 'Delete Loan';

  @override
  String get amortizationTab => 'Amortization';

  @override
  String get simulatorTab => 'Simulator';

  @override
  String get ledgerTab => 'Ledger';

  @override
  String get payAction => 'Pay';

  @override
  String get renewAction => 'Renew';

  @override
  String get partPayAction => 'Part Pay';

  @override
  String get rateAction => 'Rate';

  @override
  String get closeAction => 'Close';

  @override
  String get amortizationCurveTitle => 'Amortization Curve (Yearly)';

  @override
  String totalInterestPayableLabel(String amount) {
    return 'Total Interest Payable: $amount  •  ';
  }

  @override
  String estimatedYearlyInterestLabel(String amount) {
    return 'Estimated Yearly Interest: $amount';
  }

  @override
  String get extraPaymentAmountLabel => 'Extra Payment Amount';

  @override
  String get reduceTenureLabel => 'Reduce Tenure';

  @override
  String get reduceEmiLabel => 'Reduce EMI';

  @override
  String get newTenureLabel => 'New Tenure';

  @override // coverage:ignore-line
  String get newEmiLabel => 'New EMI';

  @override
  String get interestSavedLabel => 'Interest Saved';

  @override
  String get tenureReducedLabel => 'Tenure Reduced';

  @override // coverage:ignore-line
  String recordedPaymentsSuccess(int count) {
    return 'Recorded $count payments successfully.'; // coverage:ignore-line
  }

  @override
  String get deleteLoanConfirmTitle => 'Delete Loan?';

  @override
  String get deleteLoanConfirmMessage =>
      'This will remove the loan tracking. Existing transactions will NOT be deleted.';

  @override // coverage:ignore-line
  String get bulkRecordPaymentsTitle => 'Bulk Record Payments';

  @override
  String monthsCount(int count) {
    return '$count months';
  }

  @override
  String get outstandingPrincipalLabel => 'Outstanding Principal';

  @override
  String get bulkPayAction => 'Bulk Pay';

  @override
  String get interestRateLabel => 'Interest Rate (%)';

  @override
  String get daysAccruedLabel => 'Days Accrued';

  @override
  String get estAccruedInterestLabel => 'Est. Accrued Interest (To Date)';

  @override
  String maturityLabel(String date) {
    return 'Maturity: $date';
  }

  @override
  String get addToSystemCalendarTooltip => 'Add to System Calendar';

  @override // coverage:ignore-line
  String loanMaturityEventTitle(String name) {
    return 'Loan Maturity: $name'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String loanMaturityEventDescription(String name) {
    return 'Maturity date for Gold Loan: $name. Principal and Interest due.'; // coverage:ignore-line
  }

  @override
  String get rateLabel => 'Rate';

  @override
  String get paidLabel => 'Paid';

  @override
  String get leftLabel => 'Left';

  @override
  String percentPaidLabel(String percent) {
    return '$percent% Paid';
  }

  @override
  String get closureProgressLabel => 'Closure Progress';

  @override
  String daysCount(int count) {
    return '$count days';
  }

  @override
  String monthsShort(int count) {
    return '${count}m';
  }

  @override
  String daysShort(int count) {
    return '${count}d';
  }

  @override
  String get payInterestAndRenewTitle => 'Pay Interest & Renew';

  @override
  String get payInterestAndRenewDescription =>
      'Pay the interest due to renew the loan tenure or simply clear dues. Principal will NOT be reduced.';

  @override
  String get payAndRenewAction => 'Pay & Renew';

  @override
  String loanInterestTitle(String name) {
    return 'Loan Interest: $name';
  }

  @override
  String get closeGoldLoanTitle => 'Close Gold Loan';

  @override
  String closeGoldLoanDescription(String principal, String interest) {
    return 'Pay Principal ($principal) + Interest ($interest) to close this loan.';
  }

  @override
  String get closeLoanAction => 'Close Loan';

  @override
  String loanClosureTitle(String name) {
    return 'Loan Closure: $name';
  }

  @override
  String get paymentAmountLabel => 'Payment Amount';

  @override
  String get dateEffectiveLabel => 'Date Effective';

  @override
  String get paidFromAccountLabel => 'Paid From Account';

  @override
  String get noTransactionsMatchFilters => 'No transactions match the filters.';

  @override
  String get loanLedgerTitle => 'Loan Ledger';

  @override
  String get switchToExtendedTooltip => 'Switch to Extended Numbers';

  @override
  String get switchToCompactTooltip => 'Switch to Compact Numbers';

  @override
  String get filterByTypeTooltip => 'Filter by Type';

  @override
  String get filterByDateTooltip => 'Filter by Date';

  @override
  String get clearFiltersTooltip => 'Clear Filters';

  @override
  String get emiPaymentTitle => 'EMI Payment';

  @override
  String get prepaymentTitle => 'Prepayment';

  @override // coverage:ignore-line
  String get interestRateUpdatedTitle => 'Interest Rate Updated';

  @override
  String get loanTopUpTitle => 'Loan Top-up';

  @override
  String emiPaymentSubtitle(String principal, String interest) {
    return 'Prin: $principal • Int: $interest';
  }

  @override
  String get prepaymentSubtitle => 'Direct reduction of principal';

  @override // coverage:ignore-line
  String newRateSubtitle(String rate) {
    return 'New Rate: $rate%'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get loanTopUpSubtitle => 'Increased principal amount';

  @override
  String get balanceLabel => 'Balance: ';

  @override
  String get deleteEntryConfirmTitle => 'Delete Entry?';

  @override
  String get deleteEntryConfirmMessage =>
      'Deleting this will attempt to reverse the principal impact, but won\'t perfectly recalculate interest history.';

  @override
  String get areYouSureLabel => 'Are you sure?';

  @override
  String get partPrincipalPaymentTitle => 'Part Principal Payment';

  @override
  String get partPaymentDescription =>
      'Reduce the outstanding principal. Interest on the reduced amount will decrease from the payment date.';

  @override
  String get payPrincipalAction => 'Pay Principal';

  @override
  String get partPaymentSuccessMessage => 'Part principal payment successful.';

  @override
  String loanPartPayTitle(String name) {
    return 'Loan Part Pay: $name';
  }

  @override
  String get recalculateLoanTitle => 'Recalculate Loan';

  @override
  String currentOutstandingLabel(String amount) {
    return 'Current Outstanding: $amount';
  }

  @override
  String get newEmiAmountLabel => 'New EMI Amount';

  @override
  String get calculateInterestRateOption => 'Calculate Interest Rate?';

  @override
  String get calculateInterestRateSubtitle =>
      'If checked, Tenure will be used to find the new Rate. Otherwise, Tenure is recalculated.';

  @override
  String get targetTenureMonthsLabel => 'Target Tenure (Months)';

  @override
  String get loanTopUpDialogTitle => 'Loan Top-up';

  @override
  String get borrowMoreDescription => 'Borrow more money on this loan.';

  @override
  String get topUpAmountLabel => 'Top-up Amount';

  @override
  String get creditToAccountLabel => 'Credit to Account';

  @override
  String get recalculationModeLabel => 'Recalculation Mode:';

  @override
  String get adjustEmiOption => 'Adjust EMI';

  @override
  String get adjustEmiSubtitle => 'Keep Tenure constant. EMI will increase.';

  @override
  String get adjustTenureOption => 'Adjust Tenure';

  @override
  String get adjustTenureSubtitle => 'Keep EMI constant. Tenure will increase.';

  @override
  String get borrowAction => 'Borrow';

  @override
  String get loanTopUpSuccessMessage => 'Loan topped up successfully.';

  @override
  String get updateInterestRateTitle => 'Update Interest Rate';

  @override
  String get enterNewRateDescription => 'Enter new annual interest rate.';

  @override
  String get newAnnualRateLabel => 'New Annual Rate (%)';

  @override
  String get adjustEmiSubtitleLong =>
      'Keep Tenure constant.\nMonthly payment will change.';

  @override
  String get adjustTenureSubtitleLong =>
      'Keep EMI constant.\nLoan duration will change.';

  @override
  String get rateUpdatedSuccessMessage => 'Rate updated and loan recalibrated.';

  @override
  String get lendingBorrowingTitle => 'Lending & Borrowing';

  @override
  String get totalLentLabel => 'Total Lent';

  @override
  String get totalBorrowedLabel => 'Total Borrowed';

  @override
  String get noLendingRecords => 'No records found.';

  @override
  String get addRecordAction => 'Add Record';

  @override
  String get deleteLendingRecordTitle => 'Delete Record?';

  @override
  String get deleteLendingRecordConfirmation =>
      'Are you sure you want to delete this record? This action cannot be undone.';

  @override
  String paidSubtitle(String amount, int count) {
    return 'Paid: $amount ($count txn)';
  }

  @override // coverage:ignore-line
  String closedOnSubtitle(String date) {
    return 'Closed on $date'; // coverage:ignore-line
  }

  @override
  String balanceTrailing(String amount) {
    return 'Bal: $amount';
  }

  @override
  String get recordPaymentAction => 'Record Payment';

  @override
  String get paymentHistoryAction => 'Payment History';

  @override
  String get settleFullAction => 'Settle Full';

  @override
  String get markAsSettledTitle => 'Mark as Settled?';

  @override
  String settleLentConfirmation(String amount, String person) {
    return 'Has the amount of $amount been received back from $person?';
  }

  @override // coverage:ignore-line
  String settleBorrowedConfirmation(String amount, String person) {
    return 'Has the amount of $amount been paid back to $person?'; // coverage:ignore-line
  }

  @override
  String get yesSettleAction => 'Yes, Settle';

  @override
  String remainingLabel(String amount) {
    return 'Remaining: $amount';
  }

  @override
  String get savePaymentAction => 'Save Payment';

  @override
  String get addLendingRecordTitle => 'Add Lending Record';

  @override
  String get editLendingRecordTitle => 'Edit Lending Record';

  @override
  String get lentLabel => 'Lent (Given)';

  @override
  String get borrowedLabel => 'Borrowed (Taken)';

  @override
  String get personNameLabel => 'Person Name';

  @override
  String get enterNameError => 'Please enter a name';

  @override
  String get amountLabelSimplified => 'Amount';

  @override
  String get enterAmountError => 'Enter amount';

  @override // coverage:ignore-line
  String get invalidNumberError => 'Invalid number';

  @override
  String get reasonDescriptionLabel => 'Reason / Description';

  @override
  String get markAsClosedOption => 'Mark as Closed / SETTLED';

  @override
  String get addRecordButton => 'Add Record';

  @override
  String get editRecordButton => 'Edit Record';

  @override
  String get noPaymentsRecorded => 'No payments recorded.';

  @override
  String get totalAmountLabel => 'Total Amount';

  @override
  String get remainingSummaryLabel => 'Remaining';

  @override
  String get deletePaymentTitle => 'Delete Payment?';

  @override
  String get deletePaymentConfirmation =>
      'This will permanently remove this payment record.';

  @override
  String get paymentDeletedMessage => 'Payment deleted';

  @override
  String get holidayManagerTitle => 'Holiday Manager';

  @override
  String get holidayInfoText =>
      'Recurring transactions can be configured to avoid these dates by scheduling them a day earlier.';

  @override
  String get noHolidaysAdded => 'No holidays added yet.';

  @override
  String get recurringPaymentsTitle => 'Recurring Payments';

  @override // coverage:ignore-line
  String get noRecurringPayments => 'No recurring payments set up.';

  @override
  String nextExecutionLabel(String date) {
    return 'Next: $date';
  }

  @override
  String get addToCalendarTooltip => 'Add to System Calendar';

  @override // coverage:ignore-line
  String recurringEventDescription(String title, String amount) {
    return 'Recurring payment: $title for $amount'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get everyWeekendLabel => 'Every Weekend (Sat/Sun)';

  @override // coverage:ignore-line
  String get lastWeekendLabel => 'Last Weekend of Month';

  @override // coverage:ignore-line
  String everyWeekdayLabel(String weekday) {
    return 'Every $weekday'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get lastDayOfMonthLabel => 'Last Day of Month';

  @override // coverage:ignore-line
  String get lastWorkingDayLabel => 'Last Working Day';

  @override // coverage:ignore-line
  String get firstWorkingDayLabel => 'First Working Day';

  @override // coverage:ignore-line
  String get adjForHolidaysLabel => ' (Adj. for Holidays)';

  @override
  String get deleteRecurringTitle => 'Delete recurring rule?';

  @override
  String deleteRecurringConfirmation(String title) {
    return 'This will stop automatic payments for \"$title\". Past transactions will NOT be deleted.';
  }

  @override
  String get editRecurringAmountTitle => 'Edit Recurring Amount';

  @override
  String get newAmountLabel => 'New Amount';

  @override
  String get recycleBinTitle => 'Recycle Bin';

  @override
  String get recycleBinEmptyMessage => 'Recycle Bin is empty';

  @override
  String get restoreTooltip => 'Restore';

  @override
  String get deletePermanentlyTooltip => 'Delete Permanently';

  @override
  String get remindersTitle => 'Reminders & Notifications';

  @override
  String get upcomingLoanEMIs => 'Upcoming Loan EMIs';

  @override
  String get creditCardBills => 'Credit Card Bills';

  @override
  String get paidStatus => 'Paid';

  @override
  String get partialStatus => 'Partial';

  @override
  String get overdueStatus => 'Overdue';

  @override
  String get upcomingStatus => 'Upcoming';

  @override
  String get noLoanEMIsDue => 'No EMIs due within 7 days.';

  @override
  String dueOnLabel(String date) {
    return 'Due on $date';
  }

  @override // coverage:ignore-line
  String nextBillLabel(String date) {
    return 'Next Bill: $date'; // coverage:ignore-line
  }

  @override
  String get addToCalendarAction => 'Add to Calendar';

  @override
  String emiDueCalendarTitle(String name) {
    return 'EMI Due: $name';
  }

  @override
  String emiDueCalendarDescription(String name) {
    return 'Payment for $name due.';
  }

  @override
  String firstEMIStartsOn(String date) {
    return 'First EMI starts on $date';
  }

  @override
  String get waitForStartLabel => 'Wait for Start';

  @override
  String get payNowAction => 'PAY NOW';

  @override
  String get noCCBillsDue => 'No pending credit card bills.';

  @override
  String get noRecurringPaymentsDue => 'No due recurring payments.';

  @override
  String get frequencyMonthly => 'Monthly';

  @override // coverage:ignore-line
  String get frequencyWeekly => 'Weekly';

  @override // coverage:ignore-line
  String get frequencyOther => 'Other';

  @override
  String get selectStoppedMonthsAction => 'Select Stopped Months';

  @override // coverage:ignore-line
  String get presumptiveProfitHelper => 'Presumptive profit based on turnover';

  @override
  String get taxationTypeTooltip =>
      'Section 44AD/ADA allows presumptive taxation. Consult a professional for eligibility.';

  @override
  String get equitySharesTooltip =>
      'LTCG on equity shares above 1.25L is taxed at 12.5%.';

  @override // coverage:ignore-line
  String get reinvestmentPendingLabel => 'Reinvestment Pending';

  @override // coverage:ignore-line
  String reinvestedDetailsLabel(String amount, String type) {
    return 'Reinvested $amount via $type'; // coverage:ignore-line
  }

  @override
  String get otherIncomeTooltip =>
      'Fixed income (No loss possible) like bank interest, chit fund profit, etc. Do not include gifts here.';

  @override
  String get stcgLabel => 'STCG';

  @override // coverage:ignore-line
  String get ltcgLabel => 'LTCG';

  @override
  String get gainLabel => 'Gain';

  @override
  String get editAction => 'Edit';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get saveAction => 'Save';

  @override
  String get addIncomeAction => 'Add Income';

  @override // coverage:ignore-line
  String get noneLabel => 'None';

  @override
  String get nameLabel => 'Name';

  @override
  String get updatedPrefix => 'Upd';

  @override
  String get transactionPrefix => 'Txn';

  @override
  String get noCapitalGainsFoundNote => 'No capital gains found for this year.';

  @override
  String get policyLabel => 'Policy';

  @override
  String get taxableGainProfitLabel => 'Taxable Gain / Profit';

  @override
  String get insurancePrefix => 'Insurance';

  @override
  String get taxConfigurationTitle => 'Tax Configuration';

  @override
  String get copyPreviousYearTooltip => 'Copy Rules from Previous Year';

  @override
  String get restoreDefaultsTooltip => 'Restore System Defaults';

  @override
  String get taxJurisdictionLabel => 'Tax Jurisdiction';

  @override
  String get countryNameLabel => 'Country Name';

  @override
  String get fyStartMonthLabel => 'Financial Year Start Month';

  @override
  String get fyStartMonthHelper =>
      'Determines the start of the financial year (e.g. April 1st). Affects tax calculations.';

  @override
  String get taxRatesSlabsHeader => 'Tax Rates & Slabs';

  @override
  String get enableRebateLabel => 'Enable Rebate';

  @override
  String get rebateLimitLabel => 'Rebate Limit';

  @override
  String get enableCessLabel => 'Enable Health & Edu Cess';

  @override
  String get cessRateLabel => 'Cess Rate (%)';

  @override
  String get enableCashGiftExemptLabel => 'Enable Cash Gift Exemption';

  @override
  String get cashGiftExemptLimitLabel => 'Cash Gift Exemption Limit';

  @override
  String get selectTaxableGiftTypesLabel => 'Select Taxable Gift Types:';

  @override
  String get incomeSlabsLabel => 'Income Slabs';

  @override
  String get unlimitedLabel => 'Unlimited';

  @override
  String get addMappingAction => 'Add Mapping';

  @override
  String get noMappingsFoundNote => 'No mappings defined.';

  @override // coverage:ignore-line
  String get mappingsInstructionNote =>
      'Map Transaction Tags or Descriptions to Tax Heads for auto-assignment.';

  @override
  String get standardDeductionsHeader => 'Standard Deductions';

  @override
  String get stdDedSalaryLabel => 'Standard Deduction (Salary)';

  @override
  String get retirementExemptionsHeader => 'Retirement Exemptions';

  @override
  String get enableRetirementExemptLabel =>
      'Enable Retirement / Resignation Exemptions';

  @override
  String get leaveEncashLimitLabel => 'Leave Encashment Limit';

  @override
  String get employerGiftsHeader => 'Employer Gifts';

  @override
  String get giftExemptLimitLabel => 'Gift Exemption Limit';

  @override
  String get presumptiveIncomeHeader => 'Presumptive Income';

  @override
  String get enableBusinessExemptLabel => 'Enable Business exemption';

  @override
  String get housePropConfigHeader => 'House Property Configuration';

  @override
  String get capGainsRatesHeader => 'Capital Gains Rates';

  @override
  String get enableSpecialCGRatesLabel => 'Enable Special CG Rates';

  @override
  String get ltcgRateEquityLabel => 'LTCG Rate (Equity) %';

  @override
  String get stcgRateEquityLabel => 'STCG Rate (Equity) %';

  @override
  String get stdExemptLTCGLabel => 'Standard Exemption (LTCG)';

  @override
  String get reinvestmentRulesHeader => 'Reinvestment Rules';

  @override
  String get maxCGReinvestLimitLabel => 'Max Capital Gain Reinvest Limit';

  @override
  String get agriIncomeConfigHeader => 'Agriculture Income Configuration';

  @override
  String get enablePartialIntegrationLabel => 'Enable Partial Integration';

  @override
  String get partialIntegrationSubtitle =>
      'Determines tax using partial integration method';

  @override
  String get agriThresholdLabel => 'Agriculture Income Threshold';

  @override
  String get customGeneralExemptionsHeader => 'Custom General Exemptions';

  @override
  String get addCustomExemptionAction => 'Add Custom Exemption';

  @override
  String get advanceTaxConfigHeader => 'Advance Tax Configurations';

  @override
  String get enableAdvanceTaxInterestLabel =>
      'Enable Advance Tax Interest Calculation';

  @override
  String get interestTillPaymentDateLabel => 'Interest till Payment Date';

  @override
  String get interestTillPaymentDateSubtitle =>
      'If missed installment, calculate interest till payment date instead of next installment.';

  @override
  String get includeCGInAdvanceTaxLabel =>
      'Include Capital Gains in Advance Tax Base';

  @override
  String get includeCGInAdvanceTaxSubtitle =>
      'If enabled, STCG/LTCG tax is included in required installments. If disabled, ONLY Normal Income (Salary, Business, etc.) is considered for installment matching.';

  @override
  String get interestRateMonthlyLabel => 'Interest Rate % (Monthly)';

  @override // coverage:ignore-line
  String get addCustomExemptionTitle => 'Add Custom Exemption';

  @override
  String get restoreAction => 'Restore';

  @override
  String get taxRulesSavedStatus => 'Tax Rules Saved Successfully';

  @override
  String get taxRulesResetStatus => 'Tax Rules reset for FY.';

  @override
  String get monthJan => 'January';

  @override
  String get monthFeb => 'February';

  @override
  String get monthMar => 'March';

  @override
  String get monthApr => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'June';

  @override
  String get monthJul => 'July';

  @override
  String get monthAug => 'August';

  @override
  String get monthSep => 'September';

  @override
  String get monthOct => 'October';

  @override
  String get monthNov => 'November';

  @override
  String get monthDec => 'December';

  @override
  String get generalTab => 'General';

  @override
  String get agriIncomeTab => 'Agri Income';

  @override
  String get advanceTaxTab => 'Advance Tax';

  @override
  String get mappingsTab => 'Mappings';

  @override
  String get enableStdDedSalaryLabel => 'Enable Standard Deduction';

  @override
  String get retirementExemptSubtitle => 'Gratuity & Leave Encashment';

  @override
  String get gratuityLimitLabel => 'Gratuity Exemption Limit';

  @override
  String get enableEmployerGiftLabel => 'Enable Gifts from Employer Rule';

  @override
  String get employerGiftSubtitle => 'Exempt up to a limit';

  @override
  String get defaultGiftLimitHint => 'Default: 5000';

  @override
  String get businessExemptSubtitle => 'Presumptive income for Businesses';

  @override
  String get limit44ADLabel => 'Turnover Limit for 44AD';

  @override
  String get rate44ADLabel => 'Presumptive Profit Rate (%)';

  @override
  String get enableProfessionalExemptLabel => 'Enable Professional exemption';

  @override
  String get professionalExemptSubtitle =>
      'Presumptive income for Professionals';

  @override
  String get limit44ADALabel => 'Gross Receipts Limit for 44ADA';

  @override
  String get rate44ADALabel => 'Presumptive Profit Rate (%)';

  @override // coverage:ignore-line
  String get cancelBtnLabel => 'Cancel';

  @override
  String get enableStdDedHPLabel => 'Enable 30% Standard Deduction';

  @override
  String get stdDedHPRateLabel => 'Standard Deduction Rate (%)';

  @override
  String get stdDedHPSubtitle => 'Usually 30%';

  @override
  String get enableHPMaxInterestLabel => 'Enable Interest Deduction Cap';

  @override
  String get hpMaxInterestSubtitle =>
      'Limit max interest deduction for self-occupied';

  @override
  String get maxHPInterestDedLabel => 'Max Interest Deduction (Self-Occ)';

  @override
  String get specialCGRatesSubtitle =>
      'Use special rates instead of normal slabs';

  @override
  String get enableLTCGExemptionLabel => 'Enable LTCG Exemption';

  @override
  String get enableReinvestmentExemptLabel => 'Enable Reinvestment Exemptions';

  @override
  String get reinvestWindowLabel => 'Reinvestment Window (Years)';

  @override
  String get agriIncomeMethodDesc =>
      'Partial Integration Method determines tax on Agriculture Income if it exceeds the threshold and non-agri income exceeds basic exemption.';

  @override
  String agriThresholdSubtitle(String amount) {
    return 'Default: $amount';
  }

  @override
  String get agriBasicLimitLabel => 'Agri Basic Exemption Limit';

  @override
  String agriBasicLimitSubtitle(String amount) {
    return 'Default: $amount (Used for Partial Integration)';
  }

  @override
  String get noCustomExemptionsMsg => 'No custom exemptions defined.';

  @override
  String get advanceTaxConfigDesc =>
      'Define the installment schedule, required percentages, and interest rates for advance tax calculations.';

  @override
  String get advanceTaxInterestSubtitle =>
      'Calculate interest based on shortfalls';

  @override
  String get reminderDaysLabel => 'Reminder Days Before Deadline';

  @override
  String get interestThresholdLabel =>
      'Interest Calculation Base Threshold (Fixed)';

  @override
  String get interestThresholdSubtitle =>
      'Advance tax interest applies only if tax liability after TDS exceeds this amount.';

  @override
  String get installmentScheduleHeader => 'Installment Schedule';

  @override
  String get addInstallmentBtn => 'Add Installment';

  @override // coverage:ignore-line
  String get noInstallmentsMsg => 'No installments configured.';

  @override
  String installmentNumberLabel(int number) {
    return 'Installment #$number';
  }

  @override // coverage:ignore-line
  String get limitFieldLabel => 'Limit';

  @override // coverage:ignore-line
  String get isCliffExemptionLabel => 'Is Cliff Exemption?';

  @override // coverage:ignore-line
  String get addBtnLabel => 'Add';

  @override // coverage:ignore-line
  String get incomeHeadLabel => 'Income Head';

  @override
  String get requiredPercentageLabel => 'Required %';

  @override
  String get endMonthLabel => 'End Month';

  @override
  String get saveButton => 'Save';

  @override // coverage:ignore-line
  String get editIndependentDeductionAction => 'Edit Independent Deduction';

  @override // coverage:ignore-line
  String get editIndependentAllowanceAction => 'Edit Independent Allowance';

  @override // coverage:ignore-line
  String get payoutFrequencyTrimesterLabel => 'Trimester (4 Months)';

  @override // coverage:ignore-line
  String monthsSelectedCountLabel(String count) {
    return '$count Months Selected'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get isPartialIrregularTitle => 'Partial/Irregular Payouts';

  @override // coverage:ignore-line
  String get isPartialIrregularSubtitle =>
      'Enter different amounts for each payout month';

  @override // coverage:ignore-line
  String get enterAmountsForPayoutMonthsNote =>
      'Enter amounts for selected payout months:';

  @override
  String get unemploymentNoSalarySubtitle =>
      'Select months where no salary was received';

  @override // coverage:ignore-line
  String monthsStoppedCountLabel(String count) {
    return '$count Months Stopped'; // coverage:ignore-line
  }

  @override
  String get annualFixedAllowancesHelperText =>
      'HRA, Special, etc. (Fully Taxable)';

  @override
  String get maxAmountPerYearLabel => 'Max amount per year';

  @override
  String get totalAmountPerYearLabel => 'Total amount per year';

  @override
  String get partialPayoutTaxableFactorTitle =>
      'Partial Payout / Taxable Factor?';

  @override
  String get defaultEqualDistributionSubtitle => 'Default: Equal distribution';

  @override // coverage:ignore-line
  String get annualPayoutLabel => 'Annual Payout';

  @override
  String get perPayoutLabel => 'Per Payout';

  @override
  String get annualTotalLabel => 'Annual Total';

  @override
  String get addCapitalGainAction => 'Add Capital Gain';

  @override // coverage:ignore-line
  String get editEntryAction => 'Edit Entry';

  @override // coverage:ignore-line
  String get selectButton => 'Select';

  @override
  String get agriculturalIncomeTitle => 'Agricultural Income';

  @override
  String get frequencyDropdownLabel => 'Frequency';

  @override
  String get addSalaryStructureAction => 'Add Salary Structure';

  @override
  String get editSalaryStructureAction => 'Edit Salary Structure';

  @override
  String get noSalaryDataPreviousYearNote =>
      'No salary data found for the previous year.';

  @override
  String copiedStructuresCountNote(String count) {
    return '$count salary structures copied.';
  }

  @override // coverage:ignore-line
  String get noHousePropertiesPreviousYearNote =>
      'No house properties found for the previous year.';

  @override
  String copiedPropertiesCountNote(String count) {
    return '$count house properties copied.';
  }

  @override // coverage:ignore-line
  String get isCliffExemptionTitle => 'Is Cliff Exemption?';

  @override
  String get taxDetailsSavedStatus => 'Tax details saved successfully.';

  @override // coverage:ignore-line
  String clearCategoryDataContent(String category, String year) {
    return 'Are you sure you want to clear all $category data for FY $year?'; // coverage:ignore-line
  }

  @override
  String clearAllFiscalYearDataTitle(String year) {
    return 'Clear ALL Data for FY $year?';
  }

  @override
  String get clearAllFiscalYearDataContent =>
      'This will permanently delete all tax data for this financial year. This action cannot be undone.';

  @override
  String get deleteAllButton => 'Delete All';

  @override
  String get housePropertyTab => 'House Property';

  @override
  String get capitalGainsTab => 'Capital Gains';

  @override
  String get fiscalYearPrefix => 'FY';

  @override
  String get filterByDateRangeLabel => 'Filter by Date Range';

  @override // coverage:ignore-line
  String get clearDateFilterLabel => 'Clear Date Filter';

  @override
  String get clearAllFiscalYearDataLabel => 'Clear ALL Fiscal Year Data';

  @override
  String get clearCategoryDataLabel => 'Clear Category Data';

  @override
  String get copyPreviousYearDataLabel => 'Copy from Previous Year';

  @override
  String get estimatedTaxLiabilityLabel => 'Est. Tax Liability';

  @override
  String get keepEditingButton => 'Keep Editing';

  @override
  String get discardButton => 'Discard';

  @override
  String get lastUpdatedLabel => 'Last Updated';

  @override // coverage:ignore-line
  String get fullYearLabel => 'Full Year';

  @override
  String get dividendBreakdownNote =>
      'Dividend income is tracked by advance tax installment periods for precise interest calculation.';

  @override
  String get dividendUpdatedStatus => 'Dividend income updated.';

  @override
  String get updateTotalButton => 'Update Total';

  @override
  String get noSalaryStructureDefinedNote =>
      'No salary structure defined for this period.';

  @override
  String get basicLabel => 'Basic';

  @override
  String get allowancesLabel => 'Allowances';

  @override
  String get employerNPSLabel => 'Employer NPS Contribution';

  @override
  String get leaveEncashmentTitleLabel => 'Leave Encashment';

  @override
  String get gratuityTitleLabel => 'Gratuity';

  @override
  String get employerGiftsLabel => 'Employer Gifts';

  @override
  String get customAdHocExemptionsTitle => 'Custom Ad-hoc Exemptions';

  @override
  String get noAdHocExemptionsNote => 'No ad-hoc exemptions added.';

  @override
  String get addAdHocExemptionAction => 'Add Ad-hoc Exemption';

  @override
  String get tdsTaxesPaidTitle => 'TDS / Taxes Paid (Salary)';

  @override
  String get detailedEstCurrentMonthLabel => 'DETAILED EST. (CURRENT MONTH)';

  @override
  String get taxShortLabel => 'Tax';

  @override
  String get dedShortLabel => 'Ded';

  @override
  String get detailedLinkLabel => 'Show Detailed Amounts';

  @override
  String get bonusTaxNote =>
      'Note: Bonuses and variable pay are taxed in the month of receipt.';

  @override
  String get taxableHPIncomeLabel => 'Taxable House Property Income';

  @override
  String get interestLabel => 'Interest';

  @override // coverage:ignore-line
  String get letOutLabel => 'Let Out';

  @override
  String get lessEmployerNPSLabel => 'Less: Employer NPS Contribution';

  @override // coverage:ignore-line
  String get lessEmployerGiftsLabel => 'Less: Employer Gifts (Exempt)';

  @override
  String get taxableBeforeAdHocExemptionsLabel =>
      'Taxable Before Ad-hoc Exemptions';

  @override
  String get lessCustomAdHocExemptionsLabel => 'Less: Custom Ad-hoc Exemptions';

  @override // coverage:ignore-line
  String get editPropertyAction => 'Edit Property';

  @override
  String get grossShortLabel => 'Gross';

  @override
  String get netShortLabel => 'Net';

  @override // coverage:ignore-line
  String get editBusinessAction => 'Edit Business';

  @override
  String get shortTermSTCGLabel => 'Short Term (STCG)';

  @override // coverage:ignore-line
  String get otherAssetsTooltip =>
      'LTCG on other assets is taxed at 20% with indexation.';

  @override
  String amountCurrencyLabel(String currency) {
    return 'Amount ($currency)';
  }

  @override
  String get giftRelativesExemptNote =>
      'Note: Gifts from relatives are fully exempt from tax.';

  @override
  String get addAgriIncomeAction => 'Add Agri Income';

  @override // coverage:ignore-line
  String get editAgriIncomeAction => 'Edit Agri Income';

  @override
  String get dateLabel => 'Date';

  @override
  String get agriIncomeNote =>
      'Agricultural income is exempt but used for rate purposes if it exceeds 5000 and total income exceeds basic exemption.';

  @override
  String get noAgriIncomeNote => 'No agricultural income found for this year.';

  @override
  String get totalNetAgriIncomeLabel => 'Total Net Agri Income';

  @override
  String get maturityDateLabel => 'Maturity Date';

  @override // coverage:ignore-line
  String get selectDateAction => 'Select Date';

  @override
  String get disclaimerRulesTitle =>
      'Disclaimer: These rules are based on current Indian Tax Laws. Review with a professional for your specific case.';

  @override
  String get enableAggregateLimitsLabel => 'Enable Aggregate Limits';

  @override
  String get limitsUlipNonUlipSubtitle =>
      'Section 10(10D) limits for ULIP and Non-ULIP policies.';

  @override
  String get startDatesAggregateLimitsHeader =>
      'Start Dates for Aggregate Limits';

  @override
  String get ulipLimitStartLabel => 'ULIP Limit Start';

  @override
  String get nonUlipLimitStartLabel => 'Non-ULIP Limit Start';

  @override
  String get aggregatePremiumLimitsHeader => 'Aggregate Premium Limits';

  @override
  String get ulipLimitLabel => 'ULIP Annual Limit';

  @override
  String get nonUlipLimitLabel => 'Non-ULIP Annual Limit';

  @override
  String get enablePremiumPercentRulesLabel => 'Enable Premium % Rules';

  @override
  String get limitsPercentageSumAssuredSubtitle =>
      'Tax exemption based on premium as a percentage of sum assured.';

  @override
  String get premiumPercentRulesConfigHeader => 'Premium % Rules Configuration';

  @override
  String get policiesDatePctNote =>
      'Note: Rule applied based on the latest startDate <= policy issue date.';

  @override
  String pctLimitLabel(double pct) {
    return '$pct% Limit';
  }

  @override
  String effectiveFromLabel(String date) {
    return 'Effective From: $date';
  }

  @override
  String get saveRulesAction => 'Save Rules';

  @override
  String get recalculateTaxSuccess =>
      'Tax status for all policies recalculated.';

  @override
  String get taxOptimizationGainsTitle => 'Tax Optimization & Gains';

  @override
  String get annPremiumLabel => 'Ann. Premium';

  @override
  String get currentTaxableLabel => 'Curr. Taxable';

  @override
  String get futureTaxableLabel => 'Future Taxable';

  @override
  String get totalTaxableUlipLabel => 'Total Taxable ULIP';

  @override
  String get totalTaxableNonUlipLabel => 'Total Taxable Non-ULIP';

  @override
  String get taxableAmountsNote =>
      'Note: Taxable amounts are the sum of annual premiums for policies that have lost 10(10D) exemption.';

  @override // coverage:ignore-line
  String get addPremiumRuleTitle => 'Add Premium Rule';

  @override // coverage:ignore-line
  String limitPctLabel(String symbol) {
    return 'Limit % ($symbol)'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get addRuleAction => 'Add Rule';

  @override
  String get requiredLabel => 'Required';

  @override
  String get noteLabel => 'Note';

  @override // coverage:ignore-line
  String get principalShort => 'Principal';

  @override // coverage:ignore-line
  String get interestShort => 'Interest';

  @override // coverage:ignore-line
  String get loanEmiTitle => 'Loan EMIs';

  @override
  String get updateButton => 'Update';

  @override
  String get monthLabel => 'Month';

  @override // coverage:ignore-line
  String get selectReinvestmentTypeNote =>
      'Select reinvestment type to see details.';

  @override
  String get descriptionAssetLabel => 'Description / Asset';

  @override
  String get isLTCGLabel => 'Is LTCG?';

  @override // coverage:ignore-line
  String get editOtherIncomeAction => 'Edit Other Income';

  @override
  String get advanceTaxTitle => 'Advance Tax';

  @override
  String get tdsTitle => 'TDS';

  @override
  String get tcsTitle => 'TCS';

  @override // coverage:ignore-line
  String advanceTaxInstallmentNote(
      String month, String day, String percent, String amount) {
    return '$month $day: $percent% of total tax (approx $amount)'; // coverage:ignore-line
  }

  @override
  String addEntryTypeAction(String type) {
    return 'Add $type';
  }

  @override // coverage:ignore-line
  String editEntryTypeAction(String type) {
    return 'Edit $type'; // coverage:ignore-line
  }

  @override
  String get addButton => 'Add';

  @override
  String giftThresholdNote(String limit) {
    return 'Note: Aggregate cash gifts above $limit in a year are fully taxable.';
  }

  @override
  String get noCashGiftsNote => 'No cash gifts found for this year.';

  @override // coverage:ignore-line
  String get editGiftAction => 'Edit Gift';

  @override // coverage:ignore-line
  String errorLabelWithDetails(String error) {
    return 'Error: $error'; // coverage:ignore-line
  }

  @override
  String get resetButton => 'Reset';

  @override
  String get doneButton => 'Done';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get okButton => 'OK';

  @override
  String get verifyAction => 'Verify';

  @override
  String get saveEnableAction => 'Save & Enable';

  @override
  String get useExistingPinAction => 'Use Existing PIN';

  @override
  String get clearCloudDataAction => 'CLEAR CLOUD DATA';

  @override
  String get wipeDeactivateAction => 'WIPE & DEACTIVATE';

  @override
  String get yesRestoreAction => 'Yes, Restore';

  @override // coverage:ignore-line
  String get updateAndReloadAction => 'Update & Reload';

  @override // coverage:ignore-line
  String get forceReloadAction => 'Force Reload';

  @override
  String get encryptBackupAction => 'ENCRYPT & BACKUP';

  @override
  String get backupUnencryptedAction => 'Backup Unencrypted';

  @override
  String get createAction => 'CREATE';

  @override
  String get deleteActionCap => 'DELETE';

  @override
  String get cancelActionCap => 'CANCEL';

  @override
  String get restoreActionCap => 'RESTORE';

  @override
  String get clearActionCap => 'CLEAR';

  @override
  String get enterPinHeader => 'Enter PIN';

  @override
  String get pinDigitsHint => '4-6 digits';

  @override
  String get tooManyAttemptsMsg => 'Too many attempts. Try again later.';

  @override
  String incorrectPinWithAttempts(int count) {
    return 'Incorrect PIN ($count attempts left)';
  }

  @override
  String get forgotPinAction => 'Forgot PIN? / Use Password';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueOfflineAction => 'Continue Offline / Use Locally';

  @override // coverage:ignore-line
  String loginStatusMsg(String message) {
    return 'Login Status: $message'; // coverage:ignore-line
  }

  @override
  String get recordLoanPaymentTitle => 'Record Loan Payment';

  @override
  String get emiNote => 'Regular EMI covers Interest + Principal components.';

  @override
  String get prepaymentNote =>
      'Prepayment reduces Principal. Choose impact above.';

  @override
  String get paymentRecordedMsg => 'Payment Recorded';

  @override
  String payBillTitle(String name) {
    return 'Pay $name Bill';
  }

  @override // coverage:ignore-line
  String get billAlreadyPaidNote => 'Bill is already marked as paid.';

  @override
  String get roundOffLabel => 'Round Off';

  @override
  String get roundToNearestNote => 'Round to nearest number';

  @override // coverage:ignore-line
  String get errorLoadingAccounts => 'Error loading accounts';

  @override
  String get updateBillingCycleNote =>
      'Updating the billing cycle requires freezing the statement until your chosen start month.';

  @override
  String get freezeDateLockedNote =>
      'Freeze date cannot be changed for an active freeze.';

  @override // coverage:ignore-line
  String get debtZeroRequirementNote =>
      'Billing cycle day can only be changed when the total debt is 0. However, you can still update your Payment Due Date.';

  @override
  String get selectFirstStatementMonth => 'Select First Statement Month:';

  @override
  String get initializeUpdateAction => 'Initialize Update';

  @override
  String get updateBillingCycleTitle => 'Update Billing Cycle';

  @override
  String get freezeTransactionsUntil => 'Freeze Transactions Until';

  @override
  String get newBillingCycleDayLabel => 'New Billing Cycle Day';

  @override
  String get newPaymentDueDayLabel => 'New Payment Due Day';

  @override
  String get billingCycleUpdateSuccess =>
      'Billing cycle update initialized successfully!';

  @override // coverage:ignore-line
  String get paymentDueDateUpdateSuccess =>
      'Payment due date updated successfully!';

  @override
  String get selectFirstStatementMonthError =>
      'Please select your first statement date.';

  @override
  String get payFromAccountLabel => 'Payment Account (Optional)';

  @override
  String get prepaymentEffectLabel => 'Prepayment Effect:';

  @override // coverage:ignore-line
  String get errorTitle => 'Error';

  @override // coverage:ignore-line
  String upToDateMessage(String version) {
    return 'You are consistent with the latest version ($version).'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get forceReloadNote =>
      'If you don\'t see expected changes, you can force a reload.';

  @override // coverage:ignore-line
  String get updateApplicationConfirmMessage =>
      'This will clear the application cache and reload the latest version. Your local data (Hive) will remain safe. Do you want to proceed?';

  @override // coverage:ignore-line
  String get updateNotAvailableError =>
      'Update not available for this platform.';

  @override // coverage:ignore-line
  String get requestTimeoutError =>
      'Request timed out. Please check your connection.';

  @override // coverage:ignore-line
  String get restoreCloudWarning =>
      'This will PERMANENTLY WIPE all local data and replace it with your cloud data.';

  @override
  String get restoreCompleteStatus => 'Restore Complete! Reloading...';

  @override
  String get deactivateAccountQuestion => 'Deactivate Cloud Account?';

  @override
  String get deactivateWipeWarning =>
      'This will PERMANENTLY WIPE all your data from both the cloud and your local device.';

  @override
  String get localDataSafeNote =>
      'Your account will be deleted, and you will be completely logged out with a blank slate.';

  @override // coverage:ignore-line
  String get accountDeactivatedStatus =>
      'Account Deactivated and All Data Wiped.';

  @override
  String get clearCloudDataQuestion => 'Clear Cloud Data?';

  @override
  String get clearCloudWarning =>
      'This will PERMANENTLY DELETE all your data from the cloud server.';

  @override
  String get localDataSafeLabel => 'Your Local Data will be SAFE.';

  @override
  String get accountActiveLabel => 'Your Account will remain ACTIVE.';

  @override
  String get proceedQuestion => 'Proceed?';

  @override // coverage:ignore-line
  String authFailedStatus(String error) {
    return 'Authentication Failed: $error'; // coverage:ignore-line
  }

  @override
  String get cloudDataClearedStatus => 'Cloud Data Cleared Successfully.';

  @override
  String get selectCurrencyTitle => 'Select Currency';

  @override
  String get encryptionPasscodeLabel => 'Encryption Passcode';

  @override
  String get pleaseEnterPasscodeError => 'Please enter a passcode';

  @override
  String get verifyAppPinTitle => 'Verify App PIN';

  @override
  String get verifyPinReasonDefault => 'Enter your 4-6 digit PIN to continue.';

  @override // coverage:ignore-line
  String get pinLengthError => 'PIN must be 4-6 digits long.';

  @override // coverage:ignore-line
  String get tooManyAttemptsError => 'Too many attempts. Try again later.';

  @override
  String get incorrectPinError => 'Incorrect PIN';

  @override
  String get setAppPinTitle => 'Set App PIN';

  @override
  String get setupAppLockTitle => 'Setup App Lock';

  @override
  String get enterPinToSecureNote => 'Enter a 4-6 digit PIN to secure the app.';

  @override
  String get existingPinNote =>
      'You have an existing PIN. Do you want to use it or set a new one?';

  @override
  String get newPinHint => 'NEW PIN';

  @override
  String get appLockEnabledStatus => 'App Lock Enabled';

  @override
  String get pinSavedLockedStatus => 'PIN Saved & Locked';

  @override
  String get deleteProfileQuestion => 'Delete Profile?';

  @override
  String deleteProfileWarning(String name) {
    return 'This will PERMANENTLY delete the profile \'$name\' and ALL its associated data (Accounts, Transactions, Loans, Taxes, Lending, Categories). This cannot be undone.';
  }

  @override // coverage:ignore-line
  String get noOtherProfilesError => 'No other profiles to copy from.';

  @override
  String get copyCategoriesTitle => 'Copy Categories';

  @override
  String categoriesCopiedStatus(String name) {
    return 'Categories copied to $name';
  }

  @override
  String get updateApplicationTitle => 'Update Application';

  @override
  String get aboutTitle => 'About';

  @override // coverage:ignore-line
  String get installAppTitle => 'Install App';

  @override
  String get dangerZoneHeader => 'Danger Zone';

  @override
  String get deactivateWipeCloudTitle => 'Deactivate & Wipe Cloud Data';

  @override
  String get deactivateWipeCloudDesc =>
      'Delete all cloud data and sign out of cloud sync. This cannot be undone.';

  @override // coverage:ignore-line
  String get offlineUpdateError => 'Offline: Unable to check for updates.';

  @override // coverage:ignore-line
  String get cloudRestoreWarning =>
      'If your cloud backup was encrypted, please enter the passcode. If it was not encrypted, leave this blank and continue.';

  @override
  String get encryptBackupQuestion => 'Encrypt Backup?';

  @override
  String get noteCategoriesEncryption =>
      'Note: Categories are stored as metadata and are NOT encrypted.';

  @override // coverage:ignore-line
  String get frozenLabel => 'FROZEN';

  @override
  String get notCalculatedYet => 'Not calculated yet';

  @override
  String get tbdLabel => 'TBD';

  @override
  String get clearBilledAmountTitle => 'Clear Billed Amount';

  @override
  String get clearBilledAmountDesc => 'Mark current bill as paid/cleared';

  @override
  String get clearBilledConfirmMessage =>
      'This will set the current \"Billed Amount\" to 0 without recording a payment transaction.';

  @override
  String get billedAmountClearedStatus => 'Billed amount cleared.';

  @override
  String get recalculateBillTitle => 'Recalculate Bill';

  @override
  String get recalculateBillDesc => 'Refreshes billing cycle display';

  @override // coverage:ignore-line
  String get recalculatingBillStatus => 'Recalculating bill...';

  @override // coverage:ignore-line
  String billRecalculatedStatus(String name) {
    return 'Bill recalculated for $name.'; // coverage:ignore-line
  }

  @override
  String usedAvailableShort(String used, String avail) {
    return '$used / $avail';
  }

  @override // coverage:ignore-line
  String usedAvailableLabel(String used, String avail) {
    return '$used / $avail'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get requiredShortLabel => 'Req';

  @override
  String get deleteAccountQuestion => 'Delete Account?';

  @override
  String deleteAccountConfirmMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get deleteAccountWarning =>
      'Existing transactions will NOT be deleted but will no longer be linked to this account.';

  @override
  String accountDeletedStatus(String name) {
    return 'Account \"$name\" deleted.';
  }

  @override
  String get newAccountTitle => 'New Account';

  @override
  String get editAccountTitle => 'Edit Account';

  @override
  String get accountNameLabel => 'Account Name';

  @override // coverage:ignore-line
  String get reservedNameError => 'Reserved name';

  @override
  String get currentBalanceLabel => 'Current Balance';

  @override
  String get createAccountAction => 'Create Account';

  @override
  String get updateAccountAction => 'Update Account';

  @override // coverage:ignore-line
  String get creditLimitLabel => 'Credit Limit';

  @override // coverage:ignore-line
  String get billGenDayLabel => 'Bill Gen. Day';

  @override // coverage:ignore-line
  String get paymentDueDayLabel => 'Payment Due Day';

  @override // coverage:ignore-line
  String get dayOfMonthHelper => 'Day of month';

  @override
  String get indianRupeeLabel => 'Indian Rupee (₹)';

  @override
  String get britishPoundLabel => 'British Pound (£)';

  @override
  String get euroLabel => 'Euro (€)';

  @override
  String get usDollarLabel => 'US Dollar (\$)';

  @override // coverage:ignore-line
  String get freqDaily => 'DAILY';

  @override // coverage:ignore-line
  String get freqWeekly => 'WEEKLY';

  @override
  String get freqMonthly => 'MONTHLY';

  @override // coverage:ignore-line
  String get freqYearly => 'YEARLY';

  @override
  String get daySuffixSt => 'st';

  @override // coverage:ignore-line
  String get daySuffixNd => 'nd';

  @override // coverage:ignore-line
  String get daySuffixRd => 'rd';

  @override // coverage:ignore-line
  String get daySuffixTh => 'th';

  @override
  String get everyEvery => ' - Every ';

  @override
  String get prepaymentLabel => 'Prepayment';

  @override
  String get loanTypePersonal => 'Personal';

  @override
  String get loanTypeHome => 'Home';

  @override
  String get loanTypeEducation => 'Education';

  @override
  String get loanTypeCar => 'Car';

  @override
  String get loanTypeGold => 'Gold';

  @override
  String get loanTypeBusiness => 'Business';

  @override
  String get loanTypeOther => 'Other';

  @override
  String get bankLoanCategory => 'Bank loan';

  @override
  String ccBillPaymentTitle(Object name) {
    return 'CC Bill Payment: $name';
  }

  @override
  String get creditCardBillCategory => 'Credit Card Bill';

  @override
  String get roundingAdjustmentTitle => 'Rounding Adjustment';

  @override
  String get adjustmentCategory => 'Adjustment';

  @override // coverage:ignore-line
  String get timeoutError => 'Request timed out. Please check your connection.';

  @override
  String get restoreButton => 'Restore';

  @override
  String get backupDataZipLabel => 'Backup Data (ZIP)';

  @override
  String get restoreDataZipLabel => 'Restore Data (ZIP)';

  @override
  String repairSuccessStatus(String name, int count) {
    return '$name: Successfully repaired $count items.';
  }

  @override // coverage:ignore-line
  String repairFailedStatus(String error) {
    return 'Repair Failed: $error'; // coverage:ignore-line
  }

  @override
  String get manageRecurringPaymentsAction => 'Manage Recurring Payments';

  @override
  String get manageCategoriesAction => 'Manage Categories';

  @override // coverage:ignore-line
  String switchedToProfileStatus(String name) {
    return 'Switched to profile: $name'; // coverage:ignore-line
  }

  @override
  String get addNewProfileAction => 'Add New Profile';

  @override
  String get enterNameHint => 'Enter name';

  @override
  String get amountLabelText => 'Amount';

  @override
  String get numTransactionsLabel => 'Number of Transactions';

  @override
  String get defaultIntervalNote => 'Default interval between backups';

  @override
  String get logoutActionLabel => 'Logout';

  @override
  String get appLockPinTitle => 'App Lock PIN';

  @override
  String get appLockPinDesc => 'Secure the app with a PIN';

  @override
  String get changePinTitle => 'Change PIN';

  @override // coverage:ignore-line
  String get sameAccountError =>
      'Source and Target accounts cannot be the same.';

  @override // coverage:ignore-line
  String get futureScheduleOnlyError =>
      '\"Just Schedule\" is only allowed for Today or Future dates.';

  @override
  String get updateSimilarTitle => 'Update Similar Transactions?';

  @override
  String updateSimilarMessage(
      int count, String title, String oldCategory, String newCategory) {
    return 'Found $count other transactions with title \"$title\" and category \"$oldCategory\". Do you want to update their category to \"$newCategory\" as well?';
  }

  @override
  String get noJustThisOne => 'NO, Just this one';

  @override
  String get yesUpdateAll => 'YES, Update All';

  @override
  String get transferCategory => 'Transfer';

  @override // coverage:ignore-line
  String get day15Hint => 'e.g. 15';

  @override // coverage:ignore-line
  String get day5Hint => 'e.g. 5';

  @override
  String get japaneseYenLabel => 'Japanese Yen (¥)';

  @override
  String get chineseYuanLabel => 'Chinese Yuan (¥)';

  @override
  String get uaeDirhamLabel => 'UAE Dirham (د.إ)';

  @override // coverage:ignore-line
  String get bulkRecordDesc =>
      'Record EMI payments for a date range automatically. Assumes paid on time.';

  @override // coverage:ignore-line
  String get startDateLabel => 'Start Date';

  @override // coverage:ignore-line
  String get endDateLabel => 'End Date';

  @override // coverage:ignore-line
  String get recordPaymentsAction => 'Record Payments';

  @override
  String get rateChangeLabel => 'Rate Change';

  @override
  String get topupLabel => 'Top-up';

  @override
  String get loanTopUpCategory => 'Loan Top-up';

  @override
  String get perYearLabel => ' / yr';

  @override
  String get indiaLabel => 'India';

  @override
  String get customLabel => 'Custom';

  @override
  String fyLabel(int year, int nextYear) {
    return 'FY $year-$nextYear';
  }

  @override
  String get unsavedChangesSwitchYearContent =>
      'You have unsaved changes. Switching years will discard them. Continue?';

  @override
  String get restoreSystemDefaultsTitle => 'Restore System Defaults?';

  @override
  String get restoreSystemDefaultsContent =>
      'This will delete custom tax rules for this year and revert to system defaults (or previous year). Continue?';

  @override
  String get copiedFromPreviousYearStatus =>
      'Values copied from previous year. Click Save to apply.';

  @override // coverage:ignore-line
  String mapsToLabel(String target) {
    return 'Maps to: $target'; // coverage:ignore-line
  }

  @override // coverage:ignore-line
  String get advancedMappingsHeader => 'Advanced Mappings (CG / Filters)';

  @override // coverage:ignore-line
  String get calculatedRateLabel => 'Calculated Rate';

  @override
  String get invalidLabel => 'Invalid';

  @override
  String get continueAction => 'Continue';

  @override
  String get languageLabel => 'Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get englishLanguage => 'English';

  @override
  String get investmentsAction => 'Investments';

  @override
  String get investmentsTitle => 'Investments';

  @override
  String get investmentDashboard => 'Dashboard';

  @override
  String get investmentManagement => 'Manage';

  @override
  String get totalValueLabel => 'Total Value';

  @override
  String get investedLabel => 'Invested';

  @override
  String get unrealizedGainLabel => 'Unrealized Gain';

  @override // coverage:ignore-line
  String readyToSellLT(int count) {
    return '$count Long-term ready'; // coverage:ignore-line
  }

  @override
  String get addInvestment => 'Add Investment';

  @override // coverage:ignore-line
  String get editInvestment => 'Edit Investment';

  @override
  String get investmentName => 'Investment Name';

  @override
  String get investmentType => 'Type';

  @override // coverage:ignore-line
  String get acquisitionDate => 'Acquisition Date';

  @override // coverage:ignore-line
  String get acquisitionPrice => 'Acquisition Price';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get currentPriceLabel => 'Current Price';

  @override
  String get mfCategoryLabel => 'MF Category';

  @override
  String get thresholdLabel => 'LT Threshold (Years)';

  @override // coverage:ignore-line
  String get notAutoCalculated => '(Not auto-calculated)';

  @override
  String get exportTemplate => 'Export Tickers';

  @override
  String get importPrices => 'Import Prices';

  @override // coverage:ignore-line
  String updatePricesSuccess(int count) {
    return 'Prices updated for $count items'; // coverage:ignore-line
  }

  @override
  String get investmentCodeName => 'Ticker / Code Name';

  @override
  String get investmentType_stock => 'Stocks';

  @override
  String get investmentType_mutualFund => 'Mutual Funds';

  @override
  String get investmentType_fixedSavings => 'Fixed Savings (FD/RD)';

  @override
  String get investmentType_nps => 'NPS';

  @override
  String get investmentType_pf => 'PF / EPF / VPF';

  @override
  String get investmentType_moneyMarket => 'Money Market';

  @override
  String get investmentType_overnight => 'Overnight Fund';

  @override
  String get investmentType_otherRecord => 'Other (Variable Value)';

  @override
  String get investmentType_otherFixed => 'Other (Fixed Interest)';

  @override // coverage:ignore-line
  String get mfCategory_flexi => 'Flexi Cap';

  @override // coverage:ignore-line
  String get mfCategory_largeCap => 'Large Cap';

  @override // coverage:ignore-line
  String get mfCategory_midCap => 'Mid Cap';

  @override // coverage:ignore-line
  String get mfCategory_smallCap => 'Small Cap';

  @override // coverage:ignore-line
  String get mfCategory_debt => 'Debt';

  @override // coverage:ignore-line
  String get mfCategory_mfIndex => 'Index Fund';

  @override // coverage:ignore-line
  String get mfCategory_industry => 'Sectoral / Industry';

  @override // coverage:ignore-line
  String get mfCategory_others => 'Others';

  @override
  String get sessionExpiredLogoutMessage =>
      'You were logged out because another device logged into this account.';

  @override
  String get sessionVerificationFailed =>
      'Session verification failed. Sync paused.';

  @override // coverage:ignore-line
  String get connectionFailedOffline =>
      'Connection failed. Switching to Offline Mode.';

  @override
  String get encryptedBackupPromptTitle => 'Encrypted Backup Found';

  @override
  String get encryptedBackupPromptBody =>
      'Your cloud backup is encrypted. Please enter your passcode to restore your data.';

  @override // coverage:ignore-line
  String get incorrectPasscodeError => 'Incorrect passcode. Please try again.';

  @override
  String get passcodeLabel => 'Passcode';

  @override
  String get allTypesLabel => 'All Types';

  @override // coverage:ignore-line
  String get sortByOldestFirst => 'Sort by Oldest First';

  @override // coverage:ignore-line
  String get sortByHighestGain => 'Sort by Highest Gain';

  @override // coverage:ignore-line
  String get deleteInvestmentTitle => 'Delete Investment?';

  @override // coverage:ignore-line
  String get deleteInvestmentConfirmation =>
      'This will permanently remove this investment record.';

  @override
  String get searchLabel => 'Search Investments';

  @override // coverage:ignore-line
  String get copyToClipboard => 'Copy to Clipboard';

  @override // coverage:ignore-line
  String get exportJsonTitle => 'Export Tickers (JSON)';

  @override // coverage:ignore-line
  String get importJsonTitle => 'Import Prices (JSON)';

  @override // coverage:ignore-line
  String get importJsonHint => 'Paste JSON here...';

  @override // coverage:ignore-line
  String get invalidJsonError => 'Invalid JSON format';

  @override // coverage:ignore-line
  String get importAction => 'Import';

  @override // coverage:ignore-line
  String get copiedToClipboard => 'Copied to clipboard!';

  @override
  String get addInvestmentTitle => 'Add Investment';

  @override
  String get editInvestmentTitle => 'Edit Investment';

  @override
  String get acquisitionDateLabel => 'Acquisition Date';

  @override
  String get acquisitionPriceLabel => 'Acquisition Price';

  @override // coverage:ignore-line
  String get invalidPriceError => 'Invalid Price';

  @override // coverage:ignore-line
  String get invalidQuantityError => 'Invalid Quantity';

  @override
  String longTermInLabel(String duration) {
    return 'LT in $duration';
  }

  @override
  String get updateAction => 'Update';

  @override
  String get recurringInvestmentHeader => 'Recurring Investment';

  @override
  String get recurringAmountLabel => 'Monthly Recurring Amount';

  @override
  String get nextRecurringDateLabel => 'Next Recurring Date';

  @override
  String get pauseRecurringLabel => 'Pause Recurring Payments';

  @override // coverage:ignore-line
  String get upcomingCommitmentsHeader => 'Upcoming Commitments';

  @override
  String get premiumSectionTile => 'Premium Features';

  @override
  String get subscriptionStatusLabel => 'Subscription Status';

  @override
  String get premiumActive => 'Premium Active';

  @override
  String get liteActive => 'Lite Active (Ad-Free)';

  @override
  String get freeTierActive => 'Free Tier';

  @override
  String get upgradeButtonLabel => 'Upgrade';

  @override
  String get upgradeToPremiumLabel => 'Upgrade to Premium';

  @override
  String expiresOnLabel(String date) {
    return 'Expires on: $date';
  }

  @override
  String get expiresNever => 'Never';

  @override
  String get selectRegionTitle => 'Select Cloud Region';

  @override
  String get selectRegionDescription =>
      'Choose where your data will be stored. This choice won\'t change after the first sync.';

  @override
  String get premiumFeaturesTitle => 'Premium Features';

  @override
  String get premiumTitle => 'Upgrade to Premium';

  @override
  String get premiumSubtitle => 'Unlock the full potential of Samriddhi Flow';

  @override
  String get featureCloudSyncTitle => 'Cloud Backup & Sync';

  @override
  String get featureCloudSyncDesc =>
      'Securely back up your data and sync across multiple devices.';

  @override
  String get featureAdFreeTitle => 'Ad-Free experience';

  @override
  String get featureAdFreeDesc =>
      'Focus on your finances without any interruptions.';

  @override
  String get upgradeToPremiumAction => 'UPGRADE TO PREMIUM';

  @override
  String get buyLiteAction => 'GET LITE (AD-FREE)';

  @override
  String get buyPremiumAction => 'GET PREMIUM (FULL ACCESS)';

  @override
  String get alreadyPremiumTitle => 'You are a Premium User!';

  @override
  String get alreadyPremiumSubtitle =>
      'Thank you for your support. You have access to all features.';

  @override
  String get noThanksButton => 'No, thanks';

  @override
  String get confirmButton => 'Confirm';

  @override
  String get serverRegionLabel => 'Cloud Backup Region';

  @override
  String get serverRegionDesc => 'Manual selection of backup storage zone';

  @override
  String get bulkUpdateCodeTitle => 'Update All Stock Codes?';

  @override
  String bulkUpdateCodeMessage(int count, String oldCode, String newCode) {
    return 'Found $count other items with code \"$oldCode\". Update them all to \"$newCode\"?';
  }

  @override
  String get updateAllAction => 'UPDATE ALL';

  @override
  String get updateOnlyThisAction => 'ONLY THIS';

  @override
  String get bulkUpdateValuationTitle => 'Synchronize Valuations?';

  @override
  String bulkUpdateValuationMessage(String code, int count, double price) {
    return 'The valuation for code \"$code\" has changed. Update $count other items to $price?';
  }
}
