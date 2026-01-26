# Samriddhi Flow - Project Documentation

## 1. Project Overview
**Samriddhi Flow** is a premium personal finance and smart budgeting PWA designed for the Indian market (and global applicability). It emphasizes aesthetic excellence ("wow" factor), data privacy (local-first), and comprehensive financial tracking.

**Current Version:** v1.7.0

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
    end

    Providers --> Excel
    Providers --> File
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
    *   **Auto-Rollover:** Detects billing cycle end and snapshots statement balance.
    *   **Unbilled Usage:** Calculated dynamically based on transactions after the last cycle start.
    *   **Aggregated View:** Dashboard shows Total Credit Limit, Total Usage, and Utilization % across all cards.

### B. Transactions
*   **Types:** Income, Expense, Transfer.
*   **Logic:**
    *   `ImpactCalculator` determines how a transaction affects Account/Loan balances.
    *   **Recurring:** Supports recurring patterns (Daily, Monthly, etc).
    *   **Loans:** EMI payments are transactions linked to Loan entities.

### C. Import/Export (Excel)
*   **Engine:** `excel` package.
*   **Logic:**
    *   **Strict Column Matching:** Uses specific aliases (e.g., `Holding Tenure (Months)`) to map user headers to internal fields.
    *   **Two-Pass Detection:** 1. Exact Match (Priority) -> 2. Substring Match (Fallback).
    *   **Self-Correction:** Errors like "To Account" matching "Account" are prevented via strict checks.

### D. Cloud Sync & Backup
*   **Mechanism:** Snapshot Synchronization.
*   **Backend:** Firebase Firestore (NoSQL).
*   **How it Works:** 
    *   **Sync:** Serializes the entire local database (Accounts, Loans, Transactions, Settings) into a single encrypted JSON object and pushes it to the user's private document in Firestore.
    *   **Restore:** Fetches the latest snapshot from Firestore, **wipes the local database entirely**, and repopulates it with the cloud data. This ensures exact state replication across devices.
    *   **Privacy:** Data is stored under the user's authenticated UID.

### E. Loan Logic & Part Payments
*   **Interest Calculation:** Uses **Daily Reducing Balance** method. Interest is calculated exactly for the number of days between payments.
*   **Part Payment (Prepayment):**
    *   **Logic:** When a part payment is made, it is immediately deducted from the `Remaining Principal`.
    *   **Option 1: Reduce Tenure:** The EMI remains the same. Since principal is lower, the loan is paid off faster (fewer months). This maximizes interest savings.
    *   **Option 2: Reduce EMI:** The tenure (remaining months) remains the same. The EMI is recalculated to be lower based on the reduced principal.
*   **Impact:** All loan transactions (EMI, Prepayment) are automatically linked to an Account (e.g., Savings), creating a corresponding "Expense" or "Transfer" transaction in that account to keep balances in sync.

## 4. Current Status (v1.7.0)
*   **Stable:** Core features (CRUD, Loans, Import/Export, Credit Cards) are stable.
*   **Recent Updates (v1.7.0):**
    *   **Cloud Restore Fix:** Fixed balance mismatch by preventing transaction impact logic from re-running during restore.
    *   **Credit Dashboard:** Fixed "Total Usage" logic (Debt is now correctly identified as Positive Balance for Credit Cards).
    *   **Build Scripts:** Local `build_pwa.bat` integrated with Environment Variables for secrets.
    *   **Excel:** Fixed restore logic for complex templates.

## 5. Build Instructions
Run: `flutter build web --no-web-resources-cdn --release`
*   **Note:** This command ensures that web resources (like CanvasKit and fonts) are bundled locally instead of loaded from a CDN, making the app fully offline-capable.

## 6. Testing
Execute the comprehensive test suite (Unit, Widget, and Integration tests) using:
```bash
flutter test
```
To generate coverage reports, use:
```bash
flutter test --coverage
```

## 7. Future Roadmap
*   **Tax Engine:** Tax calculation and assessment features (Indian Regime).
