import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/widgets/smart_currency_text.dart';

class MockCurrencyFormatNotifier extends CurrencyFormatNotifier {
  final bool initial;
  MockCurrencyFormatNotifier(this.initial);

  @override
  bool build() => initial;

  void toggle() => state = !state;
}

void main() {
  testWidgets('SmartCurrencyText toggles between compact and extended',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SmartCurrencyText(
            value: 1234567,
            locale: 'en_IN',
            initialCompact: false,
          ),
        ),
      ),
    ));

    // Non-compact: ₹12,34,567.00
    expect(find.textContaining('12,34,567'), findsOneWidget);

    // Tap to toggle
    await tester.tap(find.byType(SmartCurrencyText));
    await tester.pumpAndSettle();

    // Compact (en_IN): ₹12.35L
    expect(find.textContaining('₹12.35L'), findsOneWidget);

    // Tap again
    await tester.tap(find.byType(SmartCurrencyText));
    await tester.pumpAndSettle();
    expect(find.textContaining('12,34,567'), findsOneWidget);
  });

  testWidgets('SmartCurrencyText handles prefix and suffix', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SmartCurrencyText(
            value: 100,
            locale: 'en_US',
            prefix: 'Start: ',
            suffix: ' End',
            initialCompact: false,
          ),
        ),
      ),
    ));

    expect(find.text('Start: \$100.00 End'), findsOneWidget);
  });

  testWidgets('SmartCurrencyText reacts to global provider', (tester) async {
    final formatNotifier = MockCurrencyFormatNotifier(false);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currencyFormatProvider.overrideWith(() => formatNotifier),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SmartCurrencyText(
            value: 5000000,
            locale: 'en_IN',
            // initialCompact is null, should default to global
          ),
        ),
      ),
    ));

    // Global is false
    expect(find.textContaining('50,00,000'), findsOneWidget);

    // Toggle global
    formatNotifier.toggle();
    await tester.pumpAndSettle();

    // Now should be compact: ₹50L
    expect(find.textContaining('₹50L'), findsOneWidget);
  });

  testWidgets('SmartCurrencyText didUpdateWidget resets local toggle',
      (tester) async {
    late StateSetter setInternalState;
    bool compact = false;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setInternalState = setState;
            return Scaffold(
              body: SmartCurrencyText(
                value: 1000,
                locale: 'en_US',
                initialCompact: compact,
              ),
            );
          },
        ),
      ),
    ));

    expect(find.text('\$1,000.00'), findsOneWidget);

    // Toggle locally
    await tester.tap(find.byType(SmartCurrencyText));
    await tester.pumpAndSettle();
    expect(find.text('\$1K'), findsOneWidget);

    // Update parent to force true
    setInternalState(() {
      compact = true;
    });
    await tester.pumpAndSettle();
    expect(find.text('\$1K'), findsOneWidget); // Stays compact

    // Update parent to force false
    setInternalState(() {
      compact = false;
    });
    await tester.pumpAndSettle();
    expect(find.text('\$1,000.00'), findsOneWidget); // Resets to extended
  });
}
