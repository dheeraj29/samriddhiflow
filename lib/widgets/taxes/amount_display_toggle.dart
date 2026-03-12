import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';

class AmountDisplayToggle extends ConsumerWidget {
  final String title;
  final VoidCallback? onTap;

  const AmountDisplayToggle({
    super.key,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCompact = ref.watch(currencyFormatProvider);

    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: InkWell(
        onTap: () {
          ref.read(currencyFormatProvider.notifier).value = !useCompact;
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Icon(
                useCompact ? Icons.compress : Icons.expand,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
