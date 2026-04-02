import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/investment.dart';

class MockInvestment extends Mock implements Investment {}

void main() {
  group('Investment Sorting and Filtering', () {
    final inv1 = Investment(
      id: '1',
      name: 'Old Stock',
      type: InvestmentType.stock,
      acquisitionDate: DateTime(2020, 1, 1),
      acquisitionPrice: 100,
      quantity: 10,
      currentPrice: 150, // Gain 500
      profileId: 'p1',
    );

    final inv2 = Investment(
      id: '2',
      name: 'Newer Stock Low Gain',
      type: InvestmentType.stock,
      acquisitionDate: DateTime(2021, 1, 1),
      acquisitionPrice: 100,
      quantity: 10,
      currentPrice: 110, // Gain 100
      profileId: 'p1',
    );

    final inv3 = Investment(
      id: '3',
      name: 'Newest MF High Gain',
      type: InvestmentType.mutualFund,
      acquisitionDate: DateTime(2022, 1, 1),
      acquisitionPrice: 100,
      quantity: 10,
      currentPrice: 200, // Gain 1000
      profileId: 'p1',
    );

    final inv4 = Investment(
      id: '4',
      name: 'Same Day Low Gain',
      type: InvestmentType.stock,
      acquisitionDate: DateTime(2021, 1, 1),
      acquisitionPrice: 100,
      quantity: 10,
      currentPrice: 105, // Gain 50
      profileId: 'p1',
    );

    test('Oldest First Sort Logic (Multi-level)', () {
      final list = [inv3, inv2, inv1, inv4];

      list.sort((a, b) {
        // Primary: Date ASC
        final dateComp = a.acquisitionDate.compareTo(b.acquisitionDate);
        if (dateComp != 0) return dateComp;
        // Secondary: Gain DESC
        return b.unrealizedGain.compareTo(a.unrealizedGain);
      });

      expect(list[0].id, '1'); // 2020
      expect(list[1].id, '2'); // 2021 Jan 1 (Gain 100)
      expect(list[2].id, '4'); // 2021 Jan 1 (Gain 50)
      expect(list[3].id, '3'); // 2022
    });

    test('Highest Gain Sort Logic (Multi-level)', () {
      final list = [inv1, inv2, inv3, inv4];

      list.sort((a, b) {
        // Primary: Gain DESC
        final gainComp = b.unrealizedGain.compareTo(a.unrealizedGain);
        if (gainComp != 0) return gainComp;
        // Secondary: Date ASC
        return a.acquisitionDate.compareTo(b.acquisitionDate);
      });

      expect(list[0].id, '3'); // Gain 1000
      expect(list[1].id, '1'); // Gain 500
      expect(list[2].id, '2'); // Gain 100
      expect(list[3].id, '4'); // Gain 50
    });

    test('Search Logic (Name and Ticker)', () {
      final list = [inv1, inv2, inv3];

      final searchResult1 = list
          .where((inv) =>
              inv.name.toLowerCase().contains('apple') ||
              (inv.codeName?.toLowerCase().contains('apple') ?? false))
          .toList();
      expect(searchResult1.length,
          0); // None had 'apple' in name/code in my mock setup above... wait.

      final searchResult2 = list
          .where((inv) => inv.name.toLowerCase().contains('stock'))
          .toList();
      expect(searchResult2.length, 2); // inv1 and inv2
    });

    test('Minified JSON Generation', () {
      final Map<String, double> exportData = {
        'AAPL': 150.0,
        'GOOG': 2800.0,
      };
      final jsonString = jsonEncode(exportData);
      expect(jsonString, '{"AAPL":150.0,"GOOG":2800.0}');
    });
  });
}
