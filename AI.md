# Samriddhi Flow - Project Documentation

## 1. Project Overview
**Samriddhi Flow** is a premium personal finance and smart budgeting PWA designed for the Indian market (and global applicability). It emphasizes aesthetic excellence ("wow" factor), data privacy (local-first), and comprehensive financial tracking.

**Current Version:** v2.6.0

## 2. Architecture

### High-Level Architecture
Samriddhi Flow follows a **Local-First, Offline-Capable PWA** architecture.

```mermaid
graph TD
    User[User] -->|Interacts| UI[Flutter UI Layer]
    UI -->|Reads/Writes| Providers[Riverpod State Management]
    Providers -->|Persists| Storage[StorageService (Hive)]
    Storage -->|Syncs| IDB[IndexedDB (Web)]
    
    subgraph "Core Data Models"
        Profile
        Account
        Transaction[Transaction / LoanTransaction]
        Loan
        Category
        TaxRules
        TaxYearData
        InsurancePolicy
        LendingRecord
    end

    subgraph "Services"
        JSON[JsonDataService (Backup/Restore)]
        File[FileService (File Picker)]
        Theme[ThemeService]
        Storage
        CloudSync[CloudSyncService]
        TaxConfig[TaxConfigService]
        TaxEngine[TaxStrategy / IndianTaxService]
    end

    Providers --> JSON
    Providers --> File
    Providers --> CloudSync
    Providers --> TaxConfig
    Providers --> TaxEngine
```

### Key Components

*   **State Management:** `flutter_riverpod` used for reactive state, dependency injection, and business logic separation.
*   **Storage:** `hive_ce` (Community Edition) for fast, key-value storage. Adapters generated via `build_runner`.
*   **UI Framework:** Flutter Web (WASM-ready).
*   **Tax Engine:** `IndianTaxService` (implementing `TaxStrategy`) provides salary breakdown, TDS estimation, and multi-year tax liability calculation. `TaxConfigService` manages slab rules and configuration persistence.
*   **Lending Logic:** `LendingNotifier` manages the state of peer-to-peer debt, providing real-time aggregation of total lent and borrowed amounts.
*   **Design System:** Custom "Premium" aesthetic using gradients, glassmorphism, and smooth animations.

## 3. Data Flow & Features

### A. Accounts & Credit Cards
*   **Types:** Savings, Credit Card, Wallet.
*   **Credit Logic:**
    *   Tracks `Credit Limit`, `Billing Cycle`, `Due Date`.
    *   **Auto-Rollover:** Centrally triggered via `accountsProvider` on app launch. Detects billing cycle completion across all profiles.
    *   **Inclusive Billing:** Transactions on the billing day (e.g., the 28th) are treated as "Billed," while the new cycle starts on the 29th.
    *   **Unbilled Usage:** Calculated dynamically based on transactions strictly after the current cycle start.
    *   **Aggregated View:** Dashboard shows Total Credit Limit, Total Usage, and Utilization % across all cards.

### B. Transactions
*   **Types:** Income, Expense, Transfer.
*   **Logic:**
    *   `ImpactCalculator` determines how a transaction affects Account/Loan balances.
    *   **Recurring:** Supports recurring patterns (Daily, Monthly, etc) with holiday-aware adjustments.
    *   **Loans:** EMI payments are transactions linked to Loan entities.

### C. Backup & Restore (JSON/ZIP)
*   **Engine:** `archive` package & `json` encoding.
*   **Logic:**
    *   **Snapshots:** Generates a ZIP package containing separate JSON files for each data entity (Accounts, Transactions, Loans, etc.).
    *   **Full Restore:** Restoration involves a full wipe and replace cycle to ensure consistent data state across platforms.
    *   **Sanitization:** Automatically cleans non-finite numbers during the export process.

### D. Cloud Sync & Backup
*   **Mechanism:** Snapshot Synchronization.
*   **Backend:** Firebase Firestore (NoSQL).
*   **How it Works:** 
    *   **Sync:** Serializes the entire local database (Accounts, Loans, Transactions, Categories, Profiles) and **all App Settings** (including rollover timestamps) into a single object in Firestore.
    *   **Restore:** Fetches the latest snapshot from Firestore, **wipes the local database entirely**, and repopulates it. The inclusion of settings ensures that background processes (like CC Rollovers) don't duplicate or skip periods after a restore.
    *   **Atomic Restoration:** Restored data handles transaction impacts atomically to maintain balance integrity.

### E. App Stability & Privacy
*   **App Lock:** Supports PIN protection with a 1-minute grace period and "Forgot PIN" recovery via Firebase re-authentication.
*   **Privacy Screen:** Immediately obscures app content in the app switcher. Uses browser-level `blur` events on iOS PWA for maximum reliability.
*   **Layout Safety:** UI components are designed with `LayoutBuilder` and `SingleChildScrollView` to prevent overflow errors on various device sizes and orientations.

### F. Loan Logic & Part Payments
*   **Interest Calculation:** Uses **Daily Reducing Balance** method. Interest is calculated exactly for the number of days between payments.
*   **Part Payment (Prepayment):**
    *   **Logic:** When a part payment is made, it is immediately deducted from the `Remaining Principal`.
    *   **Option 1: Reduce Tenure:** EMI remains the same; loan pays off faster.
    *   **Option 2: Reduce EMI:** Tenure remains the same; EMI is recalculated.
