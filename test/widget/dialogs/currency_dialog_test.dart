import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/widgets/currency_dialog.dart';

void main() {
  testWidgets('CurrencySelectionDialog allows selecting a currency',
      (tester) async {
    String? selectedCurrency;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              selectedCurrency = await showDialog<String>(
                context: context,
                builder: (_) => const CurrencySelectionDialog(),
              );
            },
            child: const Text('Open Dialog'),
          );
        }),
      ),
    ));

    // Open Dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Select Currency'), findsOneWidget);

    // Verify Options exist
    expect(find.text('\$'), findsOneWidget);
    expect(find.text('₹'), findsOneWidget);

    // Select '₹'
    await tester.tap(find.text('₹'));
    await tester.pumpAndSettle();

    // Verify Result
    expect(selectedCurrency, '₹');

    // Verify Dialog Closed
    expect(find.text('Select Currency'), findsNothing);
  });
}
