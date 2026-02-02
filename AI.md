# Samriddhi Flow - Project Documentation

## 1. Project Overview
**Samriddhi Flow** is a premium personal finance and smart budgeting PWA designed for the Indian market (and global applicability). It emphasizes aesthetic excellence ("wow" factor), data privacy (local-first), and comprehensive financial tracking.

**Current Version:** v1.21.0

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
    end

    subgraph "Services"
        Excel[ExcelService (Import/Export)]
        File[FileService (File Picker)]
        Theme[ThemeService]
        Storage
        CloudSync[CloudSyncService]
    end

    Providers --> Excel
    Providers --> File
    Providers --> CloudSync
```

### Key Components

*   **State Management:** `flutter_riverpod` used for reactive state, dependency injection, and business logic separation.
*   **Storage:** `hive_ce` (Community Edition) for fast, key-value storage. Adapters generated via `build_runner`.
*   **UI Framework:** Flutter Web (WASM-ready).
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

### C. Import/Export (Excel)
*   **Engine:** `excel` package.
*   **Logic:**
    *   **Strict Column Matching:** Uses specific aliases (e.g., `Holding Tenure (Months)`) to map user headers to internal fields.
    *   **Two-Pass Detection:** 1. Exact Match (Priority) -> 2. Substring Match (Fallback).
    *   **Self-Correction:** Prevents mapping errors between "Account" and "To Account".

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

## 4. Current Status (v1.22.0)
*   **Stable:** Core financial logic, cloud sync, and security features are fully operational.
*   **Recent Updates (v1.22.0):**
    *   **Recurring Payment Skip**: Added a "Skip" option in the Reminders screen to advance cycles without recording transactions.
    *   **First Working Day Logic**: Implemented "First Working Day of Month" schedule type with full holiday/weekend awareness.
    *   **Month Jump Fix**: Resolved a critical bug where Jan 30 payments would skip February and jump to March.
    *   **Test Environment**: Fixed `dart:js_interop` crashes during local testing via conditional imports.
    *   **UI Stability**: Fixed `AppLockScreen` overflow and improved iOS PWA Privacy Screen reliability.
    *   **Unified UI Components**: Created shared `TransactionListItem` widget and refactored Dashboard, Transactions, and Recycle Bin screens for consistent UI/UX.
    *   **Logic Centralization**:
        *   Moved Credit Card unbilled calculation to `BillingHelper.calculateUnbilledAmount`.
        *   Moved Loan remaining tenure logic to `LoanService.calculateRemainingTenure`.
    *   **Credit Card Fix**: Standardized the **Billing Day** as a Billed day (inclusive); centralized rollover logic in `accountsProvider` to ensure zero-gap processing across all profiles.
    *   **Backup Persistence**: Updated Cloud Sync to preserve all app settings (rollover timestamps, budget, etc.).
    *   **Code Quality**: Applied project-wide `dart fix` and synchronized `AI.md` with active project state.

## 5. Build Instructions
Run: `flutter build web --no-web-resources-cdn --release`
*   **Note:** This command ensures that web resources are bundled locally for full offline capability.

## 6. Testing
Execute: `flutter test`
Archive 100% coverage target for core business logic and critical UI screens.

## 7. Future Roadmap
*   **Tax Engine:** Tax calculation and assessment features (Indian Regime).