*   **Impact:** EMI/Prepayment transactions are linked to user accounts to maintain synchronized balances.

### G. Tax Engine & Precision
*   **Precision Guard:** Uses `1.0e15` as a finite substitute for `double.infinity` in Tax Slabs to prevent precision loss in Hive (JavaScript `Number.MAX_SAFE_INTEGER` limitation) and backup serialization failures.
*   **Salary Breakdown Logic:**
    *   **Scoped Taxing:** The monthly breakdown and TDS estimation use a **Salary-Only tax projection**, excluding non-salary losses/incomes for accurate payroll simulation.
    *   **Frequency-Aware:** Independent components (Bonuses, LTA, Deductions) respect their defined payout frequencies (Monthly, Quarterly, Annual, Custom).
    *   **Marginal Tax:** Non-monthly incomes are taxed using marginal tax calculation in the specific month received.
*   **Sanitization:** `JsonDataService` and `CloudSyncService` sanitize non-finite numbers (`Infinity`, `NaN`) during export/sync to ensure data integrity.

### H. Lending & Borrowing
*   **Tracking:** Manages money lent to or borrowed from individuals.
*   **Status:** Records can be marked as `Closed` with a specific date once settled.
*   **Aggregated View:** Provided via `totalLentProvider` and `totalBorrowedProvider` for effective debt management.
*   **Profile Scoping:** Automatically filtered by the active profile.

## 4. Current Status (v2.6.0)
*   **Stable:** Core financial logic, cloud sync, tax engine, and security features are fully operational.
*   **Recent Updates (v2.6.0):**
    *   **Tax Engine Refinement**: Implemented frequency-based payouts for independent components and salary-only tax scoping for breakdown/TDS estimation.
    *   **Hive Precision Fix**: Resolved Hive "precision loss" warnings on Web by replacing `double.infinity` with finite constants.
    *   **Data Sanitization**: Added automatic sanitization for non-finite numbers during JSON serialization and cloud sync.
    *   **Enhanced Exemption UI**: Added full frequency and custom month controls to the Custom Exemption dialog.
*   **Recent Updates (v1.22.0):**
    *   **Recurring Payment Skip**: Added a "Skip" option in the Reminders screen to advance cycles without recording transactions.
    *   **First Working Day Logic**: Implemented "First Working Day of Month" schedule type with full holiday/weekend awareness.
    *   **Month Jump Fix**: Resolved a critical bug where Jan 30 payments would skip February and jump to March.
    *   **Test Environment**: Fixed `dart:js_interop` crashes during local testing via conditional imports.
    *   **UI Stability**: Fixed `AppLockScreen` overflow and improved iOS PWA Privacy Screen reliability.
    *   **Unified UI Components**: Created shared `TransactionListItem` widget and refactored Dashboard, Transactions, Loans, and Recycle Bin screens for consistent UI/UX.
    *   **Logic Centralization**:
        *   Moved Credit Card unbilled calculation to `BillingHelper.calculateUnbilledAmount`.
        *   Moved Loan remaining tenure logic to `LoanService.calculateRemainingTenure`.
    *   **Credit Card Fix**: Standardized the **Billing Day** as a Billed day (inclusive); centralized rollover logic in `accountsProvider` to ensure zero-gap processing across all profiles.
    *   **Backup Persistence**: Updated Cloud Sync to preserve all app settings (rollover timestamps, budget, etc.).
    *   **Refactoring Services**: Deduplicated logic in `StorageService` and `JsonDataService` (Generic getters, Impact logic).
    *   **Test Coverage Push**: Achieved high coverage for critical screens:
        *   `RepairService` (Job Logic)
        *   `AddTransactionScreen` (Transfer/Recurring flows)
        *   `TransactionsScreen` (Filtering)
        *   `RemindersScreen` (Recurring Interactions)
        *   `DashboardScreen` (Net Worth, Recent Txns)
        *   `Loan Actions` (Top-up, Part Payment, Recalculate)
    *   **UI Restoration**: Restored "Compact/Extended" number toggle in `AccountsScreen`.
    *   **Code Quality**: Applied project-wide `dart fix` and synchronized `AI.md` with active project state.

## 5. Build Instructions
Run: `build_pwa.bat`
*   **Note:** This command ensures that web resources are bundled locally for full offline capability.

## 6. Testing
Execute: `flutter test`
Target: **100% coverage** for core business logic and critical UI screens.

### Coverage Rules
1.  **Maintenance**: Every modification MUST maintain or increase the coverage percentage of the modified files.
2. **Baselines**: The current project coverage baseline is **72.87%** (Filtered). Every modification MUST maintain or increase the coverage percentage of the modified files.
3.  **Sanity**: Unit tests MUST be consolidated (avoid `_unit_test.dart` fragmentation). Merge redundant test files immediately.
4.  **Mocks**: Use `test_mocks.dart` for shared service and provider mocks. Use `setupStorageDefaults(mockStorage)` to apply standard stubs and fallbacks.
5.  **Aesthetics**: Tests involving charts (PieChart) should use explicit `tester.pump(Duration)` instead of `pumpAndSettle` to avoid animation timeouts.