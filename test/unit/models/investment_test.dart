import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/investment.dart';

void main() {
  group('Investment Model Tests', () {
    test('Profit/Loss calculation returns correct values', () {
      final inv = Investment.create(
        name: 'Apple',
        codeName: 'AAPL',
        type: InvestmentType.stock,
        acquisitionDate: DateTime(2023, 1, 1),
        acquisitionPrice: 150.0,
        quantity: 10,
        currentPrice: 175.0,
      );

      expect(inv.investedValue, 1500.0);
      expect(inv.currentValuation, 1750.0);
      expect(inv.unrealizedGain, 250.0);

      final lossInv = inv.copyWith(currentPrice: 125.0);
      expect(lossInv.unrealizedGain, -250.0);
    });

    test('LTCG logic respects custom thresholds', () {
      final oneYearInv = Investment.create(
        name: 'Test',
        type: InvestmentType.stock,
        acquisitionDate: DateTime.now().subtract(const Duration(days: 400)),
        acquisitionPrice: 100,
        quantity: 1,
        customLongTermThresholdYears: 1,
      );
      expect(oneYearInv.isLongTerm, isTrue);

      final twoYearInv = oneYearInv.copyWith(customLongTermThresholdYears: 2);
      expect(twoYearInv.isLongTerm, isFalse);
    });

    test('copyWith correctly updates fields including codeName', () {
      final inv = Investment.create(
        name: 'Test',
        type: InvestmentType.stock,
        acquisitionDate: DateTime.now(),
        acquisitionPrice: 100,
        quantity: 1,
      );

      final updated = inv.copyWith(codeName: 'TICKER', remarks: 'Updated');
      expect(updated.codeName, 'TICKER');
      expect(updated.remarks, 'Updated');
      expect(updated.name, 'Test'); // Unchanged
    });
  });
}
