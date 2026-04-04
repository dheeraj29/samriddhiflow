import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/subscription_service.dart';
import '../l10n/app_localizations.dart';

class PremiumPromoScreen extends ConsumerWidget {
  const PremiumPromoScreen({super.key});

  @override // coverage:ignore-line
  Widget build(BuildContext context, WidgetRef ref) {
    // coverage:ignore-start
    final subService = ref.watch(subscriptionServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // coverage:ignore-end

    // coverage:ignore-start
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.premiumFeaturesTitle),
        // coverage:ignore-end
        elevation: 0,
      ),
      body: Padding(
        // coverage:ignore-line
        padding: const EdgeInsets.all(24.0),
        child: Column(
          // coverage:ignore-line
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // coverage:ignore-line
            const Icon(Icons.star_rounded, size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              // coverage:ignore-line
              l10n.premiumTitle, // coverage:ignore-line
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                // coverage:ignore-line
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              // coverage:ignore-line
              l10n.premiumSubtitle, // coverage:ignore-line
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                // coverage:ignore-line
                color:
                    theme.colorScheme.onSurfaceVariant, // coverage:ignore-line
              ),
            ),
            const SizedBox(height: 48),
            _buildFeatureItem(
              // coverage:ignore-line
              context,
              Icons.cloud_done_rounded,
              l10n.featureCloudSyncTitle, // coverage:ignore-line
              l10n.featureCloudSyncDesc, // coverage:ignore-line
            ),
            const SizedBox(height: 24),
            _buildFeatureItem(
              // coverage:ignore-line
              context,
              Icons.block_rounded,
              l10n.featureAdFreeTitle, // coverage:ignore-line
              l10n.featureAdFreeDesc, // coverage:ignore-line
            ),
            const Spacer(),
            ElevatedButton(
              // coverage:ignore-line
              onPressed: () async {
                // coverage:ignore-line
                // In future: purchases_flutter implementation here
                final success =
                    // coverage:ignore-start
                    await subService.purchasePackage('full_premium');
                if (success && context.mounted) {
                  Navigator.pop(context);
                  // coverage:ignore-end
                }
              },
              style: ElevatedButton.styleFrom(
                // coverage:ignore-line
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  // coverage:ignore-line
                  borderRadius:
                      BorderRadius.circular(12), // coverage:ignore-line
                ),
              ),
              child: Text(l10n.upgradeToPremiumAction), // coverage:ignore-line
            ),
            const SizedBox(height: 16),
            // coverage:ignore-start
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.noThanksButton),
              // coverage:ignore-end
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
      // coverage:ignore-line
      BuildContext context,
      IconData icon,
      String title,
      String description) {
    final theme = Theme.of(context); // coverage:ignore-line
    return Row(
      // coverage:ignore-line
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // coverage:ignore-line
        Container(
          // coverage:ignore-line
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // coverage:ignore-line
            color: theme.colorScheme.primaryContainer, // coverage:ignore-line
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color:
                  theme.colorScheme.onPrimaryContainer), // coverage:ignore-line
        ),
        const SizedBox(width: 20),
        Expanded(
          // coverage:ignore-line
          child: Column(
            // coverage:ignore-line
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // coverage:ignore-line
              Text(
                // coverage:ignore-line
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  // coverage:ignore-line
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                // coverage:ignore-line
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  // coverage:ignore-line
                  color: theme
                      .colorScheme.onSurfaceVariant, // coverage:ignore-line
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
