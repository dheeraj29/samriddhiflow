import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';

void main() {
  group('SalaryDetails Mutation Safety', () {
    test('Can add to history when initialized from immutable const list', () {
      // 1. Emulate a new/empty year which uses a const [] for history
      const initialSalary = SalaryDetails(
        history: [], // This is a constant empty list in Dart
      );

      // 2. This is the pattern used in the fix: create a mutable copy from the potentially immutable source
      final mutableHistory = List<SalaryStructure>.from(initialSalary.history);

      // 3. Adding to this should NOT throw 'Unsupported operation: add'
      final newItem = SalaryStructure(
        id: '1',
        effectiveDate: DateTime(2024, 4, 1),
        monthlyBasic: 50000,
      );

      expect(() => mutableHistory.add(newItem), returnsNormally);
      expect(mutableHistory.length, 1);
    });

    test('Directly adding to const history throws', () {
      const initialSalary = SalaryDetails(
        history: [],
      );

      // Verification of why the bug occurred:
      // Direct mutation of a const list throws.
      expect(
          () => initialSalary.history.add(SalaryStructure(
                id: '1',
                effectiveDate: DateTime(2024, 4, 1),
              )),
          throwsA(isA<UnsupportedError>()));
    });
  });
}
