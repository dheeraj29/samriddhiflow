import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Samriddhi Flow'**
  String get appTitle;

  /// Dashboard title
  ///
  /// In en, this message translates to:
  /// **'My Samriddhi'**
  String get mySamriddhi;

  /// Default value label
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultVal;

  /// Profile label with name
  ///
  /// In en, this message translates to:
  /// **'Profile: {name}'**
  String profileLabel(String name);

  /// Reminders icon tooltip
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersTooltip;

  /// Lock icon tooltip
  ///
  /// In en, this message translates to:
  /// **'Lock App'**
  String get lockAppTooltip;

  /// Logout icon tooltip
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutTooltip;

  /// Quick Actions section header
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActionsHeader;

  /// Recent Transactions section header
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactionsHeader;

  /// View All button text
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAllButton;

  /// Total Net Worth label
  ///
  /// In en, this message translates to:
  /// **'Total Net Worth'**
  String get totalNetWorthLabel;

  /// Current Savings label
  ///
  /// In en, this message translates to:
  /// **'Current Savings: '**
  String get currentSavingsLabel;

  /// Credit Card Bill Unpaid label
  ///
  /// In en, this message translates to:
  /// **'CC Bill (Unpaid)'**
  String get ccBillUnpaidLabel;

  /// Credit Card Unbilled label
  ///
  /// In en, this message translates to:
  /// **'CC Unbilled'**
  String get ccUnbilledLabel;

  /// Credit Card Usage label
  ///
  /// In en, this message translates to:
  /// **'CC Usage'**
  String get ccUsageLabel;

  /// Total Loan Liability label
  ///
  /// In en, this message translates to:
  /// **'Total Loan Liability'**
  String get totalLoanLiabilityLabel;

  /// Debt free estimation text
  ///
  /// In en, this message translates to:
  /// **'Debt Free in ~{months} months ({days} days)'**
  String debtFreeIn(String months, int days);

  /// Income for current month label
  ///
  /// In en, this message translates to:
  /// **'Income (Month)'**
  String get incomeMonthLabel;

  /// Budgeted expense label
  ///
  /// In en, this message translates to:
  /// **'Budget Expense'**
  String get budgetExpenseLabel;

  /// Monthly Budget Progress header
  ///
  /// In en, this message translates to:
  /// **'Monthly Budget Progress'**
  String get monthlyBudgetProgress;

  /// Expense shorthand label
  ///
  /// In en, this message translates to:
  /// **'Exp: '**
  String get expLabel;

  /// Remaining shorthand label
  ///
  /// In en, this message translates to:
  /// **'Rem: '**
  String get remLabel;

  /// Quick action Income
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeAction;

  /// Quick action Transfer
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferAction;

  /// Action label
  ///
  /// In en, this message translates to:
  /// **'Pay Bill'**
  String get payBillAction;

  /// Quick action Loans
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get loansAction;

  /// Quick action Taxes
  ///
  /// In en, this message translates to:
  /// **'Taxes'**
  String get taxesAction;

  /// Quick action Lending
  ///
  /// In en, this message translates to:
  /// **'Lending'**
  String get lendingAction;

  /// Empty state for transactions
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get noTransactionsYet;

  /// Backup reminder title
  ///
  /// In en, this message translates to:
  /// **'Unsaved Data: {count} transactions recorded since last backup.'**
  String unsavedDataTitle(int count);

  /// Button to go to backup settings
  ///
  /// In en, this message translates to:
  /// **'Go to Backup'**
  String get goToBackupButton;

  /// Dismiss button text
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissButton;

  /// Bottom nav Home tooltip
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTooltip;

  /// Bottom nav Accounts tooltip
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTooltip;

  /// Bottom nav Reports tooltip
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTooltip;

  /// Bottom nav Settings tooltip
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// Privacy policy title
  ///
  /// In en, this message translates to:
  /// **'Samriddhi Flow — Privacy Policy'**
  String get privacyPolicyTitle;

  /// Privacy policy introductory text
  ///
  /// In en, this message translates to:
  /// **'Your privacy is important to us. Here is how Samriddhi Flow handles your data:'**
  String get privacyPolicyIntro;

  /// Policy item title
  ///
  /// In en, this message translates to:
  /// **'Local-First Storage'**
  String get localFirstTitle;

  /// Policy item description
  ///
  /// In en, this message translates to:
  /// **'All your financial data is stored locally on your device by default. Nothing leaves your device unless you choose to back up.'**
  String get localFirstDesc;

  /// Policy item title
  ///
  /// In en, this message translates to:
  /// **'Cloud Backup'**
  String get cloudBackupTitle;

  /// Policy item description
  ///
  /// In en, this message translates to:
  /// **'Secure your sensitive financial data (accounts, transactions, etc.) with a passcode. This passcode is NEVER stored and is required to restore.'**
  String get cloudBackupDesc;

  /// Policy item title
  ///
  /// In en, this message translates to:
  /// **'Optional Encryption'**
  String get optionalEncryptionTitle;

  /// Policy item description
  ///
  /// In en, this message translates to:
  /// **'When backing up to the cloud, you can encrypt your data with a passcode of your choice. This passcode is NEVER stored anywhere — only you know it. Without the passcode, your cloud data cannot be read.'**
  String get optionalEncryptionDesc;

  /// Policy item title
  ///
  /// In en, this message translates to:
  /// **'No Tracking or Analytics'**
  String get noTrackingTitle;

  /// Policy item description
  ///
  /// In en, this message translates to:
  /// **'Samriddhi Flow does not collect, track, or transmit any usage analytics, personal information, or behavioral data.'**
  String get noTrackingDesc;

  /// Policy item title
  ///
  /// In en, this message translates to:
  /// **'Your Data, Your Control'**
  String get dataControlTitle;

  /// Policy item description
  ///
  /// In en, this message translates to:
  /// **'You can export, restore, or delete all your data at any time from the Settings screen. We believe you should have full ownership of your financial information.'**
  String get dataControlDesc;

  /// Close button text
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// Tooltip for profile switcher
  ///
  /// In en, this message translates to:
  /// **'Switch Profile ({name})'**
  String switchProfileTooltip(String name);

  /// Accounts screen title
  ///
  /// In en, this message translates to:
  /// **'My Accounts'**
  String get myAccounts;

  /// Tooltip to toggle number format
  ///
  /// In en, this message translates to:
  /// **'Switch to Extended Numbers'**
  String get extendedNumbersTooltip;

  /// Tooltip to toggle number format
  ///
  /// In en, this message translates to:
  /// **'Switch to Compact Numbers'**
  String get compactNumbersTooltip;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No accounts found.'**
  String get noAccountsFound;

  /// Button to add account
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccountButton;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Pinned Accounts'**
  String get pinnedAccountsHeader;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Savings Accounts'**
  String get savingsAccountsHeader;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Credit Cards'**
  String get creditCardsHeader;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get walletsHeader;

  /// Empty section message
  ///
  /// In en, this message translates to:
  /// **'No accounts in this section.'**
  String get noAccountsInSection;

  /// Button to add new account
  ///
  /// In en, this message translates to:
  /// **'Add New Account'**
  String get addNewAccountButton;

  /// Account type label
  ///
  /// In en, this message translates to:
  /// **'Savings Account'**
  String get savingsAccountType;

  /// Account type label
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletType;

  /// No description provided for @limitLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit Limit: {value}'**
  String limitLabel(String value);

  /// No description provided for @limitShort.
  ///
  /// In en, this message translates to:
  /// **'Limit: {value}'**
  String limitShort(String value);

  /// No description provided for @availableLabel.
  ///
  /// In en, this message translates to:
  /// **'Available: {value}'**
  String availableLabel(String value);

  /// No description provided for @availableShort.
  ///
  /// In en, this message translates to:
  /// **'Avail: {value}'**
  String availableShort(String value);

  /// Chip label
  ///
  /// In en, this message translates to:
  /// **'Billed'**
  String get billedChip;

  /// Chip label
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balanceChip;

  /// Chip label
  ///
  /// In en, this message translates to:
  /// **'Unbilled'**
  String get unbilledChip;

  /// Date label
  ///
  /// In en, this message translates to:
  /// **'Calculates on'**
  String get calculatesOn;

  /// Date label
  ///
  /// In en, this message translates to:
  /// **'Initial bill on'**
  String get initialBillOn;

  /// No description provided for @percentUsed.
  ///
  /// In en, this message translates to:
  /// **'{value}% used'**
  String percentUsed(String value);

  /// Menu option
  ///
  /// In en, this message translates to:
  /// **'Unpin Account'**
  String get unpinAccount;

  /// Menu option
  ///
  /// In en, this message translates to:
  /// **'Pin Account'**
  String get pinAccount;

  /// Menu option
  ///
  /// In en, this message translates to:
  /// **'View Transactions'**
  String get viewTransactions;

  /// Menu option
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get editAccount;

  /// Menu option
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// Billing info label
  ///
  /// In en, this message translates to:
  /// **'Last Bill Date: {date}'**
  String lastBillDate(String date);

  /// Billing info label
  ///
  /// In en, this message translates to:
  /// **'Next Bill Date: {date}'**
  String nextBillDate(String date);

  /// Menu option title
  ///
  /// In en, this message translates to:
  /// **'Update Billing Cycle'**
  String get updateBillingCycle;

  /// Menu option subtitle
  ///
  /// In en, this message translates to:
  /// **'Move to a new cycle day or due date safely'**
  String get updateBillingCycleDesc;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Select All (Filtered)'**
  String get selectAllTooltip;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'All Transactions'**
  String get allTransactionsTitle;

  /// Selection count label
  ///
  /// In en, this message translates to:
  /// **'{count} Selected'**
  String selectedCount(int count);

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Select Transactions'**
  String get selectTransactionsTooltip;

  /// Dropdown option
  ///
  /// In en, this message translates to:
  /// **'No Account (Manual)'**
  String get noAccountManual;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No matches for this filter.'**
  String get noMatchesFilter;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete {count} Transactions?'**
  String deleteSelectedTitle(int count);

  /// Dialog content
  ///
  /// In en, this message translates to:
  /// **'Items will be moved to Recycle Bin.'**
  String get itemsMoveToRecycleBin;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Transactions moved to Recycle Bin'**
  String get transactionsMovedToRecycleBin;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction?'**
  String get deleteTransactionTitle;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Moved to Recycle Bin'**
  String get movedToRecycleBin;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @salaryTab.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get salaryTab;

  /// No description provided for @housePropTab.
  ///
  /// In en, this message translates to:
  /// **'House Prop'**
  String get housePropTab;

  /// No description provided for @businessTab.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get businessTab;

  /// No description provided for @capGainsTab.
  ///
  /// In en, this message translates to:
  /// **'Cap Gains'**
  String get capGainsTab;

  /// No description provided for @dividendTab.
  ///
  /// In en, this message translates to:
  /// **'Dividend'**
  String get dividendTab;

  /// No description provided for @taxPaidTab.
  ///
  /// In en, this message translates to:
  /// **'Tax Paid'**
  String get taxPaidTab;

  /// No description provided for @giftsTab.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get giftsTab;

  /// No description provided for @agriTab.
  ///
  /// In en, this message translates to:
  /// **'Agri'**
  String get agriTab;

  /// No description provided for @otherTab.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherTab;

  /// No description provided for @categoryDataClearedStatus.
  ///
  /// In en, this message translates to:
  /// **'{category} data cleared.'**
  String categoryDataClearedStatus(String category);

  /// No description provided for @taxDataClearedStatus.
  ///
  /// In en, this message translates to:
  /// **'All tax data for the fiscal year has been cleared.'**
  String get taxDataClearedStatus;

  /// No description provided for @switchCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Category'**
  String get switchCategoryTitle;

  /// No description provided for @approxGrossIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Approx. Gross Income'**
  String get approxGrossIncomeLabel;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Do you want to discard them and leave?'**
  String get unsavedChangesContent;

  /// Discard action label
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardAction;

  /// No description provided for @dividendIncomeBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Dividend Income Breakdown'**
  String get dividendIncomeBreakdownTitle;

  /// No description provided for @totalDividendIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Dividend Income'**
  String get totalDividendIncomeLabel;

  /// No description provided for @salaryStructuresTitle.
  ///
  /// In en, this message translates to:
  /// **'Salary Structures'**
  String get salaryStructuresTitle;

  /// No description provided for @addStructureAction.
  ///
  /// In en, this message translates to:
  /// **'Add Structure'**
  String get addStructureAction;

  /// No description provided for @effectiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Effective'**
  String get effectiveLabel;

  /// No description provided for @exemptionsDeductionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Exemptions & Deductions (Yearly)'**
  String get exemptionsDeductionsTitle;

  /// No description provided for @independentAllowancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Independent Allowances'**
  String get independentAllowancesTitle;

  /// No description provided for @noIndependentAllowancesNote.
  ///
  /// In en, this message translates to:
  /// **'No independent allowances added.'**
  String get noIndependentAllowancesNote;

  /// No description provided for @addIndependentAllowanceAction.
  ///
  /// In en, this message translates to:
  /// **'Add Independent Allowance'**
  String get addIndependentAllowanceAction;

  /// No description provided for @independentDeductionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Independent Deductions'**
  String get independentDeductionsTitle;

  /// No description provided for @noIndependentDeductionsNote.
  ///
  /// In en, this message translates to:
  /// **'No independent deductions added.'**
  String get noIndependentDeductionsNote;

  /// No description provided for @addIndependentDeductionAction.
  ///
  /// In en, this message translates to:
  /// **'Add Independent Deduction'**
  String get addIndependentDeductionAction;

  /// No description provided for @netMonthlyLabel.
  ///
  /// In en, this message translates to:
  /// **'NET MONTHLY'**
  String get netMonthlyLabel;

  /// No description provided for @monthlyTakeHomeBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Take-home Breakdown'**
  String get monthlyTakeHomeBreakdownTitle;

  /// No description provided for @housePropertiesTitle.
  ///
  /// In en, this message translates to:
  /// **'House Properties'**
  String get housePropertiesTitle;

  /// No description provided for @addPropertyAction.
  ///
  /// In en, this message translates to:
  /// **'Add Property'**
  String get addPropertyAction;

  /// No description provided for @totalRentReceivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Rent Received'**
  String get totalRentReceivedLabel;

  /// No description provided for @totalInterestOnLoanLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Interest on Loan'**
  String get totalInterestOnLoanLabel;

  /// No description provided for @noHousePropertiesNote.
  ///
  /// In en, this message translates to:
  /// **'No house properties found for this year.'**
  String get noHousePropertiesNote;

  /// No description provided for @projectedAnnualIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Projected Annual Income (Interactive Summary)'**
  String get projectedAnnualIncomeTitle;

  /// No description provided for @totalGrossSalaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Gross Salary'**
  String get totalGrossSalaryLabel;

  /// No description provided for @lessStandardDeductionLabel.
  ///
  /// In en, this message translates to:
  /// **'Less: Standard Deduction'**
  String get lessStandardDeductionLabel;

  /// No description provided for @lessStatutoryExemptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Less: Statutory Exemptions'**
  String get lessStatutoryExemptionsLabel;

  /// No description provided for @totalTaxableSalaryIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Taxable Salary Income'**
  String get totalTaxableSalaryIncomeLabel;

  /// No description provided for @selfOccupiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Self Occupied'**
  String get selfOccupiedLabel;

  /// No description provided for @businessProfessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Business & Profession'**
  String get businessProfessionTitle;

  /// No description provided for @addBusinessAction.
  ///
  /// In en, this message translates to:
  /// **'Add Business'**
  String get addBusinessAction;

  /// No description provided for @totalTurnoverLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Turnover'**
  String get totalTurnoverLabel;

  /// No description provided for @totalNetIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Net Income'**
  String get totalNetIncomeLabel;

  /// No description provided for @taxableBusinessIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxable Business Income'**
  String get taxableBusinessIncomeLabel;

  /// No description provided for @noBusinessIncomeNote.
  ///
  /// In en, this message translates to:
  /// **'No business income found for this year.'**
  String get noBusinessIncomeNote;

  /// No description provided for @businessNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Business Name'**
  String get businessNameLabel;

  /// No description provided for @grossTurnoverReceiptsLabel.
  ///
  /// In en, this message translates to:
  /// **'Gross Turnover / Receipts'**
  String get grossTurnoverReceiptsLabel;

  /// No description provided for @netIncomeProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Net Income / Profit'**
  String get netIncomeProfitLabel;

  /// No description provided for @actualProfitHelper.
  ///
  /// In en, this message translates to:
  /// **'Actual net profit from business'**
  String get actualProfitHelper;

  /// No description provided for @taxationTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxation Type'**
  String get taxationTypeLabel;

  /// No description provided for @presumptiveTaxationHelper.
  ///
  /// In en, this message translates to:
  /// **'Presumptive taxation allows computing tax on a percentage of turnover.'**
  String get presumptiveTaxationHelper;

  /// No description provided for @turnoverExceedsLimitWarning.
  ///
  /// In en, this message translates to:
  /// **'Turnover exceeds limit of {limit} for presumptive taxation.'**
  String turnoverExceedsLimitWarning(String limit);

  /// No description provided for @capitalGainsTitle.
  ///
  /// In en, this message translates to:
  /// **'Capital Gains'**
  String get capitalGainsTitle;

  /// No description provided for @netCapitalGainsSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Net Capital Gains Summary'**
  String get netCapitalGainsSummaryTitle;

  /// No description provided for @longTermEquityLabel.
  ///
  /// In en, this message translates to:
  /// **'Long Term (Equity)'**
  String get longTermEquityLabel;

  /// No description provided for @longTermOtherLabel.
  ///
  /// In en, this message translates to:
  /// **'Long Term (Other)'**
  String get longTermOtherLabel;

  /// No description provided for @assetSoldLabel.
  ///
  /// In en, this message translates to:
  /// **'Asset Sold'**
  String get assetSoldLabel;

  /// No description provided for @saleAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Sale Amount'**
  String get saleAmountLabel;

  /// No description provided for @gainDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Gain Date'**
  String get gainDateLabel;

  /// No description provided for @intendToReinvestLabel.
  ///
  /// In en, this message translates to:
  /// **'Intend to Reinvest?'**
  String get intendToReinvestLabel;

  /// No description provided for @reinvestmentExemptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Section 54/54F/54EC exemptions'**
  String get reinvestmentExemptionsSubtitle;

  /// No description provided for @reinvestmentDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reinvestment Details'**
  String get reinvestmentDetailsTitle;

  /// No description provided for @pendingNotDecidedLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending / Not Decided'**
  String get pendingNotDecidedLabel;

  /// No description provided for @amountInvestedLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount Invested'**
  String get amountInvestedLabel;

  /// No description provided for @reinvestDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Reinvest Date'**
  String get reinvestDateLabel;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @otherSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Other Sources'**
  String get otherSourcesTitle;

  /// No description provided for @addOtherIncomeAction.
  ///
  /// In en, this message translates to:
  /// **'Add Other Income'**
  String get addOtherIncomeAction;

  /// No description provided for @dividendsLabel.
  ///
  /// In en, this message translates to:
  /// **'Dividends'**
  String get dividendsLabel;

  /// No description provided for @taxableOtherIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxable Other Income'**
  String get taxableOtherIncomeLabel;

  /// No description provided for @noOtherIncomeNote.
  ///
  /// In en, this message translates to:
  /// **'No Other Income added.'**
  String get noOtherIncomeNote;

  /// No description provided for @incomeTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Income Type'**
  String get incomeTypeLabel;

  /// No description provided for @grossAmountCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Gross Amount ({symbol})'**
  String grossAmountCurrencyLabel(String symbol);

  /// No description provided for @linkExemptionOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Link Exemption (Optional)'**
  String get linkExemptionOptionalLabel;

  /// No description provided for @allFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilterLabel;

  /// No description provided for @manualFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manualFilterLabel;

  /// No description provided for @syncedFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncedFilterLabel;

  /// No description provided for @advanceTaxScheduleHintsTitle.
  ///
  /// In en, this message translates to:
  /// **'Advance Tax Schedule Hints'**
  String get advanceTaxScheduleHintsTitle;

  /// No description provided for @advanceTaxBreakdownLabel.
  ///
  /// In en, this message translates to:
  /// **'Base: {base} • Cess: {cess} • Interest: {interest}'**
  String advanceTaxBreakdownLabel(String base, String cess, String interest);

  /// No description provided for @advanceTaxBreakdownLabelNoInterest.
  ///
  /// In en, this message translates to:
  /// **'Base: {base} • Cess: {cess}'**
  String advanceTaxBreakdownLabelNoInterest(String base, String cess);

  /// No description provided for @noEntriesFoundNote.
  ///
  /// In en, this message translates to:
  /// **'No entries found.'**
  String get noEntriesFoundNote;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String sourceLabel(String source);

  /// No description provided for @sourceDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Source/Description'**
  String get sourceDescriptionLabel;

  /// No description provided for @cashGiftsTotalTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash Gifts (Total)'**
  String get cashGiftsTotalTitle;

  /// No description provided for @addGiftAction.
  ///
  /// In en, this message translates to:
  /// **'Add Gift'**
  String get addGiftAction;

  /// No description provided for @totalGiftsReceivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Gifts Received'**
  String get totalGiftsReceivedLabel;

  /// No description provided for @taxablePortionLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxable Portion'**
  String get taxablePortionLabel;

  /// No description provided for @giftDescriptionSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Gift Description / Source'**
  String get giftDescriptionSourceLabel;

  /// No description provided for @giftTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Gift Type'**
  String get giftTypeLabel;

  /// No description provided for @netAgriIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Net Agricultural Income'**
  String get netAgriIncomeLabel;

  /// No description provided for @noEntriesMatchFilteringNote.
  ///
  /// In en, this message translates to:
  /// **'No entries match the current filters.'**
  String get noEntriesMatchFilteringNote;

  /// No description provided for @payoutMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Payout Month'**
  String get payoutMonthLabel;

  /// No description provided for @startMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Month'**
  String get startMonthLabel;

  /// No description provided for @deductionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Deduction Name'**
  String get deductionNameLabel;

  /// No description provided for @allowanceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Allowance Name'**
  String get allowanceNameLabel;

  /// No description provided for @annualDeductionAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Deduction Amount'**
  String get annualDeductionAmountLabel;

  /// No description provided for @annualPayoutAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Payout Amount'**
  String get annualPayoutAmountLabel;

  /// No description provided for @exemptionLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Exemption Limit'**
  String get exemptionLimitLabel;

  /// No description provided for @monthlyAmountsLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly Amounts'**
  String get monthlyAmountsLabel;

  /// No description provided for @noPayoutMonthsSelectedNote.
  ///
  /// In en, this message translates to:
  /// **'No payout months selected.'**
  String get noPayoutMonthsSelectedNote;

  /// No description provided for @unemploymentNoSalaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Unemployment / No Salary Periods'**
  String get unemploymentNoSalaryTitle;

  /// No description provided for @effectiveDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Effective Date'**
  String get effectiveDateLabel;

  /// No description provided for @annualBasicPayLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Basic Pay (CTC)'**
  String get annualBasicPayLabel;

  /// No description provided for @annualFixedAllowancesLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Fixed Allowances (CTC)'**
  String get annualFixedAllowancesLabel;

  /// No description provided for @annualPerformancePayLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Performance Pay'**
  String get annualPerformancePayLabel;

  /// No description provided for @annualVariablePayLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Variable Pay'**
  String get annualVariablePayLabel;

  /// No description provided for @payoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get payoutLabel;

  /// No description provided for @annualEmployeePFLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Employee PF'**
  String get annualEmployeePFLabel;

  /// No description provided for @annualGratuityContributionLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Gratuity Contribution'**
  String get annualGratuityContributionLabel;

  /// No description provided for @customAllowancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Allowances'**
  String get customAllowancesTitle;

  /// No description provided for @noCustomAllowancesNote.
  ///
  /// In en, this message translates to:
  /// **'No custom allowances'**
  String get noCustomAllowancesNote;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Add Transaction'**
  String get addTransactionTitle;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransactionTitle;

  /// Transaction type
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseType;

  /// Transaction type
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeType;

  /// Transaction type
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferType;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredError;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'From Account'**
  String get fromAccountLabel;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountLabel;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'To Account'**
  String get toAccountLabel;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Select Recipient'**
  String get selectRecipient;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Invalid Amount'**
  String get invalidAmountError;

  /// Switch label
  ///
  /// In en, this message translates to:
  /// **'Make Recurring'**
  String get makeRecurring;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Repeat this transaction automatically'**
  String get repeatAutomatically;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Recurring Action'**
  String get recurringAction;

  /// Segment button option
  ///
  /// In en, this message translates to:
  /// **'Pay & Schedule'**
  String get payAndSchedule;

  /// Segment button option
  ///
  /// In en, this message translates to:
  /// **'Just Schedule'**
  String get justSchedule;

  /// Recurrence info
  ///
  /// In en, this message translates to:
  /// **'First Execution: {date}'**
  String firstExecution(String date);

  /// No description provided for @frequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency: {label}'**
  String frequencyLabel(String label);

  /// Dropdown label
  ///
  /// In en, this message translates to:
  /// **'Schedule Type'**
  String get scheduleTypeLabel;

  /// Switch label
  ///
  /// In en, this message translates to:
  /// **'Adjust for Holidays'**
  String get adjustForHolidays;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Schedule a day earlier if it lands on a holiday/weekend'**
  String get adjustForHolidaysDesc;

  /// Dropdown label
  ///
  /// In en, this message translates to:
  /// **'Select Weekday'**
  String get selectWeekdayLabel;

  /// Weekday
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// Weekday
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// Weekday
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// Weekday
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// Weekday
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// Weekday
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// Weekday
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Save Transaction'**
  String get saveTransaction;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Update Transaction'**
  String get updateTransaction;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Gain / Profit Amount'**
  String get capitalGainProfitAmount;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Holding Tenure (Months)'**
  String get holdingTenureMonths;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'e.g., 12'**
  String get holdingTenureHint;

  /// Field helper
  ///
  /// In en, this message translates to:
  /// **'Enter months held (Long-term: 12+ months for stocks)'**
  String get holdingTenureHelper;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profitLabel;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get lossLabel;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Purchase Cost'**
  String get purchaseCostLabel;

  /// Field helper
  ///
  /// In en, this message translates to:
  /// **'Enter the profit (positive) or loss (negative)'**
  String get gainAmountHelper;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No transactions found.'**
  String get noTransactionsFound;

  /// Frequency
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// Frequency
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// Frequency
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// Frequency
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// Schedule type
  ///
  /// In en, this message translates to:
  /// **'Fixed Date'**
  String get fixedDate;

  /// Schedule type
  ///
  /// In en, this message translates to:
  /// **'Every Weekend'**
  String get everyWeekend;

  /// Schedule type
  ///
  /// In en, this message translates to:
  /// **'Last Weekend'**
  String get lastWeekend;

  /// Schedule type
  ///
  /// In en, this message translates to:
  /// **'Last Day of Month'**
  String get lastDayOfMonth;

  /// Schedule type
  ///
  /// In en, this message translates to:
  /// **'Last Working Day'**
  String get lastWorkingDay;

  /// Schedule type
  ///
  /// In en, this message translates to:
  /// **'First Working Day'**
  String get firstWorkingDay;

  /// Schedule type
  ///
  /// In en, this message translates to:
  /// **'Specific Weekday'**
  String get specificWeekday;

  /// Category tag
  ///
  /// In en, this message translates to:
  /// **'Capital Gain'**
  String get capitalGainTag;

  /// Category tag
  ///
  /// In en, this message translates to:
  /// **'Direct Tax'**
  String get directTaxTag;

  /// Category tag
  ///
  /// In en, this message translates to:
  /// **'Budget Free'**
  String get budgetFreeTag;

  /// Category tag
  ///
  /// In en, this message translates to:
  /// **'Tax Free'**
  String get taxFreeTag;

  /// Account usage shorthand
  ///
  /// In en, this message translates to:
  /// **'Usage: {amount}'**
  String usageShort(String amount);

  /// Account balance shorthand
  ///
  /// In en, this message translates to:
  /// **'Bal: {amount}'**
  String balanceShort(String amount);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Financial Reports'**
  String get financialReportsTitle;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No data available.'**
  String get noDataAvailable;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No data for selected criteria.'**
  String get noDataSelectedCriteria;

  /// Report type
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get spendingReport;

  /// Report type
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeReport;

  /// Report type
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get loanReport;

  /// Dropdown label
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get periodLabel;

  /// Time period
  ///
  /// In en, this message translates to:
  /// **'30 Days'**
  String get days30;

  /// Time period
  ///
  /// In en, this message translates to:
  /// **'90 Days'**
  String get days90;

  /// Time period
  ///
  /// In en, this message translates to:
  /// **'Last Year'**
  String get lastYear;

  /// Time period
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthOption;

  /// Time period
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get yearOption;

  /// Time period
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// Filter label
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get loanLabel;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'All Loans'**
  String get allLoans;

  /// Filter label
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allOption;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'All Accounts'**
  String get allAccounts;

  /// Filter option
  ///
  /// In en, this message translates to:
  /// **'Manual (No Account)'**
  String get manualNoAccount;

  /// Action label
  ///
  /// In en, this message translates to:
  /// **'Filter Categories'**
  String get filterCategories;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'{count} Categories Excluded'**
  String categoriesExcluded(int count);

  /// Dropdown label
  ///
  /// In en, this message translates to:
  /// **'Select Month'**
  String get selectMonthLabel;

  /// Dropdown label
  ///
  /// In en, this message translates to:
  /// **'Select Year'**
  String get selectYearLabel;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Total Liability'**
  String get totalLiability;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'EMI Paid'**
  String get emiPaid;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Prepayment'**
  String get prepayment;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get totalPaid;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// Category name for grouped small items
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get othersCategory;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Capital Gains (Realized)'**
  String get capitalGainsRealized;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Capital Losses (Realized)'**
  String get capitalLossesRealized;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Expand/Collapse All'**
  String get expandCollapseTooltip;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSection;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Dashboard Customization'**
  String get dashboardCustomizationSection;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get cloudSyncSection;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagementSection;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Feature Management'**
  String get featureManagementSection;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Profile Management'**
  String get profileManagementSection;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesSection;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get authSection;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securitySection;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get appInfoSection;

  /// Tile title
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeModeLabel;

  /// Theme mode
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// Theme mode
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// Theme mode
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Show Income & Expense'**
  String get showIncomeExpenseLabel;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Display monthly summary cards'**
  String get showIncomeExpenseDesc;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Show Budget Indicator'**
  String get showBudgetLabel;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Display monthly budget progress bar'**
  String get showBudgetDesc;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Connection Paused'**
  String get connectionPaused;

  /// Card description
  ///
  /// In en, this message translates to:
  /// **'You are in Offline Mode. Cloud Sync is deferred.'**
  String get offlineModeDesc;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get retryConnection;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Retrying connection...'**
  String get retryingConnection;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Internet restored! Ready to sync.'**
  String get internetRestored;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Still offline. Check connection.'**
  String get stillOffline;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Enable Cloud Sync'**
  String get enableCloudSync;

  /// Card description
  ///
  /// In en, this message translates to:
  /// **'Securely back up your data to the cloud and sync across devices.'**
  String get enableCloudSyncDesc;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Login to Setup Cloud'**
  String get loginToSetupCloud;

  /// No description provided for @accountLabelWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Account: {email}'**
  String accountLabelWithEmail(String email);

  /// Status message
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync Active'**
  String get cloudSyncActive;

  /// Warning message
  ///
  /// In en, this message translates to:
  /// **'Note: Categories aren\'t encrypted in cloud currently.'**
  String get categoriesEncryptionWarning;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Migrate/Sync Now'**
  String get migrateSyncNow;

  /// Tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Restore deleted transactions'**
  String get recycleBinDesc;

  /// Tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Export all data to a ZIP file'**
  String get backupDataZipDesc;

  /// Tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Import data from a ZIP file'**
  String get restoreDataZipDesc;

  /// Tile title
  ///
  /// In en, this message translates to:
  /// **'Repair Data'**
  String get repairDataLabel;

  /// Tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Fix data consistency issues'**
  String get repairDataDesc;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Data Repair'**
  String get dataRepairTitle;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Running repair...'**
  String get runningRepair;

  /// Tile subtitle
  ///
  /// In en, this message translates to:
  /// **'View or delete automated payments'**
  String get manageRecurringPaymentsDesc;

  /// Tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Configure non-working days'**
  String get holidayManagerDesc;

  /// Tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Add, edit, or delete categories'**
  String get manageCategoriesDesc;

  /// Switch title
  ///
  /// In en, this message translates to:
  /// **'Smart Calculator'**
  String get smartCalculatorLabel;

  /// Switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Enable Quick Sum Tracker on transactions'**
  String get smartCalculatorDesc;

  /// No description provided for @taxDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Tax Dashboard'**
  String get taxDashboardTitle;

  /// No description provided for @taxYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax Year'**
  String get taxYearLabel;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Capital Gains'**
  String get capitalGains;

  /// No description provided for @cessLabel.
  ///
  /// In en, this message translates to:
  /// **'Cess'**
  String get cessLabel;

  /// No description provided for @tdsTcsLabel.
  ///
  /// In en, this message translates to:
  /// **'TDS / TCS Tracked'**
  String get tdsTcsLabel;

  /// Reminder title
  ///
  /// In en, this message translates to:
  /// **'Advance Tax Overdue!'**
  String get advanceTaxOverdue;

  /// Label for manual execution
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manualLabel;

  /// Label for automatic execution
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoLabel;

  /// Calendar event description
  ///
  /// In en, this message translates to:
  /// **'Recurring payment: {title}'**
  String recurringPaymentCalendarDescription(String title);

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Skip Cycle?'**
  String get skipCycleTitle;

  /// Dialog content
  ///
  /// In en, this message translates to:
  /// **'Advance \"{title}\" to the next cycle without recording a transaction?'**
  String skipCycleConfirmation(String title);

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get skipAction;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No upcoming tax installments.'**
  String get noTaxInstallmentsDue;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Upcoming Tax Installments'**
  String get upcomingTaxInstallments;

  /// Badge text
  ///
  /// In en, this message translates to:
  /// **'{days}d Late'**
  String daysLate(int days);

  /// Badge text
  ///
  /// In en, this message translates to:
  /// **'Due Today'**
  String get dueToday;

  /// Days remaining
  ///
  /// In en, this message translates to:
  /// **'{days} d left'**
  String daysLeftLabel(int days);

  /// Tax reminder detail
  ///
  /// In en, this message translates to:
  /// **'Next: {amount} due by {date}'**
  String nextTaxInstallmentLabel(String amount, String date);

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorLabel(String message);

  /// Reminder title
  ///
  /// In en, this message translates to:
  /// **'Upcoming Advance Tax'**
  String get upcomingAdvanceTax;

  /// No description provided for @insurancePortfolioTooltip.
  ///
  /// In en, this message translates to:
  /// **'Insurance Portfolio'**
  String get insurancePortfolioTooltip;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @tapToSwitchLabel.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch'**
  String get tapToSwitchLabel;

  /// No description provided for @copyCategoriesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy Categories from another profile'**
  String get copyCategoriesTooltip;

  /// No description provided for @createProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get createProfileTitle;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile Name'**
  String get profileNameLabel;

  /// No description provided for @createButton.
  ///
  /// In en, this message translates to:
  /// **'CREATE'**
  String get createButton;

  /// No description provided for @currencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencyLabel;

  /// No description provided for @monthlyBudgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly Budget'**
  String get monthlyBudgetLabel;

  /// No description provided for @setMonthlyBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Monthly Budget'**
  String get setMonthlyBudgetTitle;

  /// No description provided for @backupIntervalTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup Interval'**
  String get backupIntervalTitle;

  /// No description provided for @updateApplicationDesc.
  ///
  /// In en, this message translates to:
  /// **'Clear cache and reload latest version'**
  String get updateApplicationDesc;

  /// No description provided for @installAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Add to Home Screen for Offline use'**
  String get installAppDesc;

  /// No description provided for @clearCloudDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Wipe current cloud backup while keeping your account connected for future syncs.'**
  String get clearCloudDataDesc;

  /// No description provided for @internetRequiredForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Internet connection required to check for updates.'**
  String get internetRequiredForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get checkingForUpdates;

  /// No description provided for @upToDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Up to Date'**
  String get upToDateTitle;

  /// No description provided for @cloudSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync Success!'**
  String get cloudSyncSuccess;

  /// No description provided for @syncErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync Error: {error}'**
  String syncErrorLabel(String error);

  /// No description provided for @backupFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup Failed: {error}'**
  String backupFailedLabel(String error);

  /// No description provided for @restoringFromZipTitle.
  ///
  /// In en, this message translates to:
  /// **'Restoring from ZIP'**
  String get restoringFromZipTitle;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @restoreZipWarning.
  ///
  /// In en, this message translates to:
  /// **'This will PERMANENTLY WIPE all local data and replace it with the backup content.'**
  String get restoreZipWarning;

  /// No description provided for @restoreCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Complete'**
  String get restoreCompleteTitle;

  /// No description provided for @restoredItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Restored items:'**
  String get restoredItemsLabel;

  /// No description provided for @restoreFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'Restore Failed: {error}'**
  String restoreFailedLabel(String error);

  /// No description provided for @cloudRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Restore'**
  String get cloudRestoreTitle;

  /// No description provided for @criticalWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Critical Warning'**
  String get criticalWarningTitle;

  /// No description provided for @useCloudRestoreQuestion.
  ///
  /// In en, this message translates to:
  /// **'Use Cloud Restore?'**
  String get useCloudRestoreQuestion;

  /// No description provided for @clearCloudDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Cloud Data (Keep Account)'**
  String get clearCloudDataTitle;

  /// No description provided for @clearButton.
  ///
  /// In en, this message translates to:
  /// **'CLEAR'**
  String get clearButton;

  /// No description provided for @includePinInCloudBackup.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to include it in your secure cloud backup.'**
  String get includePinInCloudBackup;

  /// No description provided for @includePinInZip.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to include it in your backup ZIP.'**
  String get includePinInZip;

  /// No description provided for @backupReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup Reminder'**
  String get backupReminderTitle;

  /// No description provided for @selectCreditCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Credit Card'**
  String get selectCreditCardTitle;

  /// No description provided for @claimOwnershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Claim Ownership?'**
  String get claimOwnershipTitle;

  /// No description provided for @claimOwnershipDesc.
  ///
  /// In en, this message translates to:
  /// **'This account is currently active on another device. Taking ownership will allow you to Backup or Restore here, but will lock the other device out.'**
  String get claimOwnershipDesc;

  /// No description provided for @claimOwnershipAction.
  ///
  /// In en, this message translates to:
  /// **'Claim Ownership'**
  String get claimOwnershipAction;

  /// No description provided for @allCreditCardsLabel.
  ///
  /// In en, this message translates to:
  /// **'All Credit Cards'**
  String get allCreditCardsLabel;

  /// No description provided for @loansScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get loansScreenTitle;

  /// No description provided for @monthsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month left} other{{count} months left}}'**
  String monthsLeft(num count);

  /// No description provided for @taxInitializationError.
  ///
  /// In en, this message translates to:
  /// **'Error initializing tax services: {error}'**
  String taxInitializationError(String error);

  /// No description provided for @taxableInsuranceAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Taxable Insurance Payouts Detected'**
  String get taxableInsuranceAlertTitle;

  /// No description provided for @taxableInsuranceAlertMessage.
  ///
  /// In en, this message translates to:
  /// **'Insurance policies crossing the 5L tax limit in FY {year}-{nextYear} have been detected. Ensure they are tracked for capital gains.'**
  String taxableInsuranceAlertMessage(int year, int nextYear);

  /// No description provided for @viewPoliciesAction.
  ///
  /// In en, this message translates to:
  /// **'View Policies'**
  String get viewPoliciesAction;

  /// No description provided for @syncingStatus.
  ///
  /// In en, this message translates to:
  /// **'Syncing data...'**
  String get syncingStatus;

  /// No description provided for @syncCompleteStatus.
  ///
  /// In en, this message translates to:
  /// **'Data synchronized successfully!'**
  String get syncCompleteStatus;

  /// No description provided for @syncFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailedStatus(String error);

  /// No description provided for @capitalGainLabel.
  ///
  /// In en, this message translates to:
  /// **'Capital Gain'**
  String get capitalGainLabel;

  /// No description provided for @expiredStatus.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expiredStatus;

  /// No description provided for @addReinvestmentTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Reinvestment'**
  String get addReinvestmentTooltip;

  /// No description provided for @capitalGainsTrackerTitle.
  ///
  /// In en, this message translates to:
  /// **'Capital Gains Tracker'**
  String get capitalGainsTrackerTitle;

  /// No description provided for @capitalGainsTrackerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tracking reinvestment deadlines for gains within {years} years.'**
  String capitalGainsTrackerSubtitle(double years);

  /// No description provided for @projectedTaxLiabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Projected Tax Liability'**
  String get projectedTaxLiabilityTitle;

  /// No description provided for @grossIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Gross Income'**
  String get grossIncomeLabel;

  /// No description provided for @capitalGainsLabel.
  ///
  /// In en, this message translates to:
  /// **'Capital Gains'**
  String get capitalGainsLabel;

  /// No description provided for @capitalGainsDeductionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Capital Gains Exemptions'**
  String get capitalGainsDeductionsLabel;

  /// No description provided for @deductionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Deductions'**
  String get deductionsLabel;

  /// No description provided for @taxableIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxable Income'**
  String get taxableIncomeLabel;

  /// No description provided for @taxOnIncomeSlabLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax on Income (Slab)'**
  String get taxOnIncomeSlabLabel;

  /// No description provided for @taxOnCapitalGainsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax on Capital Gains'**
  String get taxOnCapitalGainsLabel;

  /// No description provided for @totalTaxLiabilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Tax Liability'**
  String get totalTaxLiabilityLabel;

  /// No description provided for @cessOnSalaryTdsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cess included in Salary TDS'**
  String get cessOnSalaryTdsLabel;

  /// No description provided for @cessOnOtherSlabLabel.
  ///
  /// In en, this message translates to:
  /// **'Cess on Other Slab Tax'**
  String get cessOnOtherSlabLabel;

  /// No description provided for @cessOnSpecialLabel.
  ///
  /// In en, this message translates to:
  /// **'Capital Gains Cess'**
  String get cessOnSpecialLabel;

  /// No description provided for @advanceTaxPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Advance Tax Paid'**
  String get advanceTaxPaidLabel;

  /// No description provided for @taxShortfallInterestLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax Shortfall Interest'**
  String get taxShortfallInterestLabel;

  /// No description provided for @netTaxPayableLabel.
  ///
  /// In en, this message translates to:
  /// **'Net Tax Payable'**
  String get netTaxPayableLabel;

  /// No description provided for @suggestedItrLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggested ITR form: {form}'**
  String suggestedItrLabel(String form);

  /// No description provided for @advanceTaxOverdueTitle.
  ///
  /// In en, this message translates to:
  /// **'Advance Tax OVERDUE'**
  String get advanceTaxOverdueTitle;

  /// No description provided for @actionRequiredAdvanceTaxTitle.
  ///
  /// In en, this message translates to:
  /// **'Action Required: Advance Tax'**
  String get actionRequiredAdvanceTaxTitle;

  /// No description provided for @upcomingAdvanceTaxTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Advance Tax'**
  String get upcomingAdvanceTaxTitle;

  /// No description provided for @advanceTaxNextDueMessage.
  ///
  /// In en, this message translates to:
  /// **'Next due: {amount} by {date}'**
  String advanceTaxNextDueMessage(String amount, String date);

  /// No description provided for @lateStatusDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days late'**
  String lateStatusDays(int days);

  /// No description provided for @dueTodayStatus.
  ///
  /// In en, this message translates to:
  /// **'DUE TODAY'**
  String get dueTodayStatus;

  /// No description provided for @daysLeftStatus.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String daysLeftStatus(int days);

  /// No description provided for @taxRulesUpdatedStatus.
  ///
  /// In en, this message translates to:
  /// **'Tax rules updated successfully.'**
  String get taxRulesUpdatedStatus;

  /// No description provided for @addPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Insurance Policy'**
  String get addPolicyTitle;

  /// No description provided for @editPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Insurance Policy'**
  String get editPolicyTitle;

  /// No description provided for @policyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Policy Name'**
  String get policyNameLabel;

  /// No description provided for @annualPremiumLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Premium ({currency})'**
  String annualPremiumLabel(String currency);

  /// No description provided for @sumAssuredLabel.
  ///
  /// In en, this message translates to:
  /// **'Sum Assured ({currency})'**
  String sumAssuredLabel(String currency);

  /// No description provided for @issueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Issue Date'**
  String get issueDateLabel;

  /// No description provided for @isUlipLabel.
  ///
  /// In en, this message translates to:
  /// **'Is ULIP?'**
  String get isUlipLabel;

  /// No description provided for @enableInstallmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Installment?'**
  String get enableInstallmentLabel;

  /// No description provided for @installmentStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Installment Start'**
  String get installmentStartLabel;

  /// No description provided for @addToDashboardAction.
  ///
  /// In en, this message translates to:
  /// **'Add to Dashboard'**
  String get addToDashboardAction;

  /// No description provided for @policiesListTab.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get policiesListTab;

  /// No description provided for @taxRulesTab.
  ///
  /// In en, this message translates to:
  /// **'Tax Rules'**
  String get taxRulesTab;

  /// No description provided for @syncRecalculateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Recalculate Tax Status'**
  String get syncRecalculateTooltip;

  /// No description provided for @yourPoliciesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Policies'**
  String get yourPoliciesTitle;

  /// No description provided for @pendingCalcStatus.
  ///
  /// In en, this message translates to:
  /// **'Pending Calculation'**
  String get pendingCalcStatus;

  /// No description provided for @installmentsEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Installments Enabled'**
  String get installmentsEnabledLabel;

  /// No description provided for @taxableStatus.
  ///
  /// In en, this message translates to:
  /// **'Taxable'**
  String get taxableStatus;

  /// No description provided for @exemptStatus.
  ///
  /// In en, this message translates to:
  /// **'Exempt'**
  String get exemptStatus;

  /// No description provided for @populateIncomeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Populate Taxable Income'**
  String get populateIncomeTooltip;

  /// No description provided for @populateTaxableIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Populate Taxable Income'**
  String get populateTaxableIncomeTitle;

  /// No description provided for @taxHeadLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax Head'**
  String get taxHeadLabel;

  /// No description provided for @otherIncomeHead.
  ///
  /// In en, this message translates to:
  /// **'Other Income'**
  String get otherIncomeHead;

  /// No description provided for @assetCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Asset Category'**
  String get assetCategoryLabel;

  /// No description provided for @saleMaturityAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Sale / Maturity Amount'**
  String get saleMaturityAmountLabel;

  /// No description provided for @costOfAcquisitionLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost of Acquisition'**
  String get costOfAcquisitionLabel;

  /// No description provided for @isLongTermLabel.
  ///
  /// In en, this message translates to:
  /// **'Is Long Term?'**
  String get isLongTermLabel;

  /// No description provided for @incomeAlreadyAddedNote.
  ///
  /// In en, this message translates to:
  /// **'Warning: Income for this year may already be present in Dashboard.'**
  String get incomeAlreadyAddedNote;

  /// No description provided for @incomeAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Income for FY {year}-{nextYear} added to Dashboard targets.'**
  String incomeAddedSuccess(int year, int nextYear);

  /// No description provided for @selectMonthsAction.
  ///
  /// In en, this message translates to:
  /// **'Select Payout Months'**
  String get selectMonthsAction;

  /// No description provided for @transactionDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Transaction Date'**
  String get transactionDateLabel;

  /// No description provided for @addEntryAction.
  ///
  /// In en, this message translates to:
  /// **'Add Entry'**
  String get addEntryAction;

  /// Ad-hoc Exemptions label
  ///
  /// In en, this message translates to:
  /// **'Less: Ad-hoc Exemptions'**
  String get adhocExemptionsLabel;

  /// No description provided for @clearCategoryDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear {category} Data?'**
  String clearCategoryDataTitle(String category);

  /// No description provided for @editDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Details'**
  String get editDetailsAction;

  /// No description provided for @syncDataAction.
  ///
  /// In en, this message translates to:
  /// **'Sync Data'**
  String get syncDataAction;

  /// No description provided for @taxConfigAction.
  ///
  /// In en, this message translates to:
  /// **'Tax Config'**
  String get taxConfigAction;

  /// No description provided for @syncTaxDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Tax Data'**
  String get syncTaxDataTitle;

  /// No description provided for @lastSyncedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {date}'**
  String lastSyncedLabel(String date);

  /// No description provided for @syncPeriodYtdLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync Period (YTD)'**
  String get syncPeriodYtdLabel;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @toLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toLabel;

  /// No description provided for @syncNowAction.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNowAction;

  /// No description provided for @smartSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Sync (Merge)'**
  String get smartSyncTitle;

  /// No description provided for @smartSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Updates existing data without overwriting manual changes.'**
  String get smartSyncSubtitle;

  /// No description provided for @forceResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Force Reset (Overwrite)'**
  String get forceResetTitle;

  /// No description provided for @forceResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Overwrites all current fiscal year data with fresh synced data.'**
  String get forceResetSubtitle;

  /// No description provided for @interestRateShort.
  ///
  /// In en, this message translates to:
  /// **'{rate}% Int.'**
  String interestRateShort(String rate);

  /// No description provided for @addLoanTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Loan'**
  String get addLoanTitle;

  /// No description provided for @loanNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Loan Name'**
  String get loanNameLabel;

  /// No description provided for @loanAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Initial Principal'**
  String get loanAmountLabel;

  /// No description provided for @loanTenureLabel.
  ///
  /// In en, this message translates to:
  /// **'Tenure (Months)'**
  String get loanTenureLabel;

  /// No description provided for @loanStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get loanStartDateLabel;

  /// No description provided for @loanTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Loan Type'**
  String get loanTypeLabel;

  /// No description provided for @emiLabel.
  ///
  /// In en, this message translates to:
  /// **'EMI'**
  String get emiLabel;

  /// No description provided for @personalLoan.
  ///
  /// In en, this message translates to:
  /// **'Personal Loan'**
  String get personalLoan;

  /// No description provided for @homeLoan.
  ///
  /// In en, this message translates to:
  /// **'Home Loan'**
  String get homeLoan;

  /// No description provided for @carLoan.
  ///
  /// In en, this message translates to:
  /// **'Car Loan'**
  String get carLoan;

  /// No description provided for @goldLoan.
  ///
  /// In en, this message translates to:
  /// **'Gold Loan'**
  String get goldLoan;

  /// No description provided for @educationLoan.
  ///
  /// In en, this message translates to:
  /// **'Education Loan'**
  String get educationLoan;

  /// No description provided for @businessLoan.
  ///
  /// In en, this message translates to:
  /// **'Business Loan'**
  String get businessLoan;

  /// No description provided for @otherLoan.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherLoan;

  /// No description provided for @noActiveLoans.
  ///
  /// In en, this message translates to:
  /// **'No active loans found.'**
  String get noActiveLoans;

  /// No description provided for @remainingPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Remaining Principal'**
  String get remainingPrincipal;

  /// No description provided for @nextEmiDate.
  ///
  /// In en, this message translates to:
  /// **'Next EMI'**
  String get nextEmiDate;

  /// Label for amount paid input
  ///
  /// In en, this message translates to:
  /// **'Amount Paid'**
  String get amountPaidLabel;

  /// No description provided for @paymentDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Date'**
  String get paymentDateLabel;

  /// No description provided for @principalComponent.
  ///
  /// In en, this message translates to:
  /// **'Principal Component'**
  String get principalComponent;

  /// No description provided for @interestComponent.
  ///
  /// In en, this message translates to:
  /// **'Interest Component'**
  String get interestComponent;

  /// No description provided for @renameLoanTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Loan'**
  String get renameLoanTitle;

  /// No description provided for @calculateRateFromEmi.
  ///
  /// In en, this message translates to:
  /// **'Calculate Rate from EMI?'**
  String get calculateRateFromEmi;

  /// No description provided for @interestRateAnnual.
  ///
  /// In en, this message translates to:
  /// **'Interest Rate (Annual)'**
  String get interestRateAnnual;

  /// No description provided for @monthlyEmi.
  ///
  /// In en, this message translates to:
  /// **'Monthly EMI'**
  String get monthlyEmi;

  /// No description provided for @emiDay.
  ///
  /// In en, this message translates to:
  /// **'EMI Day'**
  String get emiDay;

  /// No description provided for @defaultPaymentAccount.
  ///
  /// In en, this message translates to:
  /// **'Default Payment Account (Optional)'**
  String get defaultPaymentAccount;

  /// No description provided for @selectSavingsAccountHelper.
  ///
  /// In en, this message translates to:
  /// **'Select a savings account for EMI payments'**
  String get selectSavingsAccountHelper;

  /// No description provided for @maturityDate.
  ///
  /// In en, this message translates to:
  /// **'Maturity Date'**
  String get maturityDate;

  /// No description provided for @estimatedEmi.
  ///
  /// In en, this message translates to:
  /// **'Estimated EMI'**
  String get estimatedEmi;

  /// No description provided for @totalInterestLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Interest: {amount}'**
  String totalInterestLabel(String amount);

  /// No description provided for @projectedInterestSimple.
  ///
  /// In en, this message translates to:
  /// **'Projected Interest (Simple)'**
  String get projectedInterestSimple;

  /// No description provided for @interestPayableMaturity.
  ///
  /// In en, this message translates to:
  /// **'Interest payable at maturity or renewal'**
  String get interestPayableMaturity;

  /// No description provided for @availLabel.
  ///
  /// In en, this message translates to:
  /// **'Avail: {amount}'**
  String availLabel(String amount);

  /// No description provided for @balLabel.
  ///
  /// In en, this message translates to:
  /// **'Bal: {amount}'**
  String balLabel(String amount);

  /// No description provided for @topUpLoanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Top-up Loan'**
  String get topUpLoanTooltip;

  /// No description provided for @moreOptionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptionsTooltip;

  /// No description provided for @renameLoanAction.
  ///
  /// In en, this message translates to:
  /// **'Rename Loan'**
  String get renameLoanAction;

  /// No description provided for @deleteLoanAction.
  ///
  /// In en, this message translates to:
  /// **'Delete Loan'**
  String get deleteLoanAction;

  /// No description provided for @amortizationTab.
  ///
  /// In en, this message translates to:
  /// **'Amortization'**
  String get amortizationTab;

  /// No description provided for @simulatorTab.
  ///
  /// In en, this message translates to:
  /// **'Simulator'**
  String get simulatorTab;

  /// No description provided for @ledgerTab.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ledgerTab;

  /// No description provided for @payAction.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get payAction;

  /// No description provided for @renewAction.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get renewAction;

  /// No description provided for @partPayAction.
  ///
  /// In en, this message translates to:
  /// **'Part Pay'**
  String get partPayAction;

  /// No description provided for @rateAction.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateAction;

  /// No description provided for @closeAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeAction;

  /// No description provided for @amortizationCurveTitle.
  ///
  /// In en, this message translates to:
  /// **'Amortization Curve (Yearly)'**
  String get amortizationCurveTitle;

  /// No description provided for @totalInterestPayableLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Interest Payable: {amount}  •  '**
  String totalInterestPayableLabel(String amount);

  /// No description provided for @estimatedYearlyInterestLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated Yearly Interest: {amount}'**
  String estimatedYearlyInterestLabel(String amount);

  /// No description provided for @extraPaymentAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Extra Payment Amount'**
  String get extraPaymentAmountLabel;

  /// No description provided for @reduceTenureLabel.
  ///
  /// In en, this message translates to:
  /// **'Reduce Tenure'**
  String get reduceTenureLabel;

  /// No description provided for @reduceEmiLabel.
  ///
  /// In en, this message translates to:
  /// **'Reduce EMI'**
  String get reduceEmiLabel;

  /// No description provided for @newTenureLabel.
  ///
  /// In en, this message translates to:
  /// **'New Tenure'**
  String get newTenureLabel;

  /// No description provided for @newEmiLabel.
  ///
  /// In en, this message translates to:
  /// **'New EMI'**
  String get newEmiLabel;

  /// No description provided for @interestSavedLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest Saved'**
  String get interestSavedLabel;

  /// No description provided for @tenureReducedLabel.
  ///
  /// In en, this message translates to:
  /// **'Tenure Reduced'**
  String get tenureReducedLabel;

  /// No description provided for @recordedPaymentsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Recorded {count} payments successfully.'**
  String recordedPaymentsSuccess(int count);

  /// No description provided for @deleteLoanConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Loan?'**
  String get deleteLoanConfirmTitle;

  /// No description provided for @deleteLoanConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove the loan tracking. Existing transactions will NOT be deleted.'**
  String get deleteLoanConfirmMessage;

  /// No description provided for @bulkRecordPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk Record Payments'**
  String get bulkRecordPaymentsTitle;

  /// No description provided for @monthsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} months'**
  String monthsCount(int count);

  /// No description provided for @outstandingPrincipalLabel.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Principal'**
  String get outstandingPrincipalLabel;

  /// No description provided for @bulkPayAction.
  ///
  /// In en, this message translates to:
  /// **'Bulk Pay'**
  String get bulkPayAction;

  /// No description provided for @interestRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest Rate (%)'**
  String get interestRateLabel;

  /// No description provided for @daysAccruedLabel.
  ///
  /// In en, this message translates to:
  /// **'Days Accrued'**
  String get daysAccruedLabel;

  /// No description provided for @estAccruedInterestLabel.
  ///
  /// In en, this message translates to:
  /// **'Est. Accrued Interest (To Date)'**
  String get estAccruedInterestLabel;

  /// No description provided for @maturityLabel.
  ///
  /// In en, this message translates to:
  /// **'Maturity: {date}'**
  String maturityLabel(String date);

  /// No description provided for @addToSystemCalendarTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to System Calendar'**
  String get addToSystemCalendarTooltip;

  /// No description provided for @loanMaturityEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Maturity: {name}'**
  String loanMaturityEventTitle(String name);

  /// No description provided for @loanMaturityEventDescription.
  ///
  /// In en, this message translates to:
  /// **'Maturity date for Gold Loan: {name}. Principal and Interest due.'**
  String loanMaturityEventDescription(String name);

  /// No description provided for @rateLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateLabel;

  /// No description provided for @paidLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidLabel;

  /// No description provided for @leftLabel.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get leftLabel;

  /// No description provided for @percentPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Paid'**
  String percentPaidLabel(String percent);

  /// No description provided for @closureProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Closure Progress'**
  String get closureProgressLabel;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String daysCount(int count);

  /// No description provided for @monthsShort.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String monthsShort(int count);

  /// No description provided for @daysShort.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String daysShort(int count);

  /// No description provided for @payInterestAndRenewTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay Interest & Renew'**
  String get payInterestAndRenewTitle;

  /// No description provided for @payInterestAndRenewDescription.
  ///
  /// In en, this message translates to:
  /// **'Pay the interest due to renew the loan tenure or simply clear dues. Principal will NOT be reduced.'**
  String get payInterestAndRenewDescription;

  /// No description provided for @payAndRenewAction.
  ///
  /// In en, this message translates to:
  /// **'Pay & Renew'**
  String get payAndRenewAction;

  /// No description provided for @loanInterestTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Interest: {name}'**
  String loanInterestTitle(String name);

  /// No description provided for @closeGoldLoanTitle.
  ///
  /// In en, this message translates to:
  /// **'Close Gold Loan'**
  String get closeGoldLoanTitle;

  /// No description provided for @closeGoldLoanDescription.
  ///
  /// In en, this message translates to:
  /// **'Pay Principal ({principal}) + Interest ({interest}) to close this loan.'**
  String closeGoldLoanDescription(String principal, String interest);

  /// No description provided for @closeLoanAction.
  ///
  /// In en, this message translates to:
  /// **'Close Loan'**
  String get closeLoanAction;

  /// No description provided for @loanClosureTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Closure: {name}'**
  String loanClosureTitle(String name);

  /// No description provided for @paymentAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Amount'**
  String get paymentAmountLabel;

  /// No description provided for @dateEffectiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Date Effective'**
  String get dateEffectiveLabel;

  /// No description provided for @paidFromAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid From Account'**
  String get paidFromAccountLabel;

  /// No description provided for @noTransactionsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No transactions match the filters.'**
  String get noTransactionsMatchFilters;

  /// No description provided for @loanLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Ledger'**
  String get loanLedgerTitle;

  /// No description provided for @switchToExtendedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to Extended Numbers'**
  String get switchToExtendedTooltip;

  /// No description provided for @switchToCompactTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to Compact Numbers'**
  String get switchToCompactTooltip;

  /// No description provided for @filterByTypeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by Type'**
  String get filterByTypeTooltip;

  /// No description provided for @filterByDateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by Date'**
  String get filterByDateTooltip;

  /// No description provided for @clearFiltersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFiltersTooltip;

  /// No description provided for @emiPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'EMI Payment'**
  String get emiPaymentTitle;

  /// No description provided for @prepaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepayment'**
  String get prepaymentTitle;

  /// No description provided for @interestRateUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Interest Rate Updated'**
  String get interestRateUpdatedTitle;

  /// No description provided for @loanTopUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Top-up'**
  String get loanTopUpTitle;

  /// No description provided for @emiPaymentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prin: {principal} • Int: {interest}'**
  String emiPaymentSubtitle(String principal, String interest);

  /// No description provided for @prepaymentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Direct reduction of principal'**
  String get prepaymentSubtitle;

  /// No description provided for @newRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New Rate: {rate}%'**
  String newRateSubtitle(String rate);

  /// No description provided for @loanTopUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Increased principal amount'**
  String get loanTopUpSubtitle;

  /// No description provided for @balanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance: '**
  String get balanceLabel;

  /// No description provided for @deleteEntryConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Entry?'**
  String get deleteEntryConfirmTitle;

  /// No description provided for @deleteEntryConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Deleting this will attempt to reverse the principal impact, but won\'t perfectly recalculate interest history.'**
  String get deleteEntryConfirmMessage;

  /// No description provided for @areYouSureLabel.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSureLabel;

  /// No description provided for @partPrincipalPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Part Principal Payment'**
  String get partPrincipalPaymentTitle;

  /// No description provided for @partPaymentDescription.
  ///
  /// In en, this message translates to:
  /// **'Reduce the outstanding principal. Interest on the reduced amount will decrease from the payment date.'**
  String get partPaymentDescription;

  /// No description provided for @payPrincipalAction.
  ///
  /// In en, this message translates to:
  /// **'Pay Principal'**
  String get payPrincipalAction;

  /// No description provided for @partPaymentSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Part principal payment successful.'**
  String get partPaymentSuccessMessage;

  /// No description provided for @loanPartPayTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Part Pay: {name}'**
  String loanPartPayTitle(String name);

  /// No description provided for @recalculateLoanTitle.
  ///
  /// In en, this message translates to:
  /// **'Recalculate Loan'**
  String get recalculateLoanTitle;

  /// No description provided for @currentOutstandingLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Outstanding: {amount}'**
  String currentOutstandingLabel(String amount);

  /// No description provided for @newEmiAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'New EMI Amount'**
  String get newEmiAmountLabel;

  /// No description provided for @calculateInterestRateOption.
  ///
  /// In en, this message translates to:
  /// **'Calculate Interest Rate?'**
  String get calculateInterestRateOption;

  /// No description provided for @calculateInterestRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If checked, Tenure will be used to find the new Rate. Otherwise, Tenure is recalculated.'**
  String get calculateInterestRateSubtitle;

  /// No description provided for @targetTenureMonthsLabel.
  ///
  /// In en, this message translates to:
  /// **'Target Tenure (Months)'**
  String get targetTenureMonthsLabel;

  /// No description provided for @loanTopUpDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Top-up'**
  String get loanTopUpDialogTitle;

  /// No description provided for @borrowMoreDescription.
  ///
  /// In en, this message translates to:
  /// **'Borrow more money on this loan.'**
  String get borrowMoreDescription;

  /// No description provided for @topUpAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Top-up Amount'**
  String get topUpAmountLabel;

  /// No description provided for @creditToAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit to Account'**
  String get creditToAccountLabel;

  /// No description provided for @recalculationModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Recalculation Mode:'**
  String get recalculationModeLabel;

  /// No description provided for @adjustEmiOption.
  ///
  /// In en, this message translates to:
  /// **'Adjust EMI'**
  String get adjustEmiOption;

  /// No description provided for @adjustEmiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep Tenure constant. EMI will increase.'**
  String get adjustEmiSubtitle;

  /// No description provided for @adjustTenureOption.
  ///
  /// In en, this message translates to:
  /// **'Adjust Tenure'**
  String get adjustTenureOption;

  /// No description provided for @adjustTenureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep EMI constant. Tenure will increase.'**
  String get adjustTenureSubtitle;

  /// No description provided for @borrowAction.
  ///
  /// In en, this message translates to:
  /// **'Borrow'**
  String get borrowAction;

  /// No description provided for @loanTopUpSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Loan topped up successfully.'**
  String get loanTopUpSuccessMessage;

  /// No description provided for @updateInterestRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Interest Rate'**
  String get updateInterestRateTitle;

  /// No description provided for @enterNewRateDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter new annual interest rate.'**
  String get enterNewRateDescription;

  /// No description provided for @newAnnualRateLabel.
  ///
  /// In en, this message translates to:
  /// **'New Annual Rate (%)'**
  String get newAnnualRateLabel;

  /// No description provided for @adjustEmiSubtitleLong.
  ///
  /// In en, this message translates to:
  /// **'Keep Tenure constant.\nMonthly payment will change.'**
  String get adjustEmiSubtitleLong;

  /// No description provided for @adjustTenureSubtitleLong.
  ///
  /// In en, this message translates to:
  /// **'Keep EMI constant.\nLoan duration will change.'**
  String get adjustTenureSubtitleLong;

  /// Success message after updating interest rate
  ///
  /// In en, this message translates to:
  /// **'Rate updated and loan recalibrated.'**
  String get rateUpdatedSuccessMessage;

  /// Title for Lending & Borrowing screen
  ///
  /// In en, this message translates to:
  /// **'Lending & Borrowing'**
  String get lendingBorrowingTitle;

  /// Label for total lent summary card
  ///
  /// In en, this message translates to:
  /// **'Total Lent'**
  String get totalLentLabel;

  /// Label for total borrowed summary card
  ///
  /// In en, this message translates to:
  /// **'Total Borrowed'**
  String get totalBorrowedLabel;

  /// Empty state message for lending records
  ///
  /// In en, this message translates to:
  /// **'No records found.'**
  String get noLendingRecords;

  /// Action text to add a lending record
  ///
  /// In en, this message translates to:
  /// **'Add Record'**
  String get addRecordAction;

  /// Title for delete lending record dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Record?'**
  String get deleteLendingRecordTitle;

  /// Confirmation message for deleting a lending record
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this record? This action cannot be undone.'**
  String get deleteLendingRecordConfirmation;

  /// Subtitle showing paid amount and transaction count
  ///
  /// In en, this message translates to:
  /// **'Paid: {amount} ({count} txn)'**
  String paidSubtitle(String amount, int count);

  /// Subtitle showing closing date
  ///
  /// In en, this message translates to:
  /// **'Closed on {date}'**
  String closedOnSubtitle(String date);

  /// Trailing text showing remaining balance
  ///
  /// In en, this message translates to:
  /// **'Bal: {amount}'**
  String balanceTrailing(String amount);

  /// Action text to record a payment
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPaymentAction;

  /// Action text to view payment history
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistoryAction;

  /// Action text to settle the full amount
  ///
  /// In en, this message translates to:
  /// **'Settle Full'**
  String get settleFullAction;

  /// Title for marking a record as settled dialog
  ///
  /// In en, this message translates to:
  /// **'Mark as Settled?'**
  String get markAsSettledTitle;

  /// Confirmation message for settling a lent record
  ///
  /// In en, this message translates to:
  /// **'Has the amount of {amount} been received back from {person}?'**
  String settleLentConfirmation(String amount, String person);

  /// Confirmation message for settling a borrowed record
  ///
  /// In en, this message translates to:
  /// **'Has the amount of {amount} been paid back to {person}?'**
  String settleBorrowedConfirmation(String amount, String person);

  /// Action text to confirm settlement
  ///
  /// In en, this message translates to:
  /// **'Yes, Settle'**
  String get yesSettleAction;

  /// Label showing remaining amount
  ///
  /// In en, this message translates to:
  /// **'Remaining: {amount}'**
  String remainingLabel(String amount);

  /// Action text to save a payment
  ///
  /// In en, this message translates to:
  /// **'Save Payment'**
  String get savePaymentAction;

  /// Title for adding a lending record
  ///
  /// In en, this message translates to:
  /// **'Add Lending Record'**
  String get addLendingRecordTitle;

  /// Title for editing a lending record
  ///
  /// In en, this message translates to:
  /// **'Edit Lending Record'**
  String get editLendingRecordTitle;

  /// Label for lent lending type
  ///
  /// In en, this message translates to:
  /// **'Lent (Given)'**
  String get lentLabel;

  /// Label for borrowed lending type
  ///
  /// In en, this message translates to:
  /// **'Borrowed (Taken)'**
  String get borrowedLabel;

  /// Label for person name input
  ///
  /// In en, this message translates to:
  /// **'Person Name'**
  String get personNameLabel;

  /// Error message for missing person name
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get enterNameError;

  /// Simplified amount label
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabelSimplified;

  /// Error message for missing amount
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmountError;

  /// Error message for invalid numeric input
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumberError;

  /// Label for reason/description input
  ///
  /// In en, this message translates to:
  /// **'Reason / Description'**
  String get reasonDescriptionLabel;

  /// Option to mark a record as closed
  ///
  /// In en, this message translates to:
  /// **'Mark as Closed / SETTLED'**
  String get markAsClosedOption;

  /// Button text to add a record
  ///
  /// In en, this message translates to:
  /// **'Add Record'**
  String get addRecordButton;

  /// Button text to edit a record
  ///
  /// In en, this message translates to:
  /// **'Edit Record'**
  String get editRecordButton;

  /// Empty state message for payment history
  ///
  /// In en, this message translates to:
  /// **'No payments recorded.'**
  String get noPaymentsRecorded;

  /// Label for total amount summary item
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmountLabel;

  /// Label for remaining amount summary item
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingSummaryLabel;

  /// Title for delete payment dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Payment?'**
  String get deletePaymentTitle;

  /// Confirmation message for deleting a payment
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove this payment record.'**
  String get deletePaymentConfirmation;

  /// Message shown when a payment is deleted
  ///
  /// In en, this message translates to:
  /// **'Payment deleted'**
  String get paymentDeletedMessage;

  /// Title for the Holiday Manager screen
  ///
  /// In en, this message translates to:
  /// **'Holiday Manager'**
  String get holidayManagerTitle;

  /// Information text in Holiday Manager
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions can be configured to avoid these dates by scheduling them a day earlier.'**
  String get holidayInfoText;

  /// Message when no holidays are added
  ///
  /// In en, this message translates to:
  /// **'No holidays added yet.'**
  String get noHolidaysAdded;

  /// Title for the Recurring Payments screen
  ///
  /// In en, this message translates to:
  /// **'Recurring Payments'**
  String get recurringPaymentsTitle;

  /// Message when no recurring payments are set up
  ///
  /// In en, this message translates to:
  /// **'No recurring payments set up.'**
  String get noRecurringPayments;

  /// Label for next execution date
  ///
  /// In en, this message translates to:
  /// **'Next: {date}'**
  String nextExecutionLabel(String date);

  /// Tooltip for adding to calendar
  ///
  /// In en, this message translates to:
  /// **'Add to System Calendar'**
  String get addToCalendarTooltip;

  /// Description for recurring calendar event
  ///
  /// In en, this message translates to:
  /// **'Recurring payment: {title} for {amount}'**
  String recurringEventDescription(String title, String amount);

  /// Label for every weekend schedule
  ///
  /// In en, this message translates to:
  /// **'Every Weekend (Sat/Sun)'**
  String get everyWeekendLabel;

  /// Label for last weekend schedule
  ///
  /// In en, this message translates to:
  /// **'Last Weekend of Month'**
  String get lastWeekendLabel;

  /// Label for specific weekday schedule
  ///
  /// In en, this message translates to:
  /// **'Every {weekday}'**
  String everyWeekdayLabel(String weekday);

  /// Label for last day of month schedule
  ///
  /// In en, this message translates to:
  /// **'Last Day of Month'**
  String get lastDayOfMonthLabel;

  /// Label for last working day schedule
  ///
  /// In en, this message translates to:
  /// **'Last Working Day'**
  String get lastWorkingDayLabel;

  /// Label for first working day schedule
  ///
  /// In en, this message translates to:
  /// **'First Working Day'**
  String get firstWorkingDayLabel;

  /// Suffix for holiday adjustment
  ///
  /// In en, this message translates to:
  /// **' (Adj. for Holidays)'**
  String get adjForHolidaysLabel;

  /// Title for delete recurring rule dialog
  ///
  /// In en, this message translates to:
  /// **'Delete recurring rule?'**
  String get deleteRecurringTitle;

  /// Confirmation message for deleting recurring rule
  ///
  /// In en, this message translates to:
  /// **'This will stop automatic payments for \"{title}\". Past transactions will NOT be deleted.'**
  String deleteRecurringConfirmation(String title);

  /// Title for editing recurring amount dialog
  ///
  /// In en, this message translates to:
  /// **'Edit Recurring Amount'**
  String get editRecurringAmountTitle;

  /// Label for new amount field
  ///
  /// In en, this message translates to:
  /// **'New Amount'**
  String get newAmountLabel;

  /// Title for the Recycle Bin screen
  ///
  /// In en, this message translates to:
  /// **'Recycle Bin'**
  String get recycleBinTitle;

  /// Message when recycle bin is empty
  ///
  /// In en, this message translates to:
  /// **'Recycle Bin is empty'**
  String get recycleBinEmptyMessage;

  /// Tooltip for restoring an item
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreTooltip;

  /// Tooltip for permanently deleting an item
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deletePermanentlyTooltip;

  /// Title for the Reminders screen
  ///
  /// In en, this message translates to:
  /// **'Reminders & Notifications'**
  String get remindersTitle;

  /// Section title for upcoming loan EMIs
  ///
  /// In en, this message translates to:
  /// **'Upcoming Loan EMIs'**
  String get upcomingLoanEMIs;

  /// Section title for credit card bills
  ///
  /// In en, this message translates to:
  /// **'Credit Card Bills'**
  String get creditCardBills;

  /// Status label for paid item
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidStatus;

  /// Status label for partially paid item
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get partialStatus;

  /// Status label for overdue item
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueStatus;

  /// Status label for upcoming item
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingStatus;

  /// Message when no loan EMIs are due
  ///
  /// In en, this message translates to:
  /// **'No EMIs due within 7 days.'**
  String get noLoanEMIsDue;

  /// Label for due date
  ///
  /// In en, this message translates to:
  /// **'Due on {date}'**
  String dueOnLabel(String date);

  /// Label for next bill date
  ///
  /// In en, this message translates to:
  /// **'Next Bill: {date}'**
  String nextBillLabel(String date);

  /// Button to add an event to calendar
  ///
  /// In en, this message translates to:
  /// **'Add to Calendar'**
  String get addToCalendarAction;

  /// Title for EMI due calendar event
  ///
  /// In en, this message translates to:
  /// **'EMI Due: {name}'**
  String emiDueCalendarTitle(String name);

  /// Description for EMI due calendar event
  ///
  /// In en, this message translates to:
  /// **'Payment for {name} due.'**
  String emiDueCalendarDescription(String name);

  /// Message for loan first EMI date
  ///
  /// In en, this message translates to:
  /// **'First EMI starts on {date}'**
  String firstEMIStartsOn(String date);

  /// Label for loan waiting to start
  ///
  /// In en, this message translates to:
  /// **'Wait for Start'**
  String get waitForStartLabel;

  /// Button to pay a bill now
  ///
  /// In en, this message translates to:
  /// **'PAY NOW'**
  String get payNowAction;

  /// Message when no CC bills are due
  ///
  /// In en, this message translates to:
  /// **'No pending credit card bills.'**
  String get noCCBillsDue;

  /// Message when no recurring payments are due
  ///
  /// In en, this message translates to:
  /// **'No due recurring payments.'**
  String get noRecurringPaymentsDue;

  /// Label for monthly frequency
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get frequencyMonthly;

  /// Label for weekly frequency
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get frequencyWeekly;

  /// No description provided for @frequencyOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get frequencyOther;

  /// No description provided for @selectStoppedMonthsAction.
  ///
  /// In en, this message translates to:
  /// **'Select Stopped Months'**
  String get selectStoppedMonthsAction;

  /// No description provided for @presumptiveProfitHelper.
  ///
  /// In en, this message translates to:
  /// **'Presumptive profit based on turnover'**
  String get presumptiveProfitHelper;

  /// No description provided for @taxationTypeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Section 44AD/ADA allows presumptive taxation. Consult a professional for eligibility.'**
  String get taxationTypeTooltip;

  /// No description provided for @equitySharesTooltip.
  ///
  /// In en, this message translates to:
  /// **'LTCG on equity shares above 1.25L is taxed at 12.5%.'**
  String get equitySharesTooltip;

  /// No description provided for @reinvestmentPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Reinvestment Pending'**
  String get reinvestmentPendingLabel;

  /// No description provided for @reinvestedDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reinvested {amount} via {type}'**
  String reinvestedDetailsLabel(String amount, String type);

  /// No description provided for @otherIncomeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Fixed income (No loss possible) like bank interest, chit fund profit, etc. Do not include gifts here.'**
  String get otherIncomeTooltip;

  /// No description provided for @stcgLabel.
  ///
  /// In en, this message translates to:
  /// **'STCG'**
  String get stcgLabel;

  /// No description provided for @ltcgLabel.
  ///
  /// In en, this message translates to:
  /// **'LTCG'**
  String get ltcgLabel;

  /// No description provided for @gainLabel.
  ///
  /// In en, this message translates to:
  /// **'Gain'**
  String get gainLabel;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @addIncomeAction.
  ///
  /// In en, this message translates to:
  /// **'Add Income'**
  String get addIncomeAction;

  /// No description provided for @noneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneLabel;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @updatedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Upd'**
  String get updatedPrefix;

  /// No description provided for @transactionPrefix.
  ///
  /// In en, this message translates to:
  /// **'Txn'**
  String get transactionPrefix;

  /// No description provided for @noCapitalGainsFoundNote.
  ///
  /// In en, this message translates to:
  /// **'No capital gains found for this year.'**
  String get noCapitalGainsFoundNote;

  /// No description provided for @policyLabel.
  ///
  /// In en, this message translates to:
  /// **'Policy'**
  String get policyLabel;

  /// No description provided for @taxableGainProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxable Gain / Profit'**
  String get taxableGainProfitLabel;

  /// No description provided for @insurancePrefix.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get insurancePrefix;

  /// No description provided for @taxConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Tax Configuration'**
  String get taxConfigurationTitle;

  /// No description provided for @copyPreviousYearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy Rules from Previous Year'**
  String get copyPreviousYearTooltip;

  /// No description provided for @restoreDefaultsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Restore System Defaults'**
  String get restoreDefaultsTooltip;

  /// Tax Jurisdiction label
  ///
  /// In en, this message translates to:
  /// **'Tax Jurisdiction'**
  String get taxJurisdictionLabel;

  /// No description provided for @countryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Country Name'**
  String get countryNameLabel;

  /// No description provided for @fyStartMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Financial Year Start Month'**
  String get fyStartMonthLabel;

  /// No description provided for @fyStartMonthHelper.
  ///
  /// In en, this message translates to:
  /// **'Determines the start of the financial year (e.g. April 1st). Affects tax calculations.'**
  String get fyStartMonthHelper;

  /// No description provided for @taxRatesSlabsHeader.
  ///
  /// In en, this message translates to:
  /// **'Tax Rates & Slabs'**
  String get taxRatesSlabsHeader;

  /// No description provided for @enableRebateLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Rebate'**
  String get enableRebateLabel;

  /// No description provided for @rebateLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Rebate Limit'**
  String get rebateLimitLabel;

  /// No description provided for @enableCessLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Health & Edu Cess'**
  String get enableCessLabel;

  /// No description provided for @cessRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Cess Rate (%)'**
  String get cessRateLabel;

  /// No description provided for @enableCashGiftExemptLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Cash Gift Exemption'**
  String get enableCashGiftExemptLabel;

  /// No description provided for @cashGiftExemptLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash Gift Exemption Limit'**
  String get cashGiftExemptLimitLabel;

  /// No description provided for @selectTaxableGiftTypesLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Taxable Gift Types:'**
  String get selectTaxableGiftTypesLabel;

  /// No description provided for @incomeSlabsLabel.
  ///
  /// In en, this message translates to:
  /// **'Income Slabs'**
  String get incomeSlabsLabel;

  /// No description provided for @unlimitedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimitedLabel;

  /// No description provided for @addMappingAction.
  ///
  /// In en, this message translates to:
  /// **'Add Mapping'**
  String get addMappingAction;

  /// No description provided for @noMappingsFoundNote.
  ///
  /// In en, this message translates to:
  /// **'No mappings defined.'**
  String get noMappingsFoundNote;

  /// No description provided for @mappingsInstructionNote.
  ///
  /// In en, this message translates to:
  /// **'Map Transaction Tags or Descriptions to Tax Heads for auto-assignment.'**
  String get mappingsInstructionNote;

  /// No description provided for @standardDeductionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Standard Deductions'**
  String get standardDeductionsHeader;

  /// No description provided for @stdDedSalaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Standard Deduction (Salary)'**
  String get stdDedSalaryLabel;

  /// No description provided for @retirementExemptionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Retirement Exemptions'**
  String get retirementExemptionsHeader;

  /// No description provided for @enableRetirementExemptLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Retirement / Resignation Exemptions'**
  String get enableRetirementExemptLabel;

  /// No description provided for @leaveEncashLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave Encashment Limit'**
  String get leaveEncashLimitLabel;

  /// No description provided for @employerGiftsHeader.
  ///
  /// In en, this message translates to:
  /// **'Employer Gifts'**
  String get employerGiftsHeader;

  /// No description provided for @giftExemptLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Gift Exemption Limit'**
  String get giftExemptLimitLabel;

  /// No description provided for @presumptiveIncomeHeader.
  ///
  /// In en, this message translates to:
  /// **'Presumptive Income'**
  String get presumptiveIncomeHeader;

  /// No description provided for @enableBusinessExemptLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Business exemption'**
  String get enableBusinessExemptLabel;

  /// No description provided for @housePropConfigHeader.
  ///
  /// In en, this message translates to:
  /// **'House Property Configuration'**
  String get housePropConfigHeader;

  /// No description provided for @capGainsRatesHeader.
  ///
  /// In en, this message translates to:
  /// **'Capital Gains Rates'**
  String get capGainsRatesHeader;

  /// No description provided for @enableSpecialCGRatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Special CG Rates'**
  String get enableSpecialCGRatesLabel;

  /// No description provided for @ltcgRateEquityLabel.
  ///
  /// In en, this message translates to:
  /// **'LTCG Rate (Equity) %'**
  String get ltcgRateEquityLabel;

  /// No description provided for @stcgRateEquityLabel.
  ///
  /// In en, this message translates to:
  /// **'STCG Rate (Equity) %'**
  String get stcgRateEquityLabel;

  /// No description provided for @stdExemptLTCGLabel.
  ///
  /// In en, this message translates to:
  /// **'Standard Exemption (LTCG)'**
  String get stdExemptLTCGLabel;

  /// No description provided for @reinvestmentRulesHeader.
  ///
  /// In en, this message translates to:
  /// **'Reinvestment Rules'**
  String get reinvestmentRulesHeader;

  /// No description provided for @maxCGReinvestLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Capital Gain Reinvest Limit'**
  String get maxCGReinvestLimitLabel;

  /// No description provided for @agriIncomeConfigHeader.
  ///
  /// In en, this message translates to:
  /// **'Agriculture Income Configuration'**
  String get agriIncomeConfigHeader;

  /// No description provided for @enablePartialIntegrationLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Partial Integration'**
  String get enablePartialIntegrationLabel;

  /// No description provided for @partialIntegrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Determines tax using partial integration method'**
  String get partialIntegrationSubtitle;

  /// No description provided for @agriThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Agriculture Income Threshold'**
  String get agriThresholdLabel;

  /// No description provided for @customGeneralExemptionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Custom General Exemptions'**
  String get customGeneralExemptionsHeader;

  /// No description provided for @addCustomExemptionAction.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Exemption'**
  String get addCustomExemptionAction;

  /// No description provided for @advanceTaxConfigHeader.
  ///
  /// In en, this message translates to:
  /// **'Advance Tax Configurations'**
  String get advanceTaxConfigHeader;

  /// No description provided for @enableAdvanceTaxInterestLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Advance Tax Interest Calculation'**
  String get enableAdvanceTaxInterestLabel;

  /// No description provided for @interestTillPaymentDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest till Payment Date'**
  String get interestTillPaymentDateLabel;

  /// No description provided for @interestTillPaymentDateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If missed installment, calculate interest till payment date instead of next installment.'**
  String get interestTillPaymentDateSubtitle;

  /// No description provided for @includeCGInAdvanceTaxLabel.
  ///
  /// In en, this message translates to:
  /// **'Include Capital Gains in Advance Tax Base'**
  String get includeCGInAdvanceTaxLabel;

  /// No description provided for @includeCGInAdvanceTaxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If enabled, STCG/LTCG tax is included in required installments. If disabled, ONLY Normal Income (Salary, Business, etc.) is considered for installment matching.'**
  String get includeCGInAdvanceTaxSubtitle;

  /// No description provided for @interestRateMonthlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest Rate % (Monthly)'**
  String get interestRateMonthlyLabel;

  /// No description provided for @addCustomExemptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Exemption'**
  String get addCustomExemptionTitle;

  /// No description provided for @cliffExemptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If checked, income above limit becomes fully taxable.'**
  String get cliffExemptionSubtitle;

  /// Restore action label
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreAction;

  /// Success message when tax rules are saved
  ///
  /// In en, this message translates to:
  /// **'Tax Rules Saved Successfully'**
  String get taxRulesSavedStatus;

  /// Status message after resetting tax rules
  ///
  /// In en, this message translates to:
  /// **'Tax Rules reset for FY.'**
  String get taxRulesResetStatus;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDec;

  /// No description provided for @generalTab.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalTab;

  /// No description provided for @agriIncomeTab.
  ///
  /// In en, this message translates to:
  /// **'Agri Income'**
  String get agriIncomeTab;

  /// No description provided for @advanceTaxTab.
  ///
  /// In en, this message translates to:
  /// **'Advance Tax'**
  String get advanceTaxTab;

  /// No description provided for @mappingsTab.
  ///
  /// In en, this message translates to:
  /// **'Mappings'**
  String get mappingsTab;

  /// No description provided for @enableStdDedSalaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Standard Deduction'**
  String get enableStdDedSalaryLabel;

  /// No description provided for @retirementExemptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Gratuity & Leave Encashment'**
  String get retirementExemptSubtitle;

  /// No description provided for @gratuityLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Gratuity Exemption Limit'**
  String get gratuityLimitLabel;

  /// No description provided for @enableEmployerGiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Gifts from Employer Rule'**
  String get enableEmployerGiftLabel;

  /// No description provided for @employerGiftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exempt up to a limit'**
  String get employerGiftSubtitle;

  /// No description provided for @defaultGiftLimitHint.
  ///
  /// In en, this message translates to:
  /// **'Default: 5000'**
  String get defaultGiftLimitHint;

  /// No description provided for @businessExemptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Presumptive income for Businesses'**
  String get businessExemptSubtitle;

  /// No description provided for @limit44ADLabel.
  ///
  /// In en, this message translates to:
  /// **'Turnover Limit for 44AD'**
  String get limit44ADLabel;

  /// No description provided for @rate44ADLabel.
  ///
  /// In en, this message translates to:
  /// **'Presumptive Profit Rate (%)'**
  String get rate44ADLabel;

  /// No description provided for @enableProfessionalExemptLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Professional exemption'**
  String get enableProfessionalExemptLabel;

  /// No description provided for @professionalExemptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Presumptive income for Professionals'**
  String get professionalExemptSubtitle;

  /// No description provided for @limit44ADALabel.
  ///
  /// In en, this message translates to:
  /// **'Gross Receipts Limit for 44ADA'**
  String get limit44ADALabel;

  /// No description provided for @rate44ADALabel.
  ///
  /// In en, this message translates to:
  /// **'Presumptive Profit Rate (%)'**
  String get rate44ADALabel;

  /// No description provided for @cancelBtnLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelBtnLabel;

  /// No description provided for @enableStdDedHPLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable 30% Standard Deduction'**
  String get enableStdDedHPLabel;

  /// No description provided for @stdDedHPRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Standard Deduction Rate (%)'**
  String get stdDedHPRateLabel;

  /// No description provided for @stdDedHPSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Usually 30%'**
  String get stdDedHPSubtitle;

  /// No description provided for @enableHPMaxInterestLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Interest Deduction Cap'**
  String get enableHPMaxInterestLabel;

  /// No description provided for @hpMaxInterestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Limit max interest deduction for self-occupied'**
  String get hpMaxInterestSubtitle;

  /// No description provided for @maxHPInterestDedLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Interest Deduction (Self-Occ)'**
  String get maxHPInterestDedLabel;

  /// No description provided for @specialCGRatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use special rates instead of normal slabs'**
  String get specialCGRatesSubtitle;

  /// No description provided for @enableLTCGExemptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable LTCG Exemption'**
  String get enableLTCGExemptionLabel;

  /// No description provided for @enableReinvestmentExemptLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Reinvestment Exemptions'**
  String get enableReinvestmentExemptLabel;

  /// No description provided for @reinvestWindowLabel.
  ///
  /// In en, this message translates to:
  /// **'Reinvestment Window (Years)'**
  String get reinvestWindowLabel;

  /// No description provided for @agriIncomeMethodDesc.
  ///
  /// In en, this message translates to:
  /// **'Partial Integration Method determines tax on Agriculture Income if it exceeds the threshold and non-agri income exceeds basic exemption.'**
  String get agriIncomeMethodDesc;

  /// No description provided for @agriThresholdSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default: {amount}'**
  String agriThresholdSubtitle(String amount);

  /// No description provided for @agriBasicLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Agri Basic Exemption Limit'**
  String get agriBasicLimitLabel;

  /// No description provided for @agriBasicLimitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default: {amount} (Used for Partial Integration)'**
  String agriBasicLimitSubtitle(String amount);

  /// No description provided for @noCustomExemptionsMsg.
  ///
  /// In en, this message translates to:
  /// **'No custom exemptions defined.'**
  String get noCustomExemptionsMsg;

  /// No description provided for @advanceTaxConfigDesc.
  ///
  /// In en, this message translates to:
  /// **'Define the installment schedule, required percentages, and interest rates for advance tax calculations.'**
  String get advanceTaxConfigDesc;

  /// No description provided for @advanceTaxInterestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Calculate interest based on shortfalls'**
  String get advanceTaxInterestSubtitle;

  /// No description provided for @reminderDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder Days Before Deadline'**
  String get reminderDaysLabel;

  /// No description provided for @interestThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest Calculation Base Threshold (Fixed)'**
  String get interestThresholdLabel;

  /// No description provided for @interestThresholdSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Advance tax interest applies only if tax liability after TDS exceeds this amount.'**
  String get interestThresholdSubtitle;

  /// No description provided for @installmentScheduleHeader.
  ///
  /// In en, this message translates to:
  /// **'Installment Schedule'**
  String get installmentScheduleHeader;

  /// No description provided for @addInstallmentBtn.
  ///
  /// In en, this message translates to:
  /// **'Add Installment'**
  String get addInstallmentBtn;

  /// No description provided for @noInstallmentsMsg.
  ///
  /// In en, this message translates to:
  /// **'No installments configured.'**
  String get noInstallmentsMsg;

  /// No description provided for @installmentNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Installment #{number}'**
  String installmentNumberLabel(int number);

  /// No description provided for @limitFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get limitFieldLabel;

  /// No description provided for @isCliffExemptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Is Cliff Exemption?'**
  String get isCliffExemptionLabel;

  /// No description provided for @addBtnLabel.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addBtnLabel;

  /// No description provided for @incomeHeadLabel.
  ///
  /// In en, this message translates to:
  /// **'Income Head'**
  String get incomeHeadLabel;

  /// No description provided for @requiredPercentageLabel.
  ///
  /// In en, this message translates to:
  /// **'Required %'**
  String get requiredPercentageLabel;

  /// No description provided for @endMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'End Month'**
  String get endMonthLabel;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @editIndependentDeductionAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Independent Deduction'**
  String get editIndependentDeductionAction;

  /// No description provided for @editIndependentAllowanceAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Independent Allowance'**
  String get editIndependentAllowanceAction;

  /// No description provided for @payoutFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Payout Frequency'**
  String get payoutFrequencyLabel;

  /// No description provided for @payoutFrequencyTrimesterLabel.
  ///
  /// In en, this message translates to:
  /// **'Trimester (4 Months)'**
  String get payoutFrequencyTrimesterLabel;

  /// No description provided for @monthsSelectedCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} Months Selected'**
  String monthsSelectedCountLabel(String count);

  /// No description provided for @isPartialIrregularTitle.
  ///
  /// In en, this message translates to:
  /// **'Partial/Irregular Payouts'**
  String get isPartialIrregularTitle;

  /// No description provided for @isPartialIrregularSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter different amounts for each payout month'**
  String get isPartialIrregularSubtitle;

  /// No description provided for @enterAmountsForPayoutMonthsNote.
  ///
  /// In en, this message translates to:
  /// **'Enter amounts for selected payout months:'**
  String get enterAmountsForPayoutMonthsNote;

  /// No description provided for @unemploymentNoSalarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select months where no salary was received'**
  String get unemploymentNoSalarySubtitle;

  /// No description provided for @monthsStoppedCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} Months Stopped'**
  String monthsStoppedCountLabel(String count);

  /// No description provided for @annualFixedAllowancesHelperText.
  ///
  /// In en, this message translates to:
  /// **'HRA, Special, etc. (Fully Taxable)'**
  String get annualFixedAllowancesHelperText;

  /// No description provided for @maxAmountPerYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Max amount per year'**
  String get maxAmountPerYearLabel;

  /// No description provided for @totalAmountPerYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Total amount per year'**
  String get totalAmountPerYearLabel;

  /// No description provided for @partialPayoutTaxableFactorTitle.
  ///
  /// In en, this message translates to:
  /// **'Partial Payout / Taxable Factor?'**
  String get partialPayoutTaxableFactorTitle;

  /// No description provided for @defaultEqualDistributionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default: Equal distribution'**
  String get defaultEqualDistributionSubtitle;

  /// No description provided for @annualPayoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Payout'**
  String get annualPayoutLabel;

  /// No description provided for @perPayoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Per Payout'**
  String get perPayoutLabel;

  /// No description provided for @annualTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Annual Total'**
  String get annualTotalLabel;

  /// No description provided for @addCapitalGainAction.
  ///
  /// In en, this message translates to:
  /// **'Add Capital Gain'**
  String get addCapitalGainAction;

  /// No description provided for @editEntryAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Entry'**
  String get editEntryAction;

  /// No description provided for @selectButton.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectButton;

  /// No description provided for @agriculturalIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Agricultural Income'**
  String get agriculturalIncomeTitle;

  /// No description provided for @frequencyDropdownLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequencyDropdownLabel;

  /// No description provided for @addSalaryStructureAction.
  ///
  /// In en, this message translates to:
  /// **'Add Salary Structure'**
  String get addSalaryStructureAction;

  /// No description provided for @editSalaryStructureAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Salary Structure'**
  String get editSalaryStructureAction;

  /// No description provided for @noSalaryDataPreviousYearNote.
  ///
  /// In en, this message translates to:
  /// **'No salary data found for the previous year.'**
  String get noSalaryDataPreviousYearNote;

  /// No description provided for @copiedStructuresCountNote.
  ///
  /// In en, this message translates to:
  /// **'{count} salary structures copied.'**
  String copiedStructuresCountNote(String count);

  /// No description provided for @noHousePropertiesPreviousYearNote.
  ///
  /// In en, this message translates to:
  /// **'No house properties found for the previous year.'**
  String get noHousePropertiesPreviousYearNote;

  /// No description provided for @copiedPropertiesCountNote.
  ///
  /// In en, this message translates to:
  /// **'{count} house properties copied.'**
  String copiedPropertiesCountNote(String count);

  /// No description provided for @isCliffExemptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Is Cliff Exemption?'**
  String get isCliffExemptionTitle;

  /// No description provided for @exemptionLimitHelperText.
  ///
  /// In en, this message translates to:
  /// **'Income above this limit is fully taxable (no exemption applies).'**
  String get exemptionLimitHelperText;

  /// No description provided for @taxDetailsSavedStatus.
  ///
  /// In en, this message translates to:
  /// **'Tax details saved successfully.'**
  String get taxDetailsSavedStatus;

  /// No description provided for @clearCategoryDataContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all {category} data for FY {year}?'**
  String clearCategoryDataContent(String category, String year);

  /// No description provided for @clearAllFiscalYearDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear ALL Data for FY {year}?'**
  String clearAllFiscalYearDataTitle(String year);

  /// No description provided for @clearAllFiscalYearDataContent.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all tax data for this financial year. This action cannot be undone.'**
  String get clearAllFiscalYearDataContent;

  /// No description provided for @deleteAllButton.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAllButton;

  /// No description provided for @housePropertyTab.
  ///
  /// In en, this message translates to:
  /// **'House Property'**
  String get housePropertyTab;

  /// No description provided for @capitalGainsTab.
  ///
  /// In en, this message translates to:
  /// **'Capital Gains'**
  String get capitalGainsTab;

  /// No description provided for @fiscalYearPrefix.
  ///
  /// In en, this message translates to:
  /// **'FY'**
  String get fiscalYearPrefix;

  /// No description provided for @filterByDateRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter by Date Range'**
  String get filterByDateRangeLabel;

  /// No description provided for @clearDateFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear Date Filter'**
  String get clearDateFilterLabel;

  /// No description provided for @clearAllFiscalYearDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear ALL Fiscal Year Data'**
  String get clearAllFiscalYearDataLabel;

  /// No description provided for @clearCategoryDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear Category Data'**
  String get clearCategoryDataLabel;

  /// No description provided for @copyPreviousYearDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy from Previous Year'**
  String get copyPreviousYearDataLabel;

  /// No description provided for @estimatedTaxLiabilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Est. Tax Liability'**
  String get estimatedTaxLiabilityLabel;

  /// No description provided for @keepEditingButton.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get keepEditingButton;

  /// No description provided for @discardButton.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardButton;

  /// No description provided for @lastUpdatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get lastUpdatedLabel;

  /// No description provided for @fullYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Year'**
  String get fullYearLabel;

  /// No description provided for @dividendBreakdownNote.
  ///
  /// In en, this message translates to:
  /// **'Dividend income is tracked by advance tax installment periods for precise interest calculation.'**
  String get dividendBreakdownNote;

  /// No description provided for @dividendUpdatedStatus.
  ///
  /// In en, this message translates to:
  /// **'Dividend income updated.'**
  String get dividendUpdatedStatus;

  /// No description provided for @updateTotalButton.
  ///
  /// In en, this message translates to:
  /// **'Update Total'**
  String get updateTotalButton;

  /// No description provided for @noSalaryStructureDefinedNote.
  ///
  /// In en, this message translates to:
  /// **'No salary structure defined for this period.'**
  String get noSalaryStructureDefinedNote;

  /// No description provided for @basicLabel.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get basicLabel;

  /// No description provided for @allowancesLabel.
  ///
  /// In en, this message translates to:
  /// **'Allowances'**
  String get allowancesLabel;

  /// No description provided for @employerNPSLabel.
  ///
  /// In en, this message translates to:
  /// **'Employer NPS Contribution'**
  String get employerNPSLabel;

  /// No description provided for @leaveEncashmentTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave Encashment'**
  String get leaveEncashmentTitleLabel;

  /// No description provided for @gratuityTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Gratuity'**
  String get gratuityTitleLabel;

  /// No description provided for @customAdHocExemptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Ad-hoc Exemptions'**
  String get customAdHocExemptionsTitle;

  /// No description provided for @noAdHocExemptionsNote.
  ///
  /// In en, this message translates to:
  /// **'No ad-hoc exemptions added.'**
  String get noAdHocExemptionsNote;

  /// No description provided for @addAdHocExemptionAction.
  ///
  /// In en, this message translates to:
  /// **'Add Ad-hoc Exemption'**
  String get addAdHocExemptionAction;

  /// No description provided for @tdsTaxesPaidTitle.
  ///
  /// In en, this message translates to:
  /// **'TDS / Taxes Paid (Salary)'**
  String get tdsTaxesPaidTitle;

  /// No description provided for @detailedEstCurrentMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'DETAILED EST. (CURRENT MONTH)'**
  String get detailedEstCurrentMonthLabel;

  /// No description provided for @taxShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get taxShortLabel;

  /// No description provided for @dedShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Ded'**
  String get dedShortLabel;

  /// No description provided for @detailedLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Show Detailed Amounts'**
  String get detailedLinkLabel;

  /// No description provided for @bonusTaxNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Bonuses and variable pay are taxed in the month of receipt.'**
  String get bonusTaxNote;

  /// No description provided for @taxableHPIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxable House Property Income'**
  String get taxableHPIncomeLabel;

  /// No description provided for @interestLabel.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get interestLabel;

  /// No description provided for @letOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Let Out'**
  String get letOutLabel;

  /// No description provided for @lessEmployerNPSLabel.
  ///
  /// In en, this message translates to:
  /// **'Less: Employer NPS Contribution'**
  String get lessEmployerNPSLabel;

  /// No description provided for @taxableBeforeAdHocExemptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxable Before Ad-hoc Exemptions'**
  String get taxableBeforeAdHocExemptionsLabel;

  /// No description provided for @lessCustomAdHocExemptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Less: Custom Ad-hoc Exemptions'**
  String get lessCustomAdHocExemptionsLabel;

  /// No description provided for @editPropertyAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Property'**
  String get editPropertyAction;

  /// No description provided for @grossShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get grossShortLabel;

  /// No description provided for @netShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get netShortLabel;

  /// No description provided for @editBusinessAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Business'**
  String get editBusinessAction;

  /// No description provided for @shortTermSTCGLabel.
  ///
  /// In en, this message translates to:
  /// **'Short Term (STCG)'**
  String get shortTermSTCGLabel;

  /// No description provided for @otherAssetsTooltip.
  ///
  /// In en, this message translates to:
  /// **'LTCG on other assets is taxed at 20% with indexation.'**
  String get otherAssetsTooltip;

  /// No description provided for @amountCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount ({currency})'**
  String amountCurrencyLabel(String currency);

  /// No description provided for @giftRelativesExemptNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Gifts from relatives are fully exempt from tax.'**
  String get giftRelativesExemptNote;

  /// No description provided for @addAgriIncomeAction.
  ///
  /// In en, this message translates to:
  /// **'Add Agri Income'**
  String get addAgriIncomeAction;

  /// No description provided for @editAgriIncomeAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Agri Income'**
  String get editAgriIncomeAction;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @agriIncomeNote.
  ///
  /// In en, this message translates to:
  /// **'Agricultural income is exempt but used for rate purposes if it exceeds 5000 and total income exceeds basic exemption.'**
  String get agriIncomeNote;

  /// No description provided for @noAgriIncomeNote.
  ///
  /// In en, this message translates to:
  /// **'No agricultural income found for this year.'**
  String get noAgriIncomeNote;

  /// No description provided for @totalNetAgriIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Net Agri Income'**
  String get totalNetAgriIncomeLabel;

  /// No description provided for @maturityDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Maturity Date'**
  String get maturityDateLabel;

  /// No description provided for @selectDateAction.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDateAction;

  /// No description provided for @disclaimerRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer: These rules are based on current Indian Tax Laws. Review with a professional for your specific case.'**
  String get disclaimerRulesTitle;

  /// No description provided for @enableAggregateLimitsLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Aggregate Limits'**
  String get enableAggregateLimitsLabel;

  /// No description provided for @limitsUlipNonUlipSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Section 10(10D) limits for ULIP and Non-ULIP policies.'**
  String get limitsUlipNonUlipSubtitle;

  /// No description provided for @startDatesAggregateLimitsHeader.
  ///
  /// In en, this message translates to:
  /// **'Start Dates for Aggregate Limits'**
  String get startDatesAggregateLimitsHeader;

  /// No description provided for @ulipLimitStartLabel.
  ///
  /// In en, this message translates to:
  /// **'ULIP Limit Start'**
  String get ulipLimitStartLabel;

  /// No description provided for @nonUlipLimitStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Non-ULIP Limit Start'**
  String get nonUlipLimitStartLabel;

  /// No description provided for @aggregatePremiumLimitsHeader.
  ///
  /// In en, this message translates to:
  /// **'Aggregate Premium Limits'**
  String get aggregatePremiumLimitsHeader;

  /// No description provided for @ulipLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'ULIP Annual Limit'**
  String get ulipLimitLabel;

  /// No description provided for @nonUlipLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Non-ULIP Annual Limit'**
  String get nonUlipLimitLabel;

  /// No description provided for @enablePremiumPercentRulesLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Premium % Rules'**
  String get enablePremiumPercentRulesLabel;

  /// No description provided for @limitsPercentageSumAssuredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tax exemption based on premium as a percentage of sum assured.'**
  String get limitsPercentageSumAssuredSubtitle;

  /// No description provided for @premiumPercentRulesConfigHeader.
  ///
  /// In en, this message translates to:
  /// **'Premium % Rules Configuration'**
  String get premiumPercentRulesConfigHeader;

  /// No description provided for @policiesDatePctNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Rule applied based on the latest startDate <= policy issue date.'**
  String get policiesDatePctNote;

  /// No description provided for @pctLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'{pct}% Limit'**
  String pctLimitLabel(double pct);

  /// No description provided for @effectiveFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Effective From: {date}'**
  String effectiveFromLabel(String date);

  /// No description provided for @saveRulesAction.
  ///
  /// In en, this message translates to:
  /// **'Save Rules'**
  String get saveRulesAction;

  /// No description provided for @recalculateTaxSuccess.
  ///
  /// In en, this message translates to:
  /// **'Tax status for all policies recalculated.'**
  String get recalculateTaxSuccess;

  /// No description provided for @taxOptimizationGainsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tax Optimization & Gains'**
  String get taxOptimizationGainsTitle;

  /// No description provided for @annPremiumLabel.
  ///
  /// In en, this message translates to:
  /// **'Ann. Premium'**
  String get annPremiumLabel;

  /// No description provided for @currentTaxableLabel.
  ///
  /// In en, this message translates to:
  /// **'Curr. Taxable'**
  String get currentTaxableLabel;

  /// No description provided for @futureTaxableLabel.
  ///
  /// In en, this message translates to:
  /// **'Future Taxable'**
  String get futureTaxableLabel;

  /// No description provided for @totalTaxableUlipLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Taxable ULIP'**
  String get totalTaxableUlipLabel;

  /// No description provided for @totalTaxableNonUlipLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Taxable Non-ULIP'**
  String get totalTaxableNonUlipLabel;

  /// No description provided for @taxableAmountsNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Taxable amounts are the sum of annual premiums for policies that have lost 10(10D) exemption.'**
  String get taxableAmountsNote;

  /// No description provided for @addPremiumRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Premium Rule'**
  String get addPremiumRuleTitle;

  /// No description provided for @limitPctLabel.
  ///
  /// In en, this message translates to:
  /// **'Limit % ({symbol})'**
  String limitPctLabel(String symbol);

  /// No description provided for @addRuleAction.
  ///
  /// In en, this message translates to:
  /// **'Add Rule'**
  String get addRuleAction;

  /// No description provided for @requiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredLabel;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// No description provided for @principalShort.
  ///
  /// In en, this message translates to:
  /// **'Principal'**
  String get principalShort;

  /// No description provided for @interestShort.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get interestShort;

  /// No description provided for @loanEmiTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan EMIs'**
  String get loanEmiTitle;

  /// No description provided for @updateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButton;

  /// No description provided for @monthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthLabel;

  /// No description provided for @selectReinvestmentTypeNote.
  ///
  /// In en, this message translates to:
  /// **'Select reinvestment type to see details.'**
  String get selectReinvestmentTypeNote;

  /// No description provided for @descriptionAssetLabel.
  ///
  /// In en, this message translates to:
  /// **'Description / Asset'**
  String get descriptionAssetLabel;

  /// No description provided for @isLTCGLabel.
  ///
  /// In en, this message translates to:
  /// **'Is LTCG?'**
  String get isLTCGLabel;

  /// No description provided for @editOtherIncomeAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Other Income'**
  String get editOtherIncomeAction;

  /// No description provided for @advanceTaxTitle.
  ///
  /// In en, this message translates to:
  /// **'Advance Tax'**
  String get advanceTaxTitle;

  /// No description provided for @tdsTitle.
  ///
  /// In en, this message translates to:
  /// **'TDS'**
  String get tdsTitle;

  /// No description provided for @tcsTitle.
  ///
  /// In en, this message translates to:
  /// **'TCS'**
  String get tcsTitle;

  /// No description provided for @advanceTaxInstallmentNote.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}: {percent}% of total tax (approx {amount})'**
  String advanceTaxInstallmentNote(
      String month, String day, String percent, String amount);

  /// No description provided for @addEntryTypeAction.
  ///
  /// In en, this message translates to:
  /// **'Add {type}'**
  String addEntryTypeAction(String type);

  /// No description provided for @editEntryTypeAction.
  ///
  /// In en, this message translates to:
  /// **'Edit {type}'**
  String editEntryTypeAction(String type);

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @giftThresholdNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Aggregate cash gifts above {limit} in a year are fully taxable.'**
  String giftThresholdNote(String limit);

  /// No description provided for @noCashGiftsNote.
  ///
  /// In en, this message translates to:
  /// **'No cash gifts found for this year.'**
  String get noCashGiftsNote;

  /// No description provided for @editGiftAction.
  ///
  /// In en, this message translates to:
  /// **'Edit Gift'**
  String get editGiftAction;

  /// No description provided for @errorLabelWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorLabelWithDetails(String error);

  /// No description provided for @resetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetButton;

  /// No description provided for @doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @verifyAction.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyAction;

  /// No description provided for @saveEnableAction.
  ///
  /// In en, this message translates to:
  /// **'Save & Enable'**
  String get saveEnableAction;

  /// No description provided for @useExistingPinAction.
  ///
  /// In en, this message translates to:
  /// **'Use Existing PIN'**
  String get useExistingPinAction;

  /// No description provided for @clearCloudDataAction.
  ///
  /// In en, this message translates to:
  /// **'CLEAR CLOUD DATA'**
  String get clearCloudDataAction;

  /// No description provided for @wipeDeactivateAction.
  ///
  /// In en, this message translates to:
  /// **'WIPE & DEACTIVATE'**
  String get wipeDeactivateAction;

  /// No description provided for @yesRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Yes, Restore'**
  String get yesRestoreAction;

  /// No description provided for @updateAndReloadAction.
  ///
  /// In en, this message translates to:
  /// **'Update & Reload'**
  String get updateAndReloadAction;

  /// No description provided for @forceReloadAction.
  ///
  /// In en, this message translates to:
  /// **'Force Reload'**
  String get forceReloadAction;

  /// No description provided for @encryptBackupAction.
  ///
  /// In en, this message translates to:
  /// **'ENCRYPT & BACKUP'**
  String get encryptBackupAction;

  /// No description provided for @backupUnencryptedAction.
  ///
  /// In en, this message translates to:
  /// **'Backup Unencrypted'**
  String get backupUnencryptedAction;

  /// No description provided for @createAction.
  ///
  /// In en, this message translates to:
  /// **'CREATE'**
  String get createAction;

  /// No description provided for @deleteActionCap.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteActionCap;

  /// No description provided for @cancelActionCap.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancelActionCap;

  /// No description provided for @restoreActionCap.
  ///
  /// In en, this message translates to:
  /// **'RESTORE'**
  String get restoreActionCap;

  /// No description provided for @clearActionCap.
  ///
  /// In en, this message translates to:
  /// **'CLEAR'**
  String get clearActionCap;

  /// No description provided for @enterPinHeader.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get enterPinHeader;

  /// No description provided for @pinDigitsHint.
  ///
  /// In en, this message translates to:
  /// **'4-6 digits'**
  String get pinDigitsHint;

  /// No description provided for @tooManyAttemptsMsg.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get tooManyAttemptsMsg;

  /// No description provided for @incorrectPinWithAttempts.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN ({count} attempts left)'**
  String incorrectPinWithAttempts(int count);

  /// No description provided for @forgotPinAction.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN? / Use Password'**
  String get forgotPinAction;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueOfflineAction.
  ///
  /// In en, this message translates to:
  /// **'Continue Offline / Use Locally'**
  String get continueOfflineAction;

  /// No description provided for @loginStatusMsg.
  ///
  /// In en, this message translates to:
  /// **'Login Status: {message}'**
  String loginStatusMsg(String message);

  /// No description provided for @recordLoanPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Loan Payment'**
  String get recordLoanPaymentTitle;

  /// No description provided for @emiNote.
  ///
  /// In en, this message translates to:
  /// **'Regular EMI covers Interest + Principal components.'**
  String get emiNote;

  /// No description provided for @prepaymentNote.
  ///
  /// In en, this message translates to:
  /// **'Prepayment reduces Principal. Choose impact above.'**
  String get prepaymentNote;

  /// No description provided for @paymentRecordedMsg.
  ///
  /// In en, this message translates to:
  /// **'Payment Recorded'**
  String get paymentRecordedMsg;

  /// No description provided for @payBillTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay {name} Bill'**
  String payBillTitle(String name);

  /// No description provided for @billAlreadyPaidNote.
  ///
  /// In en, this message translates to:
  /// **'Bill is already marked as paid.'**
  String get billAlreadyPaidNote;

  /// No description provided for @roundOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Round Off'**
  String get roundOffLabel;

  /// No description provided for @roundToNearestNote.
  ///
  /// In en, this message translates to:
  /// **'Round to nearest number'**
  String get roundToNearestNote;

  /// No description provided for @errorLoadingAccounts.
  ///
  /// In en, this message translates to:
  /// **'Error loading accounts'**
  String get errorLoadingAccounts;

  /// No description provided for @updateBillingCycleNote.
  ///
  /// In en, this message translates to:
  /// **'Updating the billing cycle requires freezing the statement until your chosen start month.'**
  String get updateBillingCycleNote;

  /// No description provided for @freezeDateLockedNote.
  ///
  /// In en, this message translates to:
  /// **'Freeze date cannot be changed for an active freeze.'**
  String get freezeDateLockedNote;

  /// No description provided for @debtZeroRequirementNote.
  ///
  /// In en, this message translates to:
  /// **'Billing cycle day can only be changed when the total debt is 0. However, you can still update your Payment Due Date.'**
  String get debtZeroRequirementNote;

  /// No description provided for @selectFirstStatementMonth.
  ///
  /// In en, this message translates to:
  /// **'Select First Statement Month:'**
  String get selectFirstStatementMonth;

  /// No description provided for @initializeUpdateAction.
  ///
  /// In en, this message translates to:
  /// **'Initialize Update'**
  String get initializeUpdateAction;

  /// No description provided for @updateBillingCycleTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Billing Cycle'**
  String get updateBillingCycleTitle;

  /// No description provided for @freezeTransactionsUntil.
  ///
  /// In en, this message translates to:
  /// **'Freeze Transactions Until'**
  String get freezeTransactionsUntil;

  /// No description provided for @newBillingCycleDayLabel.
  ///
  /// In en, this message translates to:
  /// **'New Billing Cycle Day'**
  String get newBillingCycleDayLabel;

  /// No description provided for @newPaymentDueDayLabel.
  ///
  /// In en, this message translates to:
  /// **'New Payment Due Day'**
  String get newPaymentDueDayLabel;

  /// No description provided for @billingCycleUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Billing cycle update initialized successfully!'**
  String get billingCycleUpdateSuccess;

  /// No description provided for @paymentDueDateUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment due date updated successfully!'**
  String get paymentDueDateUpdateSuccess;

  /// No description provided for @selectFirstStatementMonthError.
  ///
  /// In en, this message translates to:
  /// **'Please select your first statement date.'**
  String get selectFirstStatementMonthError;

  /// No description provided for @payFromAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Account (Optional)'**
  String get payFromAccountLabel;

  /// No description provided for @prepaymentEffectLabel.
  ///
  /// In en, this message translates to:
  /// **'Prepayment Effect:'**
  String get prepaymentEffectLabel;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// No description provided for @upToDateMessage.
  ///
  /// In en, this message translates to:
  /// **'You are consistent with the latest version ({version}).'**
  String upToDateMessage(String version);

  /// No description provided for @forceReloadNote.
  ///
  /// In en, this message translates to:
  /// **'If you don\'t see expected changes, you can force a reload.'**
  String get forceReloadNote;

  /// No description provided for @updateApplicationConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will clear the application cache and reload the latest version. Your local data (Hive) will remain safe. Do you want to proceed?'**
  String get updateApplicationConfirmMessage;

  /// No description provided for @updateNotAvailableError.
  ///
  /// In en, this message translates to:
  /// **'Update not available for this platform.'**
  String get updateNotAvailableError;

  /// No description provided for @requestTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please check your connection.'**
  String get requestTimeoutError;

  /// No description provided for @restoreCloudWarning.
  ///
  /// In en, this message translates to:
  /// **'This will PERMANENTLY WIPE all local data and replace it with your cloud data.'**
  String get restoreCloudWarning;

  /// No description provided for @restoreCompleteStatus.
  ///
  /// In en, this message translates to:
  /// **'Restore Complete! Reloading...'**
  String get restoreCompleteStatus;

  /// No description provided for @deactivateAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Cloud Account?'**
  String get deactivateAccountQuestion;

  /// No description provided for @deactivateWipeWarning.
  ///
  /// In en, this message translates to:
  /// **'This will PERMANENTLY WIPE all your data from both the cloud and your local device.'**
  String get deactivateWipeWarning;

  /// No description provided for @localDataSafeNote.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted, and you will be completely logged out with a blank slate.'**
  String get localDataSafeNote;

  /// No description provided for @accountDeactivatedStatus.
  ///
  /// In en, this message translates to:
  /// **'Account Deactivated and All Data Wiped.'**
  String get accountDeactivatedStatus;

  /// No description provided for @clearCloudDataQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear Cloud Data?'**
  String get clearCloudDataQuestion;

  /// No description provided for @clearCloudWarning.
  ///
  /// In en, this message translates to:
  /// **'This will PERMANENTLY DELETE all your data from the cloud server.'**
  String get clearCloudWarning;

  /// No description provided for @localDataSafeLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Local Data will be SAFE.'**
  String get localDataSafeLabel;

  /// No description provided for @accountActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Account will remain ACTIVE.'**
  String get accountActiveLabel;

  /// No description provided for @proceedQuestion.
  ///
  /// In en, this message translates to:
  /// **'Proceed?'**
  String get proceedQuestion;

  /// No description provided for @authFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Authentication Failed: {error}'**
  String authFailedStatus(String error);

  /// No description provided for @cloudDataClearedStatus.
  ///
  /// In en, this message translates to:
  /// **'Cloud Data Cleared Successfully.'**
  String get cloudDataClearedStatus;

  /// No description provided for @selectCurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get selectCurrencyTitle;

  /// No description provided for @encryptionPasscodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Encryption Passcode'**
  String get encryptionPasscodeLabel;

  /// No description provided for @pleaseEnterPasscodeError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a passcode'**
  String get pleaseEnterPasscodeError;

  /// No description provided for @verifyAppPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify App PIN'**
  String get verifyAppPinTitle;

  /// No description provided for @verifyPinReasonDefault.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-6 digit PIN to continue.'**
  String get verifyPinReasonDefault;

  /// No description provided for @pinLengthError.
  ///
  /// In en, this message translates to:
  /// **'PIN must be 4-6 digits long.'**
  String get pinLengthError;

  /// No description provided for @tooManyAttemptsError.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get tooManyAttemptsError;

  /// No description provided for @incorrectPinError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get incorrectPinError;

  /// No description provided for @setAppPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set App PIN'**
  String get setAppPinTitle;

  /// No description provided for @setupAppLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup App Lock'**
  String get setupAppLockTitle;

  /// No description provided for @enterPinToSecureNote.
  ///
  /// In en, this message translates to:
  /// **'Enter a 4-6 digit PIN to secure the app.'**
  String get enterPinToSecureNote;

  /// No description provided for @existingPinNote.
  ///
  /// In en, this message translates to:
  /// **'You have an existing PIN. Do you want to use it or set a new one?'**
  String get existingPinNote;

  /// No description provided for @newPinHint.
  ///
  /// In en, this message translates to:
  /// **'NEW PIN'**
  String get newPinHint;

  /// No description provided for @appLockEnabledStatus.
  ///
  /// In en, this message translates to:
  /// **'App Lock Enabled'**
  String get appLockEnabledStatus;

  /// No description provided for @pinSavedLockedStatus.
  ///
  /// In en, this message translates to:
  /// **'PIN Saved & Locked'**
  String get pinSavedLockedStatus;

  /// No description provided for @deleteProfileQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile?'**
  String get deleteProfileQuestion;

  /// No description provided for @deleteProfileWarning.
  ///
  /// In en, this message translates to:
  /// **'This will PERMANENTLY delete the profile \'{name}\' and ALL its associated data (Accounts, Transactions, Loans, Taxes, Lending, Categories). This cannot be undone.'**
  String deleteProfileWarning(String name);

  /// No description provided for @noOtherProfilesError.
  ///
  /// In en, this message translates to:
  /// **'No other profiles to copy from.'**
  String get noOtherProfilesError;

  /// No description provided for @copyCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy Categories'**
  String get copyCategoriesTitle;

  /// No description provided for @categoriesCopiedStatus.
  ///
  /// In en, this message translates to:
  /// **'Categories copied to {name}'**
  String categoriesCopiedStatus(String name);

  /// No description provided for @updateApplicationTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Application'**
  String get updateApplicationTitle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @installAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Install App'**
  String get installAppTitle;

  /// No description provided for @dangerZoneHeader.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZoneHeader;

  /// No description provided for @deactivateWipeCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate & Wipe Cloud Data'**
  String get deactivateWipeCloudTitle;

  /// No description provided for @deactivateWipeCloudDesc.
  ///
  /// In en, this message translates to:
  /// **'Delete all cloud data and sign out of cloud sync. This cannot be undone.'**
  String get deactivateWipeCloudDesc;

  /// No description provided for @offlineUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Offline: Unable to check for updates.'**
  String get offlineUpdateError;

  /// No description provided for @cloudRestoreWarning.
  ///
  /// In en, this message translates to:
  /// **'If your cloud backup was encrypted, please enter the passcode. If it was not encrypted, leave this blank and continue.'**
  String get cloudRestoreWarning;

  /// No description provided for @encryptBackupQuestion.
  ///
  /// In en, this message translates to:
  /// **'Encrypt Backup?'**
  String get encryptBackupQuestion;

  /// No description provided for @noteCategoriesEncryption.
  ///
  /// In en, this message translates to:
  /// **'Note: Categories are stored as metadata and are NOT encrypted.'**
  String get noteCategoriesEncryption;

  /// No description provided for @frozenLabel.
  ///
  /// In en, this message translates to:
  /// **'FROZEN'**
  String get frozenLabel;

  /// No description provided for @notCalculatedYet.
  ///
  /// In en, this message translates to:
  /// **'Not calculated yet'**
  String get notCalculatedYet;

  /// No description provided for @tbdLabel.
  ///
  /// In en, this message translates to:
  /// **'TBD'**
  String get tbdLabel;

  /// No description provided for @clearBilledAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Billed Amount'**
  String get clearBilledAmountTitle;

  /// No description provided for @clearBilledAmountDesc.
  ///
  /// In en, this message translates to:
  /// **'Mark current bill as paid/cleared'**
  String get clearBilledAmountDesc;

  /// No description provided for @clearBilledConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will set the current \"Billed Amount\" to 0 without recording a payment transaction.'**
  String get clearBilledConfirmMessage;

  /// No description provided for @billedAmountClearedStatus.
  ///
  /// In en, this message translates to:
  /// **'Billed amount cleared.'**
  String get billedAmountClearedStatus;

  /// No description provided for @recalculateBillTitle.
  ///
  /// In en, this message translates to:
  /// **'Recalculate Bill'**
  String get recalculateBillTitle;

  /// No description provided for @recalculateBillDesc.
  ///
  /// In en, this message translates to:
  /// **'Refreshes billing cycle display'**
  String get recalculateBillDesc;

  /// No description provided for @recalculatingBillStatus.
  ///
  /// In en, this message translates to:
  /// **'Recalculating bill...'**
  String get recalculatingBillStatus;

  /// No description provided for @billRecalculatedStatus.
  ///
  /// In en, this message translates to:
  /// **'Bill recalculated for {name}.'**
  String billRecalculatedStatus(String name);

  /// No description provided for @usedAvailableShort.
  ///
  /// In en, this message translates to:
  /// **'{used} / {avail}'**
  String usedAvailableShort(String used, String avail);

  /// No description provided for @usedAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'{used} / {avail}'**
  String usedAvailableLabel(String used, String avail);

  /// No description provided for @requiredShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Req'**
  String get requiredShortLabel;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteAccountConfirmMessage(String name);

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Existing transactions will NOT be deleted but will no longer be linked to this account.'**
  String get deleteAccountWarning;

  /// No description provided for @accountDeletedStatus.
  ///
  /// In en, this message translates to:
  /// **'Account \"{name}\" deleted.'**
  String accountDeletedStatus(String name);

  /// No description provided for @newAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'New Account'**
  String get newAccountTitle;

  /// No description provided for @editAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get editAccountTitle;

  /// No description provided for @accountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get accountNameLabel;

  /// No description provided for @reservedNameError.
  ///
  /// In en, this message translates to:
  /// **'Reserved name'**
  String get reservedNameError;

  /// No description provided for @currentBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get currentBalanceLabel;

  /// No description provided for @createAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountAction;

  /// No description provided for @updateAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Update Account'**
  String get updateAccountAction;

  /// No description provided for @creditLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit Limit'**
  String get creditLimitLabel;

  /// No description provided for @billGenDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Bill Gen. Day'**
  String get billGenDayLabel;

  /// No description provided for @paymentDueDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Due Day'**
  String get paymentDueDayLabel;

  /// No description provided for @dayOfMonthHelper.
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get dayOfMonthHelper;

  /// No description provided for @indianRupeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Indian Rupee (₹)'**
  String get indianRupeeLabel;

  /// No description provided for @britishPoundLabel.
  ///
  /// In en, this message translates to:
  /// **'British Pound (£)'**
  String get britishPoundLabel;

  /// No description provided for @euroLabel.
  ///
  /// In en, this message translates to:
  /// **'Euro (€)'**
  String get euroLabel;

  /// No description provided for @usDollarLabel.
  ///
  /// In en, this message translates to:
  /// **'US Dollar (\$)'**
  String get usDollarLabel;

  /// No description provided for @freqDaily.
  ///
  /// In en, this message translates to:
  /// **'DAILY'**
  String get freqDaily;

  /// No description provided for @freqWeekly.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY'**
  String get freqWeekly;

  /// No description provided for @freqMonthly.
  ///
  /// In en, this message translates to:
  /// **'MONTHLY'**
  String get freqMonthly;

  /// No description provided for @freqYearly.
  ///
  /// In en, this message translates to:
  /// **'YEARLY'**
  String get freqYearly;

  /// No description provided for @daySuffixSt.
  ///
  /// In en, this message translates to:
  /// **'st'**
  String get daySuffixSt;

  /// No description provided for @daySuffixNd.
  ///
  /// In en, this message translates to:
  /// **'nd'**
  String get daySuffixNd;

  /// No description provided for @daySuffixRd.
  ///
  /// In en, this message translates to:
  /// **'rd'**
  String get daySuffixRd;

  /// No description provided for @daySuffixTh.
  ///
  /// In en, this message translates to:
  /// **'th'**
  String get daySuffixTh;

  /// No description provided for @everyEvery.
  ///
  /// In en, this message translates to:
  /// **' - Every '**
  String get everyEvery;

  /// No description provided for @prepaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Prepayment'**
  String get prepaymentLabel;

  /// No description provided for @loanTypePersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get loanTypePersonal;

  /// No description provided for @loanTypeHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get loanTypeHome;

  /// No description provided for @loanTypeEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get loanTypeEducation;

  /// No description provided for @loanTypeCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get loanTypeCar;

  /// No description provided for @loanTypeGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get loanTypeGold;

  /// No description provided for @loanTypeBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get loanTypeBusiness;

  /// No description provided for @loanTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get loanTypeOther;

  /// No description provided for @bankLoanCategory.
  ///
  /// In en, this message translates to:
  /// **'Bank loan'**
  String get bankLoanCategory;

  /// No description provided for @ccBillPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'CC Bill Payment: {name}'**
  String ccBillPaymentTitle(Object name);

  /// No description provided for @creditCardBillCategory.
  ///
  /// In en, this message translates to:
  /// **'Credit Card Bill'**
  String get creditCardBillCategory;

  /// No description provided for @roundingAdjustmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Rounding Adjustment'**
  String get roundingAdjustmentTitle;

  /// No description provided for @adjustmentCategory.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get adjustmentCategory;

  /// No description provided for @timeoutError.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please check your connection.'**
  String get timeoutError;

  /// No description provided for @restoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreButton;

  /// No description provided for @backupDataZipLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup Data (ZIP)'**
  String get backupDataZipLabel;

  /// No description provided for @restoreDataZipLabel.
  ///
  /// In en, this message translates to:
  /// **'Restore Data (ZIP)'**
  String get restoreDataZipLabel;

  /// No description provided for @repairSuccessStatus.
  ///
  /// In en, this message translates to:
  /// **'{name}: Successfully repaired {count} items.'**
  String repairSuccessStatus(String name, int count);

  /// No description provided for @repairFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Repair Failed: {error}'**
  String repairFailedStatus(String error);

  /// No description provided for @manageRecurringPaymentsAction.
  ///
  /// In en, this message translates to:
  /// **'Manage Recurring Payments'**
  String get manageRecurringPaymentsAction;

  /// No description provided for @manageCategoriesAction.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get manageCategoriesAction;

  /// No description provided for @switchedToProfileStatus.
  ///
  /// In en, this message translates to:
  /// **'Switched to profile: {name}'**
  String switchedToProfileStatus(String name);

  /// No description provided for @addNewProfileAction.
  ///
  /// In en, this message translates to:
  /// **'Add New Profile'**
  String get addNewProfileAction;

  /// No description provided for @enterNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterNameHint;

  /// No description provided for @amountLabelText.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabelText;

  /// No description provided for @numTransactionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of Transactions'**
  String get numTransactionsLabel;

  /// No description provided for @defaultIntervalNote.
  ///
  /// In en, this message translates to:
  /// **'Default interval between backups'**
  String get defaultIntervalNote;

  /// No description provided for @logoutActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutActionLabel;

  /// No description provided for @appLockPinTitle.
  ///
  /// In en, this message translates to:
  /// **'App Lock PIN'**
  String get appLockPinTitle;

  /// No description provided for @appLockPinDesc.
  ///
  /// In en, this message translates to:
  /// **'Secure the app with a PIN'**
  String get appLockPinDesc;

  /// No description provided for @changePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePinTitle;

  /// No description provided for @sameAccountError.
  ///
  /// In en, this message translates to:
  /// **'Source and Target accounts cannot be the same.'**
  String get sameAccountError;

  /// No description provided for @futureScheduleOnlyError.
  ///
  /// In en, this message translates to:
  /// **'\"Just Schedule\" is only allowed for Today or Future dates.'**
  String get futureScheduleOnlyError;

  /// No description provided for @updateSimilarTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Similar Transactions?'**
  String get updateSimilarTitle;

  /// No description provided for @updateSimilarMessage.
  ///
  /// In en, this message translates to:
  /// **'Found {count} other transactions with title \"{title}\" and category \"{oldCategory}\". Do you want to update their category to \"{newCategory}\" as well?'**
  String updateSimilarMessage(
      int count, String title, String oldCategory, String newCategory);

  /// No description provided for @noJustThisOne.
  ///
  /// In en, this message translates to:
  /// **'NO, Just this one'**
  String get noJustThisOne;

  /// No description provided for @yesUpdateAll.
  ///
  /// In en, this message translates to:
  /// **'YES, Update All'**
  String get yesUpdateAll;

  /// No description provided for @transferCategory.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferCategory;

  /// No description provided for @day15Hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 15'**
  String get day15Hint;

  /// No description provided for @day5Hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5'**
  String get day5Hint;

  /// No description provided for @japaneseYenLabel.
  ///
  /// In en, this message translates to:
  /// **'Japanese Yen (¥)'**
  String get japaneseYenLabel;

  /// No description provided for @chineseYuanLabel.
  ///
  /// In en, this message translates to:
  /// **'Chinese Yuan (¥)'**
  String get chineseYuanLabel;

  /// No description provided for @uaeDirhamLabel.
  ///
  /// In en, this message translates to:
  /// **'UAE Dirham (د.إ)'**
  String get uaeDirhamLabel;

  /// No description provided for @bulkRecordDesc.
  ///
  /// In en, this message translates to:
  /// **'Record EMI payments for a date range automatically. Assumes paid on time.'**
  String get bulkRecordDesc;

  /// No description provided for @startDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDateLabel;

  /// No description provided for @endDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDateLabel;

  /// No description provided for @recordPaymentsAction.
  ///
  /// In en, this message translates to:
  /// **'Record Payments'**
  String get recordPaymentsAction;

  /// No description provided for @rateChangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate Change'**
  String get rateChangeLabel;

  /// No description provided for @topupLabel.
  ///
  /// In en, this message translates to:
  /// **'Top-up'**
  String get topupLabel;

  /// No description provided for @loanTopUpCategory.
  ///
  /// In en, this message translates to:
  /// **'Loan Top-up'**
  String get loanTopUpCategory;

  /// Suffix for annual amounts
  ///
  /// In en, this message translates to:
  /// **' / yr'**
  String get perYearLabel;

  /// India jurisdiction label
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get indiaLabel;

  /// Custom jurisdiction label
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customLabel;

  /// Financial Year label
  ///
  /// In en, this message translates to:
  /// **'FY {year}-{nextYear}'**
  String fyLabel(int year, int nextYear);

  /// Content for unsaved changes warning when switching years
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Switching years will discard them. Continue?'**
  String get unsavedChangesSwitchYearContent;

  /// Title for restore defaults dialog
  ///
  /// In en, this message translates to:
  /// **'Restore System Defaults?'**
  String get restoreSystemDefaultsTitle;

  /// Content for restore defaults dialog
  ///
  /// In en, this message translates to:
  /// **'This will delete custom tax rules for this year and revert to system defaults (or previous year). Continue?'**
  String get restoreSystemDefaultsContent;

  /// Status message after copying rules from previous year
  ///
  /// In en, this message translates to:
  /// **'Values copied from previous year. Click Save to apply.'**
  String get copiedFromPreviousYearStatus;

  /// Label for mapping targets
  ///
  /// In en, this message translates to:
  /// **'Maps to: {target}'**
  String mapsToLabel(String target);

  /// Header for advanced mappings section
  ///
  /// In en, this message translates to:
  /// **'Advanced Mappings (CG / Filters)'**
  String get advancedMappingsHeader;

  /// No description provided for @calculatedRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Calculated Rate'**
  String get calculatedRateLabel;

  /// No description provided for @invalidLabel.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get invalidLabel;

  /// Continue action label
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// Language selection label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// System default language option
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @investmentsAction.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get investmentsAction;

  /// No description provided for @investmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Investments'**
  String get investmentsTitle;

  /// No description provided for @investmentDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get investmentDashboard;

  /// No description provided for @investmentManagement.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get investmentManagement;

  /// No description provided for @totalValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Value'**
  String get totalValueLabel;

  /// No description provided for @investedLabel.
  ///
  /// In en, this message translates to:
  /// **'Invested'**
  String get investedLabel;

  /// No description provided for @unrealizedGainLabel.
  ///
  /// In en, this message translates to:
  /// **'Unrealized Gain'**
  String get unrealizedGainLabel;

  /// No description provided for @readyToSellLT.
  ///
  /// In en, this message translates to:
  /// **'{count} Long-term ready'**
  String readyToSellLT(int count);

  /// No description provided for @addInvestment.
  ///
  /// In en, this message translates to:
  /// **'Add Investment'**
  String get addInvestment;

  /// No description provided for @editInvestment.
  ///
  /// In en, this message translates to:
  /// **'Edit Investment'**
  String get editInvestment;

  /// No description provided for @investmentName.
  ///
  /// In en, this message translates to:
  /// **'Investment Name'**
  String get investmentName;

  /// No description provided for @investmentType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get investmentType;

  /// No description provided for @acquisitionDate.
  ///
  /// In en, this message translates to:
  /// **'Acquisition Date'**
  String get acquisitionDate;

  /// No description provided for @acquisitionPrice.
  ///
  /// In en, this message translates to:
  /// **'Acquisition Price'**
  String get acquisitionPrice;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @currentPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Price'**
  String get currentPriceLabel;

  /// No description provided for @mfCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'MF Category'**
  String get mfCategoryLabel;

  /// No description provided for @thresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'LT Threshold (Years)'**
  String get thresholdLabel;

  /// No description provided for @notAutoCalculated.
  ///
  /// In en, this message translates to:
  /// **'(Not auto-calculated)'**
  String get notAutoCalculated;

  /// No description provided for @exportTemplate.
  ///
  /// In en, this message translates to:
  /// **'Export Tickers'**
  String get exportTemplate;

  /// No description provided for @importPrices.
  ///
  /// In en, this message translates to:
  /// **'Import Prices'**
  String get importPrices;

  /// No description provided for @updatePricesSuccess.
  ///
  /// In en, this message translates to:
  /// **'Prices updated for {count} items'**
  String updatePricesSuccess(int count);

  /// No description provided for @investmentCodeName.
  ///
  /// In en, this message translates to:
  /// **'Ticker / Code Name'**
  String get investmentCodeName;

  /// No description provided for @investmentType_stock.
  ///
  /// In en, this message translates to:
  /// **'Stocks'**
  String get investmentType_stock;

  /// No description provided for @investmentType_mutualFund.
  ///
  /// In en, this message translates to:
  /// **'Mutual Funds'**
  String get investmentType_mutualFund;

  /// No description provided for @investmentType_fixedSavings.
  ///
  /// In en, this message translates to:
  /// **'Fixed Savings (FD/RD)'**
  String get investmentType_fixedSavings;

  /// No description provided for @investmentType_nps.
  ///
  /// In en, this message translates to:
  /// **'NPS'**
  String get investmentType_nps;

  /// No description provided for @investmentType_pf.
  ///
  /// In en, this message translates to:
  /// **'PF / EPF / VPF'**
  String get investmentType_pf;

  /// No description provided for @investmentType_moneyMarket.
  ///
  /// In en, this message translates to:
  /// **'Money Market'**
  String get investmentType_moneyMarket;

  /// No description provided for @investmentType_overnight.
  ///
  /// In en, this message translates to:
  /// **'Overnight Fund'**
  String get investmentType_overnight;

  /// No description provided for @investmentType_otherRecord.
  ///
  /// In en, this message translates to:
  /// **'Other (Variable Value)'**
  String get investmentType_otherRecord;

  /// No description provided for @investmentType_otherFixed.
  ///
  /// In en, this message translates to:
  /// **'Other (Fixed Interest)'**
  String get investmentType_otherFixed;

  /// No description provided for @mfCategory_flexi.
  ///
  /// In en, this message translates to:
  /// **'Flexi Cap'**
  String get mfCategory_flexi;

  /// No description provided for @mfCategory_largeCap.
  ///
  /// In en, this message translates to:
  /// **'Large Cap'**
  String get mfCategory_largeCap;

  /// No description provided for @mfCategory_midCap.
  ///
  /// In en, this message translates to:
  /// **'Mid Cap'**
  String get mfCategory_midCap;

  /// No description provided for @mfCategory_smallCap.
  ///
  /// In en, this message translates to:
  /// **'Small Cap'**
  String get mfCategory_smallCap;

  /// No description provided for @mfCategory_debt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get mfCategory_debt;

  /// No description provided for @mfCategory_mfIndex.
  ///
  /// In en, this message translates to:
  /// **'Index Fund'**
  String get mfCategory_mfIndex;

  /// No description provided for @mfCategory_industry.
  ///
  /// In en, this message translates to:
  /// **'Sectoral / Industry'**
  String get mfCategory_industry;

  /// No description provided for @mfCategory_others.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get mfCategory_others;

  /// No description provided for @sessionExpiredLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'You were logged out because another device logged into this account.'**
  String get sessionExpiredLogoutMessage;

  /// No description provided for @sessionVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Session verification failed. Sync paused.'**
  String get sessionVerificationFailed;

  /// No description provided for @connectionFailedOffline.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Switching to Offline Mode.'**
  String get connectionFailedOffline;

  /// No description provided for @encryptedBackupPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted Backup Found'**
  String get encryptedBackupPromptTitle;

  /// No description provided for @encryptedBackupPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Your cloud backup is encrypted. Please enter your passcode to restore your data.'**
  String get encryptedBackupPromptBody;

  /// No description provided for @incorrectPasscodeError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect passcode. Please try again.'**
  String get incorrectPasscodeError;

  /// No description provided for @passcodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Passcode'**
  String get passcodeLabel;

  /// No description provided for @allTypesLabel.
  ///
  /// In en, this message translates to:
  /// **'All Types'**
  String get allTypesLabel;

  /// No description provided for @sortByOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Sort by Oldest First'**
  String get sortByOldestFirst;

  /// No description provided for @sortByHighestGain.
  ///
  /// In en, this message translates to:
  /// **'Sort by Highest Gain'**
  String get sortByHighestGain;

  /// No description provided for @deleteInvestmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Investment?'**
  String get deleteInvestmentTitle;

  /// No description provided for @deleteInvestmentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove this investment record.'**
  String get deleteInvestmentConfirmation;

  /// No description provided for @searchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search Investments'**
  String get searchLabel;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get copyToClipboard;

  /// No description provided for @exportJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Tickers (JSON)'**
  String get exportJsonTitle;

  /// No description provided for @importJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Prices (JSON)'**
  String get importJsonTitle;

  /// No description provided for @importJsonHint.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON here...'**
  String get importJsonHint;

  /// No description provided for @invalidJsonError.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON format'**
  String get invalidJsonError;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard!'**
  String get copiedToClipboard;

  /// No description provided for @addInvestmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Investment'**
  String get addInvestmentTitle;

  /// No description provided for @editInvestmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Investment'**
  String get editInvestmentTitle;

  /// No description provided for @acquisitionDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Acquisition Date'**
  String get acquisitionDateLabel;

  /// No description provided for @acquisitionPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Acquisition Price'**
  String get acquisitionPriceLabel;

  /// No description provided for @invalidPriceError.
  ///
  /// In en, this message translates to:
  /// **'Invalid Price'**
  String get invalidPriceError;

  /// No description provided for @invalidQuantityError.
  ///
  /// In en, this message translates to:
  /// **'Invalid Quantity'**
  String get invalidQuantityError;

  /// No description provided for @longTermInLabel.
  ///
  /// In en, this message translates to:
  /// **'LT in {duration}'**
  String longTermInLabel(String duration);

  /// No description provided for @updateAction.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateAction;

  /// Section header in Add Investment
  ///
  /// In en, this message translates to:
  /// **'Recurring Investment'**
  String get recurringInvestmentHeader;

  /// Label for recurring amount field
  ///
  /// In en, this message translates to:
  /// **'Monthly Recurring Amount'**
  String get recurringAmountLabel;

  /// Label for next recurring date picker
  ///
  /// In en, this message translates to:
  /// **'Next Recurring Date'**
  String get nextRecurringDateLabel;

  /// Label for pause recurring switch
  ///
  /// In en, this message translates to:
  /// **'Pause Recurring Payments'**
  String get pauseRecurringLabel;

  /// Header for upcoming investments dashboard
  ///
  /// In en, this message translates to:
  /// **'Upcoming Commitments'**
  String get upcomingCommitmentsHeader;

  /// No description provided for @premiumSectionTile.
  ///
  /// In en, this message translates to:
  /// **'Premium Features'**
  String get premiumSectionTile;

  /// No description provided for @subscriptionStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscription Status'**
  String get subscriptionStatusLabel;

  /// No description provided for @premiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium Active'**
  String get premiumActive;

  /// No description provided for @liteActive.
  ///
  /// In en, this message translates to:
  /// **'Lite Active (Ad-Free)'**
  String get liteActive;

  /// No description provided for @freeTierActive.
  ///
  /// In en, this message translates to:
  /// **'Free Tier'**
  String get freeTierActive;

  /// No description provided for @upgradeButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgradeButtonLabel;

  /// No description provided for @upgradeToPremiumLabel.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get upgradeToPremiumLabel;

  /// No description provided for @expiresOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires on: {date}'**
  String expiresOnLabel(String date);

  /// No description provided for @expiresNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get expiresNever;

  /// No description provided for @selectRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Cloud Region'**
  String get selectRegionTitle;

  /// No description provided for @selectRegionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose where your data will be stored. This choice won\'t change after the first sync.'**
  String get selectRegionDescription;

  /// No description provided for @premiumFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Features'**
  String get premiumFeaturesTitle;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get premiumTitle;

  /// No description provided for @premiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock the full potential of Samriddhi Flow'**
  String get premiumSubtitle;

  /// No description provided for @featureCloudSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Backup & Sync'**
  String get featureCloudSyncTitle;

  /// No description provided for @featureCloudSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Securely back up your data and sync across multiple devices.'**
  String get featureCloudSyncDesc;

  /// No description provided for @featureAdFreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Ad-Free experience'**
  String get featureAdFreeTitle;

  /// No description provided for @featureAdFreeDesc.
  ///
  /// In en, this message translates to:
  /// **'Focus on your finances without any interruptions.'**
  String get featureAdFreeDesc;

  /// No description provided for @upgradeToPremiumAction.
  ///
  /// In en, this message translates to:
  /// **'UPGRADE TO PREMIUM'**
  String get upgradeToPremiumAction;

  /// No description provided for @buyLiteAction.
  ///
  /// In en, this message translates to:
  /// **'GET LITE (AD-FREE)'**
  String get buyLiteAction;

  /// No description provided for @buyPremiumAction.
  ///
  /// In en, this message translates to:
  /// **'GET PREMIUM (FULL ACCESS)'**
  String get buyPremiumAction;

  /// No description provided for @alreadyPremiumTitle.
  ///
  /// In en, this message translates to:
  /// **'You are a Premium User!'**
  String get alreadyPremiumTitle;

  /// No description provided for @alreadyPremiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your support. You have access to all features.'**
  String get alreadyPremiumSubtitle;

  /// No description provided for @noThanksButton.
  ///
  /// In en, this message translates to:
  /// **'No, thanks'**
  String get noThanksButton;

  /// No description provided for @confirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmButton;

  /// No description provided for @serverRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Cloud Backup Region'**
  String get serverRegionLabel;

  /// No description provided for @serverRegionDesc.
  ///
  /// In en, this message translates to:
  /// **'Manual selection of backup storage zone'**
  String get serverRegionDesc;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override // coverage:ignore-line
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(// coverage:ignore-line
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
