import '../../models/taxes/tax_data.dart';

abstract class TaxStrategy {
  String get countryCode;

  /// Calculates the total tax liability for the given tax year data
  double calculateLiability(TaxYearData data);

  /// Returns a map of deduction suggestions based on the data
  Map<String, double> getDeductionSuggestions(TaxYearData data);

  /// Suggests the appropriate ITR form (e.g., ITR-1, ITR-4)
  String suggestITR(TaxYearData data);

  /// Checks if the specific insurance policy maturity is taxable
  /// returns true if taxable
  bool isInsuranceMaturityTaxable(
      double annualPremium, double sumAssured, DateTime issueDate);
}
