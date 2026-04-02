import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:samriddhi_flow/widgets/taxes/amount_display_toggle.dart';

void main() {
  testWidgets('AmountDisplayToggle toggles currencyFormatProvider',
      (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AmountDisplayToggle(
              title: 'Test Toggle',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    // Initial state check

    expect(find.text('Test Toggle'), findsOneWidget);

    expect(find.byIcon(Icons.compress),
        findsOneWidget); // Default is true (compact)

    // Tap to toggle

    await tester.tap(find.byType(AmountDisplayToggle));

    await tester.pumpAndSettle();

    expect(tapped, isTrue);

    expect(find.byIcon(Icons.expand), findsOneWidget); // Now false (expanded)

    // Tap again to toggle back

    await tester.tap(find.byType(AmountDisplayToggle));

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.compress), findsOneWidget);
  });
}
