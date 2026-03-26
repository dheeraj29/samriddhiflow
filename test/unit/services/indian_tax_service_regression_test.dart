import 'helpers/indian_tax/advance_tax_interest_edge.dart' as advance_tax_edge;
import 'helpers/indian_tax/advance_tax_tds.dart' as advance_tax_tds;
import 'helpers/indian_tax/agri_income_shortfall.dart' as agri_shortfall;
import 'helpers/indian_tax/other_income_subtype_categorization.dart'
    as other_income_subtypes;
import 'helpers/indian_tax/salary_advance_tax_repro.dart'
    as salary_advance_tax_repro;
import 'helpers/indian_tax/tax_shortfall.dart' as tax_shortfall;
import 'helpers/indian_tax/tax_slab_fallback.dart' as tax_slab_fallback;

void main() {
  salary_advance_tax_repro.registerSalaryAdvanceTaxReproTests();
  other_income_subtypes.registerOtherIncomeSubtypeCategorizationTests();
  agri_shortfall.registerAgriIncomeShortfallTests();
  tax_slab_fallback.registerTaxSlabFallbackTests();
  tax_shortfall.registerTaxShortfallTests();
  advance_tax_edge.registerAdvanceTaxInterestEdgeTests();
  advance_tax_tds.registerAdvanceTaxAndGeneratedTdsTests();
}
