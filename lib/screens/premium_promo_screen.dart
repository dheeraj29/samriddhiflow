import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/subscription_service.dart';
import '../l10n/app_localizations.dart';

class PremiumPromoScreen extends ConsumerWidget {
  const PremiumPromoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subService = ref.watch(subscriptionServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tier = subService.getTier();
    final isPremium = tier == SubscriptionTier.premium;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.premiumFeaturesTitle),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.star_rounded, size: 80, color: Colors.amber),
              const SizedBox(height: 24),
              _buildHeader(l10n, theme, isPremium),
              const SizedBox(height: 32),
              _buildFeatures(l10n, context),
              const SizedBox(height: 32),
              if (!isPremium)
                _buildSubscriptionActions(context, l10n, subService, tier),
              const SizedBox(height: 16),
              _buildCloseButton(context, l10n, isPremium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, ThemeData theme, bool isPremium) {
    return Column(
      children: [
        Text(
          isPremium ? l10n.alreadyPremiumTitle : l10n.premiumTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isPremium ? l10n.alreadyPremiumSubtitle : l10n.premiumSubtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures(AppLocalizations l10n, BuildContext context) {
    return Column(
      children: [
        _buildFeatureItem(
          context,
          Icons.cloud_done_rounded,
          l10n.featureCloudSyncTitle,
          l10n.featureCloudSyncDesc,
        ),
        const SizedBox(height: 24),
        _buildFeatureItem(
          context,
          Icons.block_rounded,
          l10n.featureAdFreeTitle,
          l10n.featureAdFreeDesc,
        ),
      ],
    );
  }

  Widget _buildSubscriptionActions(BuildContext context, AppLocalizations l10n,
      SubscriptionService subService, SubscriptionTier tier) {
    final isLite = tier == SubscriptionTier.lite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isLite) ...[
          OutlinedButton(
            // coverage:ignore-start
            onPressed: () async {
              final success = await subService.purchasePackage('lite_ad_free');
              if (success && context.mounted) {
                Navigator.pop(context);
                // coverage:ignore-end
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.buyLiteAction),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          // coverage:ignore-start
          onPressed: () async {
            final success = await subService.purchasePackage('full_premium');
            if (success && context.mounted) {
              Navigator.pop(context);
              // coverage:ignore-end
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
              isLite ? l10n.upgradeToPremiumAction : l10n.buyPremiumAction),
        ),
      ],
    );
  }

  Widget _buildCloseButton(
      BuildContext context, AppLocalizations l10n, bool isPremium) {
    return TextButton(
      onPressed: () => Navigator.pop(context), // coverage:ignore-line
      child: Text(isPremium ? l10n.closeAction : l10n.noThanksButton),
    );
  }

  Widget _buildFeatureItem(
      BuildContext context, IconData icon, String title, String description) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
