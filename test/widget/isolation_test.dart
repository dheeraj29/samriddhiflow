import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Row with spaceBetween in FittedBox in Column with Spacer',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Left'),
                  SizedBox(width: 10),
                  Text('Right'),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Left'), findsOneWidget);
  });
}
