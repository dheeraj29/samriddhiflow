import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CurrencySelectionDialog extends StatelessWidget {
  const CurrencySelectionDialog({super.key});

  final List<String> currencies = const ['\$', '€', '£', '₹', '¥', '₽'];

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Select Currency'),
      children: currencies
          .map((c) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(c,
                      style: AppTheme.offlineSafeTextStyle.copyWith(
                        fontSize: 18,
                      )),
                ),
              ))
          .toList(),
    );
  }
}
