import 'package:samriddhi_flow/services/storage_service.dart';

class NotificationService {
  final StorageService _storage;

  NotificationService(this._storage);

  Future<void> init() async {
    // Native notifications removed as per user request (Windows/Android).
    // In-app nudges only.
  }

  /// Checks for inactivity and upcoming loan maturities
  /// Returns a list of "Nudges" (messages) to show in-app
  Future<List<String>> checkNudges() async {
    final nudges = <String>[];

    // 1. Inactivity Check
    final lastLogin = _storage.getLastLogin();
    final now = DateTime.now();
    await _storage.setLastLogin(now); // Update for next time

    if (lastLogin != null) {
      final daysSince = now.difference(lastLogin).inDays;
      final threshold = _storage.getInactivityThresholdDays();
      if (daysSince > threshold) {
        nudges.add(
            "Welcome back! You haven't checked your budget in $daysSince days.");
      }
    }

    // 2. Loan Maturities
    final loans = _storage.getLoans();
    final maturityWarningDays = _storage.getMaturityWarningDays();

    for (final loan in loans) {
      if (loan.remainingPrincipal > 0) {
        final maturityDate =
            loan.startDate.add(Duration(days: loan.tenureMonths * 30));
        final daysToMaturity = maturityDate.difference(now).inDays;

        if (daysToMaturity >= 0 && daysToMaturity <= maturityWarningDays) {
          nudges
              .add("Loan '${loan.name}' is maturing in $daysToMaturity days!");
        } else if (daysToMaturity < 0) {
          nudges.add(
              "Loan '${loan.name}' is OVERDUE by ${daysToMaturity.abs()} days!");
        }
      }
    }

    return nudges;
  }
}
