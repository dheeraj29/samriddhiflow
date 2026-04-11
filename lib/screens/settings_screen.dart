import 'package:samriddhi_flow/utils/regex_utils.dart';
import '../utils/connectivity_platform.dart';
import '../utils/network_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:samriddhi_flow/core/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../feature_providers.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:samriddhi_flow/core/cloud_config.dart';

import '../theme/app_theme.dart';
import '../models/profile.dart';
import '../models/account.dart';
import 'package:uuid/uuid.dart';

import '../services/auth_service.dart';
import '../widgets/pure_icons.dart';
import 'recycle_bin_screen.dart';
import 'recurring_manager_screen.dart';
import 'holiday_manager_screen.dart';
import '../widgets/auth_wrapper.dart';
import 'login_screen.dart';
import '../utils/ui_utils.dart';
import '../widgets/common_dialogs.dart';
import '../widgets/category_manager_dialog.dart';
import '../services/repair_service.dart';
import '../widgets/region_selection_dialog.dart';
import 'premium_promo_screen.dart';
import '../services/subscription_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // App State
  bool _isUploading = false;
  bool _isDownloading = false;
  bool _isAppLockEnabled = false;
  bool _showGlobalSettings = false;
  final Map<String, bool> _expandedSections = {};

  // Internal keys for expandable sections
  static const String _secAppearance = 'Appearance';
  static const String _secDashboard = 'Dashboard Customization';
  static const String _secCloud = 'Cloud & Sync';
  static const String _secData = 'Data Management';
  static const String _secFeature = 'Feature Management';
  static const String _secProfile = 'Profile Management';
  static const String _secPreferences = 'Preferences';
  static const String _secAuth = 'Authentication';
  static const String _secSecurity = 'Security';
  static const String _secAppInfo = 'App Info';
  static const String _secPremium = 'Premium';

  static const String _secHeaderProfile = 'HeaderProfile';
  static const String _secHeaderGlobal = 'HeaderGlobal';

  final List<String> _sectionKeys = [
    _secPremium,
    _secHeaderProfile,
    _secProfile,
    _secPreferences, // Profile-specific preferences like Currency
    _secData, // Profile data like Clear Transactions

    _secHeaderGlobal,
    _secAppearance, // Global (Theme, Language)
    _secDashboard, // Global
    _secFeature, // Global
    _secCloud, // Global
    _secAuth, // Global
    _secSecurity, // Global
    _secAppInfo, // Global
  ];

  // PWA Install Prompt
  Object? _installPrompt;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _isAppLockEnabled = storage.isAppLockEnabled();

    // Default all sections to expanded
    for (var key in _sectionKeys) {
      _expandedSections[key] = true;
    }

    // Listen for PWA Install Prompt (Web Only)
    if (kIsWeb) {
      // coverage:ignore-start
      ConnectivityPlatform.listenForInstallPrompt((event) {
        setState(() {
          _installPrompt = event;
          // coverage:ignore-end
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStreamProvider).value;
    // Watch connectivity stream to force rebuild on network changes
    ref.watch(connectivityStreamProvider);
    ref.watch(isOfflineProvider);

    final l10n = AppLocalizations.of(context)!;
    final subService = ref.watch(subscriptionServiceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          IconButton(
            tooltip: l10n.expandCollapseTooltip,
            icon: Icon(
              _expandedSections.values.every((v) => v)
                  ? Icons.unfold_less
                  : Icons.unfold_more,
            ),
            onPressed: () {
              final newValue = !_expandedSections.values.every((v) => v);
              setState(() {
                for (var key in _expandedSections.keys) {
                  _expandedSections[key] = newValue;
                }
              });
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildUnifiedNavigationHeader(context, l10n, user, subService),
          const SizedBox(height: 24),
          if (!_showGlobalSettings) ...[
            _buildCollapsibleCard(
              _secPreferences,
              l10n.preferencesSection,
              _buildPreferencesSection(context, l10n),
              isProfile: true,
            ),
            _buildCollapsibleCard(
              _secData,
              l10n.profileDataSection,
              _buildProfileDataSection(context, l10n),
              isProfile: true,
            ),
            _buildCollapsibleCard(
              _secDashboard,
              l10n.dashboardCustomizationSection,
              _buildDashboardSection(l10n),
              isProfile: true,
            ),
            _buildCollapsibleCard(
              _secFeature,
              l10n.featureManagementSection,
              _buildFeatureManagementSection(context, l10n),
              isProfile: true,
            ),
          ] else ...[
            _buildCollapsibleCard(
              _secPremium,
              l10n.premiumSectionTile,
              _buildPremiumSection(l10n),
              isProfile: false,
            ),
            if (subService.isCloudSyncEnabled())
              _buildCollapsibleCard(
                _secCloud,
                l10n.cloudSyncSection,
                _buildCloudSectionContent(context, ref, user, l10n),
                isProfile: false,
              ),
            _buildCollapsibleCard(
              _secAppearance,
              l10n.appearanceSection,
              _buildAppearanceSection(l10n),
              isProfile: false,
            ),
            _buildCollapsibleCard(
              'GlobalData',
              l10n.globalDataSection,
              _buildGlobalDataSection(context, l10n),
              isProfile: false,
            ),
            if (user != null &&
                !ref.watch(isOfflineProvider) &&
                subService.isCloudSyncEnabled())
              _buildCollapsibleCard(
                _secAuth,
                l10n.authSection,
                _buildAuthSection(context, l10n),
                isProfile: false,
              ),
            _buildCollapsibleCard(
              _secSecurity,
              l10n.securitySection,
              _buildSecuritySection(context, l10n),
              isProfile: false,
            ),
            _buildCollapsibleCard(
              _secAppInfo,
              l10n.appInfoSection,
              _buildAppInfoSection(context, l10n),
              isProfile: false,
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUnifiedNavigationHeader(BuildContext context,
      AppLocalizations l10n, User? user, SubscriptionService subService) {
    final activeProfile = ref.watch(activeProfileProvider);
    final profilesAsync = ref.watch(profilesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Card with Profile Info & Manage/Switch
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        profilesAsync.maybeWhen(
                          data: (profiles) => _buildProfileDropdownRow(
                              context, profiles, activeProfile, l10n),
                          orElse: () => Text(
                            activeProfile?.name ??
                                "Guest", // coverage:ignore-line
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          l10n.profileSettingsHeader.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Toggle between Profile and Global
              Center(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Profile Settings'),
                      icon: Icon(Icons.account_circle_outlined),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Global Settings'),
                      icon: Icon(Icons.public),
                    ),
                  ],
                  selected: {_showGlobalSettings},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _showGlobalSettings = newSelection.first;
                    });
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileDropdownRow(BuildContext context, List<Profile> profiles,
      Profile? activeProfile, AppLocalizations l10n) {
    if (profiles.isEmpty) {
      return Text(
        activeProfile?.name ?? "Guest", // coverage:ignore-line
        style: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      );
    }
    return Row(
      children: [
        IconButton(
          icon: PureIcons.addCircle(color: Colors.blue, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: l10n.addNewProfileAction,
          onPressed: () => _handleAddProfile(context, l10n),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              value: activeProfile?.id,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              items: profiles.map((p) {
                return DropdownMenuItem<String>(
                  value: p.id,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (newId) {
                if (newId != null && newId != activeProfile?.id) {
                  ref.read(activeProfileIdProvider.notifier).setProfile(newId);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: PureIcons.copy(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: AppLocalizations.of(context)!.copyCategoriesTooltip,
          onPressed: () =>
              _showCopyCategoriesDialog(context, ref, activeProfile?.id ?? ''),
        ),
        if (profiles.length > 1 && activeProfile != null) ...[
          const SizedBox(width: 12),
          IconButton(
            icon: PureIcons.deleteOutlined(color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () =>
                _showDeleteProfileDialog(context, ref, activeProfile),
          ),
        ],
      ],
    );
  }

  Widget _buildCollapsibleCard(String key, String displayTitle, Widget content,
      {required bool isProfile}) {
    final isExpanded = _expandedSections[key] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withAlpha(50),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedSections[key] = !isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 22,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildThemeTile(l10n),
        const Divider(),
        _buildLanguageTile(l10n),
      ],
    );
  }

  Widget _buildThemeTile(AppLocalizations l10n) {
    final mode = ref.watch(themeModeProvider);

    IconData getThemeIcon() {
      if (mode == ThemeMode.dark) return Icons.dark_mode;
      if (mode == ThemeMode.light) return Icons.light_mode;
      return Icons.brightness_auto;
    }

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.themeModeLabel),
          leading: Icon(getThemeIcon(), color: Colors.amber),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.systemTheme),
                  icon: const Icon(Icons.brightness_auto)),
              ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l10n.lightTheme),
                  icon: const Icon(Icons.light_mode)),
              ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(l10n.darkTheme),
                  icon: const Icon(Icons.dark_mode)),
            ],
            selected: {mode},
            onSelectionChanged: (Set<ThemeMode> newSelection) {
              FocusScope.of(context).unfocus();
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(newSelection.first);
            },
            showSelectedIcon: false,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageTile(AppLocalizations l10n) {
    final locale = ref.watch(localeProvider);

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.languageLabel),
          leading: const Icon(Icons.language, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String?>(
            segments: [
              ButtonSegment(
                  value: null,
                  label: Text(l10n.systemDefault),
                  icon: const Icon(Icons.settings_suggest)),
              ButtonSegment(
                  value: 'en',
                  label: Text(l10n.englishLanguage),
                  icon: const Icon(Icons.abc)),
            ],
            selected: {locale?.languageCode},
            onSelectionChanged: (Set<String?> newSelection) {
              FocusScope.of(context).unfocus();
              ref.read(localeProvider.notifier).setLocale(newSelection.first);
            },
            showSelectedIcon: false,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumSection(AppLocalizations l10n) {
    final subService = ref.watch(subscriptionServiceProvider);
    final tier = subService.getTier();
    final isPremium = tier == SubscriptionTier.premium;
    final isLite = tier == SubscriptionTier.lite;
    final isFree = tier == SubscriptionTier.free;

    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (isPremium) {
      statusText = l10n.premiumActive;
      statusIcon = Icons.verified_user_rounded;
      statusColor = Colors.green;
    } else if (isLite) {
      statusText = l10n.liteActive;
      statusIcon = Icons.star_rounded;
      statusColor = Colors.blue;
    } else {
      statusText = l10n.freeTierActive;
      statusIcon = Icons.star_border_rounded;
      statusColor = Colors.amber;
    }

    final expiryDate = subService.getExpiryDate();
    final expiryText =
        expiryDate == null ? l10n.expiresNever : "TBD"; // use dummy for now

    final upgradeLabel =
        isLite ? l10n.upgradeToPremiumLabel : l10n.upgradeButtonLabel;

    return Column(
      children: [
        ListTile(
          title: Text(l10n.subscriptionStatusLabel),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(statusText),
              if (!isFree)
                Text(
                  l10n.expiresOnLabel(expiryText),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
          leading: Icon(statusIcon, color: statusColor, size: 28),
          trailing: (!isPremium)
              ? TextButton(
                  // coverage:ignore-start
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PremiumPromoScreen()),
                      // coverage:ignore-end
                    );
                  },
                  child: Text(upgradeLabel),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildDashboardSection(AppLocalizations l10n) {
    final config = ref.watch(dashboardConfigProvider);
    final notifier = ref.read(dashboardConfigProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.showIncomeExpenseLabel),
          subtitle: Text(AppLocalizations.of(context)!.showIncomeExpenseDesc),
          value: config.showIncomeExpense,
          onChanged: (val) {
            FocusScope.of(context).unfocus();
            notifier.updateConfig(showIncomeExpense: val);
          },
          secondary: const Icon(Icons.analytics_outlined, color: Colors.blue),
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.showBudgetLabel),
          subtitle: Text(AppLocalizations.of(context)!.showBudgetDesc),
          value: config.showBudget,
          // coverage:ignore-start
          onChanged: (val) {
            FocusScope.of(context).unfocus();
            notifier.updateConfig(showBudget: val);
            // coverage:ignore-end
          },
          secondary: const Icon(Icons.pie_chart_outline, color: Colors.green),
        ),
      ],
    );
  }

  Widget _buildCloudSectionContent(BuildContext context, WidgetRef ref,
      dynamic user, AppLocalizations l10n) {
    final region = ref.watch(cloudDatabaseRegionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context)!.serverRegionLabel),
          subtitle: Text(AppLocalizations.of(context)!.serverRegionDesc),
          leading: const Icon(Icons.public, color: Colors.blue),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                region == CloudDatabaseRegion.india ? l10n.indiaLabel : region,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500),
              ),
              const Icon(Icons.chevron_right, size: 16),
            ],
          ),
          onTap: () {
            final storage = ref.read(storageServiceProvider);
            final settings = storage.getAllSettings();
            if (settings['last_sync'] != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Region cannot be changed after data has been synced to the cloud.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              showDialog(
                context: context,
                builder: (_) => const RegionSelectionDialog(),
              );
            }
          },
        ),
        const Divider(),
        _buildCloudSection(context, user, l10n),
      ],
    );
  }

  Widget _buildCloudSection(
      BuildContext context, dynamic user, AppLocalizations l10n) {
    if (user == null) {
      return _buildNoUserCloudSection(context, l10n);
    }
    return _buildActiveCloudCard(context, user, l10n);
  }

  Widget _buildNoUserCloudSection(BuildContext context, AppLocalizations l10n) {
    if (ref.watch(isLoggedInProvider)) {
      return _buildOfflinePausedCard(context, l10n); // coverage:ignore-line
    }
    return _buildEnableCloudCard(context, l10n);
  }

  Widget _buildOfflinePausedCard(BuildContext context, AppLocalizations l10n) {
    // coverage:ignore-line
    return Container(
      // coverage:ignore-line
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      // coverage:ignore-start
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        // coverage:ignore-end
      ),
      // coverage:ignore-start
      child: Column(
        children: [
          Text(AppLocalizations.of(context)!.connectionPaused,
              style: AppTheme.offlineSafeTextStyle.copyWith(
                  // coverage:ignore-end
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface)), // coverage:ignore-line
          const SizedBox(height: 8),
          Text(
            // coverage:ignore-line
            AppLocalizations.of(context)!
                .offlineModeDesc, // coverage:ignore-line
            textAlign: TextAlign.center,
            style: AppTheme.offlineSafeTextStyle.copyWith(
                // coverage:ignore-line
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant), // coverage:ignore-line
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          // coverage:ignore-start
          ElevatedButton.icon(
            onPressed: () async {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          AppLocalizations.of(context)!.retryingConnection)),
                  // coverage:ignore-end
                );
              }
              // coverage:ignore-start
              final hasNet = await NetworkUtils.hasActualInternet();
              if (hasNet && context.mounted) {
                ref.read(isOfflineProvider.notifier).setOffline(false);
                ref.invalidate(firebaseInitializerProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      // coverage:ignore-end
                      content: Text(AppLocalizations.of(context)!
                          .internetRestored)), // coverage:ignore-line
                );
                // coverage:ignore-start
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      // coverage:ignore-end
                      content: Text(AppLocalizations.of(context)!
                          .stillOffline)), // coverage:ignore-line
                );
              }
            },
            icon: const Icon(Icons.refresh),
            // coverage:ignore-start
            label: Text(AppLocalizations.of(context)!.retryConnection),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              // coverage:ignore-end
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnableCloudCard(BuildContext context, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(AppLocalizations.of(context)!.enableCloudSync,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.enableCloudSyncDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.push(
                context, // coverage:ignore-line
                MaterialPageRoute(
                    builder: (_) =>
                        const LoginScreen())), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.loginToSetupCloud),
          )
        ],
      ),
    );
  }

  Widget _buildActiveCloudCard(
      BuildContext context, dynamic user, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        AppLocalizations.of(context)!
                            .accountLabelWithEmail(user.email ?? "User"),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    Text(AppLocalizations.of(context)!.cloudSyncActive,
                        style:
                            const TextStyle(color: Colors.green, fontSize: 12)),
                    Text(
                        AppLocalizations.of(context)!
                            .categoriesEncryptionWarning,
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : () => _backupToCloud(),
                  icon: _isUploading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : PureIcons.sync(),
                  label: Text(AppLocalizations.of(context)!.migrateSyncNow),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0175C2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDownloading ? null : () => _smartRestoreFlow(),
                  icon: _isDownloading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : PureIcons.download(),
                  label: Text(l10n.restoreButton),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0175C2),
                    side: const BorderSide(color: Color(0xFF0175C2)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDataSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context)!.recycleBinTitle),
          subtitle: Text(AppLocalizations.of(context)!.recycleBinDesc),
          leading: PureIcons.recycleBin(color: Colors.red),
          // coverage:ignore-start
          onTap: () {
            FocusScope.of(context).unfocus();
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecycleBinScreen()));
            // coverage:ignore-end
          },
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.repairDataLabel),
          subtitle: Text(AppLocalizations.of(context)!.repairDataDesc),
          leading: const Icon(Icons.build_circle, color: Colors.amber),
          onTap: () {
            FocusScope.of(context).unfocus();
            _showRepairDialog(context, l10n);
          },
        ),
      ],
    );
  }

  Widget _buildGlobalDataSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(l10n.backupDataZipLabel),
          subtitle: Text(AppLocalizations.of(context)!.backupDataZipDesc),
          leading: const Icon(Icons.archive, color: Colors.purple),
          onTap: _isUploading
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  _backupToZip();
                },
          trailing: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
        ),
        ListTile(
          title: Text(l10n.restoreDataZipLabel),
          subtitle: Text(AppLocalizations.of(context)!.restoreDataZipDesc),
          leading: const Icon(Icons.unarchive, color: Colors.teal),
          onTap: _isDownloading
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  _restoreFromZip();
                },
          trailing: _isDownloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
        ),
      ],
    );
  }

  void _showRepairDialog(BuildContext parentContext, AppLocalizations l10n) {
    final allJobs = ref.read(repairServiceProvider).jobs;
    final jobs = allJobs.where((j) => j.showInSettings).toList();
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.dataRepairTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: jobs.length,
            itemBuilder: (itemContext, index) {
              final job = jobs[index];
              return ListTile(
                title: Text(job.name),
                subtitle: Text(job.description),
                trailing: const Icon(Icons.play_arrow, color: Colors.blue),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(dialogContext);
                  _handleRepairJobTap(parentContext, job, l10n);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext), // coverage:ignore-line
              child: Text(AppLocalizations.of(context)!.closeButton)),
        ],
      ),
    );
  }

  Future<void> _handleRepairJobTap(
      BuildContext parentContext, dynamic job, AppLocalizations l10n) async {
    Map<String, dynamic>? args;

    if (job.id == 'repair_cc_balances') {
      args = await _selectCreditCardForRepair(
          parentContext); // coverage:ignore-line
      if (args == null && !context.mounted) return; // coverage:ignore-line
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(parentContext)
        .showSnackBar(SnackBar(content: Text(l10n.runningRepair)));

    try {
      final int count = await job.run(ref.reader, args: args);
      if (context.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
            SnackBar(content: Text(l10n.repairSuccessStatus(job.name, count))));
        ref.invalidate(accountsProvider);
      }
    } catch (e) {
      // coverage:ignore-start
      if (context.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(
            content: Text(l10n.repairFailedStatus(e.toString())),
            // coverage:ignore-end
            backgroundColor: Colors.red));
      }
    }
  }

  Future<Map<String, dynamic>?> _selectCreditCardForRepair(
      // coverage:ignore-line
      BuildContext parentContext) async {
    // coverage:ignore-start
    final accounts = (ref.read(accountsProvider).asData?.value ?? [])
        .where((a) => a.type == AccountType.creditCard)
        .toList();
    // coverage:ignore-end

    if (accounts.isEmpty || !context.mounted) {
      // coverage:ignore-line
      return null;
    }

    final result = await showDialog<String>(
      // coverage:ignore-line
      context: parentContext,
      // coverage:ignore-start
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.selectCreditCardTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: Padding(
              // coverage:ignore-end
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                  AppLocalizations.of(context)!
                      .allCreditCardsLabel, // coverage:ignore-line
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const Divider(),
          // coverage:ignore-start
          ...accounts.map((a) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, a.id),
                child: Padding(
                  // coverage:ignore-end
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(a.name), // coverage:ignore-line
                ),
              )),
        ],
      ),
    );

    if (result == null) return null; // Cancelled
    if (result != 'all') return {'accountId': result}; // coverage:ignore-line
    return {}; // coverage:ignore-line
  }

  Widget _buildFeatureManagementSection(
      BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(l10n.manageRecurringPaymentsAction),
          subtitle:
              Text(AppLocalizations.of(context)!.manageRecurringPaymentsDesc),
          leading: PureIcons.refresh(color: Colors.orange),
          // coverage:ignore-start
          onTap: () {
            FocusScope.of(context).unfocus();
            Navigator.push(
                // coverage:ignore-end
                context,
                MaterialPageRoute(
                    // coverage:ignore-line
                    builder: (_) =>
                        const RecurringManagerScreen())); // coverage:ignore-line
          },
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.holidayManagerTitle),
          subtitle: Text(AppLocalizations.of(context)!.holidayManagerDesc),
          leading: PureIcons.calendar(color: Colors.red),
          // coverage:ignore-start
          onTap: () {
            FocusScope.of(context).unfocus();
            Navigator.push(
                // coverage:ignore-end
                context,
                MaterialPageRoute(
                    // coverage:ignore-line
                    builder: (_) =>
                        const HolidayManagerScreen())); // coverage:ignore-line
          },
        ),
        ListTile(
          title: Text(l10n.manageCategoriesAction),
          subtitle: Text(AppLocalizations.of(context)!.manageCategoriesDesc),
          leading: PureIcons.icon(Icons.category, color: Colors.blue),
          // coverage:ignore-start
          onTap: () {
            FocusScope.of(context).unfocus();
            showDialog(
              // coverage:ignore-end
              context: context,
              builder: (context) =>
                  const CategoryManagerDialog(), // coverage:ignore-line
            );
          },
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.smartCalculatorLabel),
          subtitle: Text(AppLocalizations.of(context)!.smartCalculatorDesc),
          secondary: PureIcons.calculate(color: Colors.teal),
          value: ref.watch(smartCalculatorEnabledProvider),
          // coverage:ignore-start
          onChanged: (_) {
            FocusScope.of(context).unfocus();
            ref.read(smartCalculatorEnabledProvider.notifier).toggle();
            // coverage:ignore-end
          },
        ),
      ],
    );
  }

  void _handleAddProfile(BuildContext context, AppLocalizations l10n) {
    FocusScope.of(context).unfocus();
    CommonDialogs.showTextFieldDialog(
      context: context,
      title: AppLocalizations.of(context)!.createProfileTitle,
      labelText: AppLocalizations.of(context)!.profileNameLabel,
      hintText: l10n.enterNameHint,
      initialValue: "",
      saveLabel: AppLocalizations.of(context)!.createAction,
      onSave: (val) async {
        if (val.trim().isEmpty) return;
        final newProfile = Profile(
          id: const Uuid().v4(),
          name: val.trim(),
        );
        await ref.read(storageServiceProvider).saveProfile(newProfile);
        ref.invalidate(profilesProvider);
      },
    );
  }

  Widget _buildPreferencesSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context)!.currencyLabel),
          subtitle: Text('Current: ${() {
            final code = ref.watch(currencyProvider);
            if (code == 'en_IN') return l10n.indianRupeeLabel;
            if (code == 'en_GB') return l10n.britishPoundLabel;
            if (code == 'en_EU') return l10n.euroLabel;
            return l10n.usDollarLabel;
          }()}'),
          leading: PureIcons.money(color: Colors.green),
          onTap: () {
            FocusScope.of(context).unfocus();
            _showCurrencyDialog();
          },
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.monthlyBudgetLabel),
          subtitle: Text(
              'Limit: ${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).format(ref.watch(monthlyBudgetProvider))}'),
          leading: PureIcons.reports(color: Colors.blue),
          onTap: () {
            FocusScope.of(context).unfocus();
            CommonDialogs.showTextFieldDialog(
              context: context,
              title: AppLocalizations.of(context)!.setMonthlyBudgetTitle,
              labelText: l10n.amountLabelText,
              prefixText:
                  '${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).currencySymbol} ',
              initialValue: ref.read(monthlyBudgetProvider).toString(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegexUtils.amountExp)
              ],
              onSave: (val) {
                final amount = double.tryParse(val) ?? 0;
                ref.read(monthlyBudgetProvider.notifier).setBudget(amount);
              },
            );
          },
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.backupReminderTitle),
          subtitle: Text(
              'Remind after every ${ref.watch(backupThresholdProvider)} transactions'),
          leading: PureIcons.sync(color: Colors.purple),
          onTap: () {
            FocusScope.of(context).unfocus();
            CommonDialogs.showTextFieldDialog(
              context: context,
              title: AppLocalizations.of(context)!.backupIntervalTitle,
              labelText: l10n.numTransactionsLabel,
              helperText: l10n.defaultIntervalNote,
              initialValue: ref.read(backupThresholdProvider).toString(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSave: (val) {
                final threshold = int.tryParse(val) ?? 20;
                ref
                    .read(backupThresholdProvider.notifier)
                    .setThreshold(threshold);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAuthSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(l10n.logoutActionLabel),
          leading: PureIcons.logout(color: Colors.red),
          onTap: () {
            FocusScope.of(context).unfocus();
            UIUtils.handleLogout(context, ref);
          },
        ),
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(l10n.appLockPinTitle),
          subtitle: Text(l10n.appLockPinDesc),
          secondary: PureIcons.lock(color: Colors.grey),
          value: _isAppLockEnabled,
          onChanged: (val) async {
            FocusScope.of(context).unfocus();
            if (val) {
              _showSetPinDialog(context);
            } else {
              final pin = await _showVerifyPinDialog(context);
              if (pin != null) {
                setState(
                    () => _isAppLockEnabled = false); // coverage:ignore-line
                await ref
                    .read(storageServiceProvider)
                    .setAppLockEnabled(false); // coverage:ignore-line
              }
            }
          },
        ),
        if (_isAppLockEnabled)
          ListTile(
            title: Text(l10n.changePinTitle),
            leading: PureIcons.security(size: 20),
            // coverage:ignore-start
            onTap: () {
              FocusScope.of(context).unfocus();
              _showSetPinDialog(context);
              // coverage:ignore-end
            },
          ),
      ],
    );
  }

  Widget _buildAppInfoSection(BuildContext context, AppLocalizations l10n) {
    final user = ref.watch(authStreamProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUpdateAppTile(context),
        _buildAboutTile(context),
        if (_installPrompt != null) _buildInstallAppTile(context),
        if (user != null && !ref.watch(isOfflineProvider))
          _buildDangerZone(context),
      ],
    );
  }

  Widget _buildUpdateAppTile(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.updateApplicationTitle),
      subtitle: Text(AppLocalizations.of(context)!.updateApplicationDesc),
      leading:
          const Icon(Icons.system_update_rounded, color: Colors.blueAccent),
      // coverage:ignore-start
      onTap: () {
        FocusScope.of(context).unfocus();
        _updateApplication();
        // coverage:ignore-end
      },
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.aboutTitle),
      subtitle: const Text(AppConstants.appVersion),
      leading: PureIcons.info(size: 20),
      // coverage:ignore-start
      onTap: () {
        FocusScope.of(context).unfocus();
        UIUtils.showCommonAboutDialog(context, AppConstants.appVersion);
        // coverage:ignore-end
      },
    );
  }

  // coverage:ignore-start
  Widget _buildInstallAppTile(BuildContext context) {
    return Column(
      children: [
        // coverage:ignore-end
        const Divider(),
        // coverage:ignore-start
        ListTile(
          title: Text(AppLocalizations.of(context)!.installAppTitle),
          subtitle: Text(AppLocalizations.of(context)!.installAppDesc),
          // coverage:ignore-end
          leading: const Icon(Icons.install_mobile, color: Colors.blue),
          // coverage:ignore-start
          onTap: () async {
            if (_installPrompt != null) {
              await ConnectivityPlatform.triggerInstallPrompt(_installPrompt!);
              setState(() => _installPrompt = null);
              // coverage:ignore-end
            }
          },
        ),
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final subService = ref.watch(subscriptionServiceProvider);
    final hasCloud = subService.isCloudSyncEnabled();

    return Column(
      children: [
        const Divider(),
        UIUtils.buildSectionHeader(
            AppLocalizations.of(context)!.dangerZoneHeader,
            showDivider: false),
        if (hasCloud)
          ListTile(
            title: Text(AppLocalizations.of(context)!.clearCloudDataTitle,
                style: const TextStyle(color: Colors.orange)),
            subtitle: Text(AppLocalizations.of(context)!.clearCloudDataDesc),
            leading: PureIcons.cloudOff(size: 20, color: Colors.orange),
            onTap: _clearCloudDataFlow,
          ),
        if (hasCloud)
          ListTile(
            title: Text(AppLocalizations.of(context)!.deactivateWipeCloudTitle,
                style: const TextStyle(color: Colors.red)),
            subtitle:
                Text(AppLocalizations.of(context)!.deactivateWipeCloudDesc),
            leading: PureIcons.deleteForever(color: Colors.red),
            onTap: _deactivateAccountFlow,
          ),
        // If not cloud, we might still want a local wipe option?
        // But for now, user asked to hide these.
      ],
    );
  }

  // --- ACTIONS ---

  Future<bool> _ensureRegionSelected() async {
    final region = ref.read(cloudDatabaseRegionProvider);
    if (region.isNotEmpty) return true;

    // coverage:ignore-start
    if (!mounted) return false;
    final picked = await showDialog<bool>(
      context: context,
      builder: (_) => const RegionSelectionDialog(isMandatory: false),
      // coverage:ignore-end
    );
    return picked == true && mounted; // coverage:ignore-line
  }

  // coverage:ignore-start
  Future<void> _updateApplication() async {
    if (ref.read(isOfflineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            // coverage:ignore-end
            content: Text(AppLocalizations.of(context)!
                .internetRequiredForUpdates)), // coverage:ignore-line
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      // coverage:ignore-line
      SnackBar(
          content: Text(AppLocalizations.of(context)!
              .checkingForUpdates)), // coverage:ignore-line
    );

    final updateFound = await _checkForWebUpdate(); // coverage:ignore-line

    if (!updateFound) {
      if (mounted) await _showUpToDateDialog(); // coverage:ignore-line
      return;
    }

    if (!mounted) return; // coverage:ignore-line
    await _showUpdateConfirmDialog(); // coverage:ignore-line
  }

  Future<bool> _checkForWebUpdate() async {
    // coverage:ignore-line
    if (!kIsWeb) return false;

    // coverage:ignore-start
    if (ref.read(isOfflineProvider)) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.offlineUpdateError),
            // coverage:ignore-end
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    try {
      return await ConnectivityPlatform
              .checkForServiceWorkerUpdate() // coverage:ignore-line
          .timeout(const Duration(seconds: 5)); // coverage:ignore-line
    } catch (e) {
      return false;
    }
  }

  // coverage:ignore-start
  Future<void> _showUpToDateDialog() async {
    final wantReload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.upToDateTitle),
        content: Column(
          // coverage:ignore-end
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          // coverage:ignore-start
          children: [
            Text(AppLocalizations.of(context)!
                .upToDateMessage(AppConstants.appVersion)),
            // coverage:ignore-end
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!
                .forceReloadNote), // coverage:ignore-line
          ],
        ),
        // coverage:ignore-start
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.okButton)),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(AppLocalizations.of(context)!.forceReloadAction)),
          // coverage:ignore-end
        ],
      ),
    );

    if (wantReload == true && kIsWeb) {
      // coverage:ignore-line
      try {
        await ConnectivityPlatform
            .reloadAndClearCache(); // coverage:ignore-line
      } catch (e) {
        // Reload failure
      }
    }
  }

  // coverage:ignore-start
  Future<void> _showUpdateConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // coverage:ignore-end
        icon: const Icon(Icons.system_update_rounded,
            color: Colors.blueAccent, size: 40),
        title: Text(AppLocalizations.of(context)!
            .updateApplicationTitle), // coverage:ignore-line
        content:
            // coverage:ignore-start
            Text(AppLocalizations.of(context)!.updateApplicationConfirmMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancelButton)),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.updateAndReloadAction)),
          // coverage:ignore-end
        ],
      ),
    );

    if (confirmed == true) {
      // coverage:ignore-line
      if (kIsWeb) {
        try {
          await ConnectivityPlatform
              .reloadAndClearCache(); // coverage:ignore-line
        } catch (e) {
          // Reload failure
        }
      } else {
        // coverage:ignore-start
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              // coverage:ignore-end
              content: Text(AppLocalizations.of(context)!
                  .updateNotAvailableError)), // coverage:ignore-line
        );
      }
    }
  }

  Future<void> _backupToCloud() async {
    final l10n = AppLocalizations.of(context)!;
    if (!await _ensureRegionSelected()) return;

    final capturedPin =
        await _requirePinIfEnabled(reason: l10n.includePinInCloudBackup);
    if (capturedPin == null) return;

    if (!mounted) return;
    final passcode = await _promptForEncryptionPasscode(
        context, l10n.cloudBackupTitle, l10n.cloudBackupDesc);

    if (passcode == null) return; // User Cancelled
    final storage = ref.read(storageServiceProvider);
    final isNewDevice = storage.getSessionId() == null;

    setState(() => _isUploading = true);
    try {
      await ref
          .read(cloudSyncServiceProvider)
          .syncToCloud(passcode: passcode, appPin: capturedPin)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception(l10n.requestTimeoutError); // coverage:ignore-line
      });

      if (mounted) {
        ref.read(txnsSinceBackupProvider.notifier).reset();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.cloudSyncSuccess)));
      }
    } catch (e) {
      if (mounted) {
        // coverage:ignore-line
        await _handleCloudSessionConflict(
            e, isNewDevice, _backupToCloud); // coverage:ignore-line
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleCloudSessionConflict(
      dynamic e, bool isNewDevice, Function retryAction) async {
    final l10n = AppLocalizations.of(context)!;
    final errorStr = e.toString();

    if (errorStr.contains("SESSION_EXPIRED") ||
        errorStr.contains("another device")) {
      if (isNewDevice) {
        final confirm = await UIUtils.showClaimOwnershipDialog(
            context); // coverage:ignore-line

        // coverage:ignore-start
        if (confirm == true && mounted) {
          await ref.read(cloudSyncServiceProvider).claimSession();
          if (mounted) {
            await retryAction();
            // coverage:ignore-end
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sessionExpiredLogoutMessage)),
        );
        await ref.read(storageServiceProvider).clearAllData(fullWipe: true);
        ref.read(authServiceProvider).signOut(ref);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.syncErrorLabel(errorStr))),
      );
    }
  }

  Future<bool> _ensureEntitledTier() async {
    final subService = ref.read(subscriptionServiceProvider);
    final isLiteOrPremium = subService.getTier() != SubscriptionTier.free;

    if (!isLiteOrPremium) {
      // coverage:ignore-start
      if (!mounted) return false;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (c) => const PremiumPromoScreen()),
        // coverage:ignore-end
      );
      return result == true; // coverage:ignore-line
    }
    return true;
  }

  Future<String?> _getBackupPin() async {
    if (!_isAppLockEnabled) return null;
    return await _showVerifyPinDialog(context, // coverage:ignore-line
        reason: AppLocalizations.of(context)!
            .includePinInZip); // coverage:ignore-line
  }

  Future<void> _backupToZip() async {
    if (!await _ensureEntitledTier()) return;

    final capturedPin = await _getBackupPin();
    if (_isAppLockEnabled && capturedPin == null) return;

    setState(() => _isUploading = true);
    try {
      // 1. Generate ZIP bytes
      final bytes = await ref
          .read(jsonDataServiceProvider)
          .createBackupPackage(appPin: capturedPin);

      // 2. Save File
      final fileName =
          'samriddhi_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.zip';
      final resultMessage =
          await ref.read(fileServiceProvider).saveFile(fileName, bytes);

      if (resultMessage != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(resultMessage)));
      }
    } catch (e) {
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!
                .backupFailedLabel(e.toString()))));
        // coverage:ignore-end
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _restoreFromZip() async {
    if (!await _ensureEntitledTier()) return;

    if (_isAppLockEnabled) {
      if (!mounted) return;
      final pin = await _showVerifyPinDialog(context);
      if (pin == null) return;
    }

    final bytes = await ref
        .read(fileServiceProvider)
        .pickFile(allowedExtensions: ['zip']);
    if (bytes == null || !mounted) return;

    if (await _confirmRestoreFromZip()) {
      await _performZipRestore(bytes);
    }
  }

  Future<bool> _confirmRestoreFromZip() async {
    final decision = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 40),
        title: Text(AppLocalizations.of(context)!.restoringFromZipTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.areYouSure),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.restoreZipWarning),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'CANCEL'),
            child: Text(AppLocalizations.of(ctx)!.cancelButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'RESTORE'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(ctx)!.yesRestoreAction),
          ),
        ],
      ),
    );
    return decision == 'RESTORE';
  }

  Map<String, dynamic> _captureSessionIdentity() {
    final storage = ref.read(storageServiceProvider);
    return {
      'isLoggedIn': ref.read(isLoggedInProvider),
      'localMode': ref.read(localModeProvider),
      'sessionId': storage.getSessionId(),
      'lastLogin': storage.getLastLogin(),
      'region': storage.getCloudDatabaseRegion(),
      'profileId': storage.getActiveProfileId(),
    };
  }

  Future<void> _applySessionIdentity(Map<String, dynamic> identity) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setAuthFlag(identity['isLoggedIn']);
    if (identity['sessionId'] != null) {
      await storage.setSessionId(identity['sessionId']); // coverage:ignore-line
    }
    if (identity['lastLogin'] != null) {
      await storage.setLastLogin(identity['lastLogin']); // coverage:ignore-line
    }
    await storage.setCloudDatabaseRegion(identity['region']);
    await storage.setActiveProfileId(identity['profileId']);
    ref.read(localModeProvider.notifier).value = identity['localMode'];
  }

  void _invalidateSettingsProviders() {
    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(loansProvider);
    ref.invalidate(recurringTransactionsProvider);
    ref.invalidate(profilesProvider);
    ref.invalidate(monthlyBudgetProvider);
    ref.invalidate(currencyProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(dashboardConfigProvider);
    ref.read(txnsSinceBackupProvider.notifier).reset();
  }

  Future<void> _showRestoreSuccessDialog(Map<String, int> stats) async {
    final summaryItems =
        stats.entries.map((e) => "${e.key}: ${e.value}").toList();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.restoreCompleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.restoredItemsLabel,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...summaryItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(item),
                )),
          ],
        ),
        actions: [
          TextButton(
            // coverage:ignore-start
            onPressed: () {
              Navigator.pop(ctx);
              if (!ref.read(isLoggedInProvider)) {
                ref.read(localModeProvider.notifier).value = true;
                // coverage:ignore-end
              }
              // coverage:ignore-start
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (route) => false);
              // coverage:ignore-end
            },
            child: Text(AppLocalizations.of(ctx)!.okButton),
          ),
        ],
      ),
    );
  }

  Future<void> _performZipRestore(dynamic bytes) async {
    setState(() => _isDownloading = true);
    try {
      final identity = _captureSessionIdentity();

      final stats =
          await ref.read(jsonDataServiceProvider).restoreFromPackage(bytes);

      if (mounted) {
        await _applySessionIdentity(identity);
        _invalidateSettingsProviders();
        await _showRestoreSuccessDialog(stats);
      }
    } catch (e) {
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!
                .restoreFailedLabel(e.toString()))));
        // coverage:ignore-end
      }
    } finally {
      if (mounted) {
        // coverage:ignore-line
        setState(() => _isDownloading = false); // coverage:ignore-line
      }
    }
  }

  Future<void> _smartRestoreFlow() async {
    // coverage:ignore-line
    if (!await _verifyAppLockIfNeeded()) return; // coverage:ignore-line

    // 1. Check if region is selected
    if (!await _ensureRegionSelected()) return; // coverage:ignore-line

    // 2. Safety Dialog
    if (!mounted) return; // coverage:ignore-line
    final confirmed = await _showRestoreWarningDialog(); // coverage:ignore-line
    if (!confirmed) return;

    // coverage:ignore-start
    if (!mounted) return;
    final passcode = await _promptForEncryptionPasscode(
        context,
        AppLocalizations.of(context)!.cloudRestoreTitle,
        AppLocalizations.of(context)!.cloudRestoreWarning,
        // coverage:ignore-end
        isRestore: true);

    if (passcode == null) return; // User cancelled

    // 2. Perform Restore
    await _executeCloudRestore(passcode); // coverage:ignore-line
  }

  // coverage:ignore-start
  Future<bool> _verifyAppLockIfNeeded() async {
    if (_isAppLockEnabled) {
      final pin = await _showVerifyPinDialog(context);
      // coverage:ignore-end
      if (pin == null) return false;
    }
    return true;
  }

  Future<String?> _requirePinIfEnabled({String? reason}) async {
    if (!_isAppLockEnabled) return ""; // Success case (unlocked)
    if (!mounted) return null; // coverage:ignore-line
    return await _showVerifyPinDialog(context,
        reason: reason); // coverage:ignore-line
  }

  Future<bool> _confirmAccountDeactivation(AppLocalizations l10n) async {
    if (!mounted) return false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.red, size: 40),
        title: Text(l10n.deactivateAccountQuestion),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deactivateWipeWarning),
            const SizedBox(height: 16),
            Text(l10n.localDataSafeNote),
            const SizedBox(height: 16),
            Text(l10n.proceedQuestion),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // coverage:ignore-line
            child: Text(l10n.cancelActionCap),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.wipeDeactivateAction),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<bool> _confirmClearCloudData(AppLocalizations l10n) async {
    if (!mounted) return false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cloud_off, color: Colors.orange, size: 40),
        title: Text(l10n.clearCloudDataQuestion),
        content: Text(l10n.clearCloudWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // coverage:ignore-line
            child: Text(l10n.cancelActionCap),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(l10n.clearCloudDataAction),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  // coverage:ignore-start
  Future<bool> _showRestoreWarningDialog() async {
    final decision = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        // coverage:ignore-end
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.red, size: 40),
        title: Text(AppLocalizations.of(context)!
            .criticalWarningTitle), // coverage:ignore-line
        content: Column(
          // coverage:ignore-line
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // coverage:ignore-line
            Text(
                AppLocalizations.of(context)!
                    .useCloudRestoreQuestion, // coverage:ignore-line
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!
                .restoreCloudWarning), // coverage:ignore-line
          ],
        ),
        // coverage:ignore-start
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'CANCEL'),
            child: Text(AppLocalizations.of(context)!.cancelButton),
            // coverage:ignore-end
          ),
          // coverage:ignore-start
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'RESTORE'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.yesRestoreAction),
            // coverage:ignore-end
          ),
        ],
      ),
    );
    return decision == 'RESTORE'; // coverage:ignore-line
  }

  // coverage:ignore-start
  Future<void> _executeCloudRestore(String passcode) async {
    setState(() => _isDownloading = true);
    final l10n = AppLocalizations.of(context)!;
    final storage = ref.read(storageServiceProvider);
    final isNewDevice = storage.getSessionId() == null;
    // coverage:ignore-end

    try {
      // coverage:ignore-start
      await ref
          .read(cloudSyncServiceProvider)
          .restoreFromCloud(passcode: passcode)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception(l10n.timeoutError);
        // coverage:ignore-end
      });

      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.restoreCompleteStatus)));
        ref.invalidate(accountsProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(loansProvider);
        ref.invalidate(recurringTransactionsProvider);
        ref.invalidate(monthlyBudgetProvider);
        ref.invalidate(currencyProvider);
        ref.invalidate(categoriesProvider);
        ref.invalidate(dashboardConfigProvider);
        ref.read(txnsSinceBackupProvider.notifier).reset();
        // coverage:ignore-end
      }
    } catch (e) {
      // coverage:ignore-start
      if (mounted) {
        await _handleCloudSessionConflict(
            e, isNewDevice, () => _executeCloudRestore(passcode));
        // coverage:ignore-end
      }
    } finally {
      if (mounted) {
        // coverage:ignore-line
        setState(() => _isDownloading = false); // coverage:ignore-line
      }
    }
  }

  Future<void> _deactivateAccountFlow() async {
    final l10n = AppLocalizations.of(context)!;
    if (!await _ensureRegionSelected()) return;

    if (await _requirePinIfEnabled() == null) return;

    if (!await _confirmAccountDeactivation(l10n)) return;

    // 2. Perform Deactivate
    setState(() => _isUploading = true); // Use uploading spinner for progress
    try {
      final syncService = ref.read(cloudSyncServiceProvider);
      final authService = ref.read(authServiceProvider);

      // A. Re-authenticate first to ensure session is fresh (Google Auth handles it or we call signIn)
      await _requireFreshAuth(l10n);

      // B. Wipe Cloud Data
      await syncService.deleteCloudData();

      // C. Delete Account
      await authService.deleteAccount();

      // D. Wipe Local Data completely
      await ref.read(storageServiceProvider).clearAllData(fullWipe: true);

      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accountDeactivatedStatus)),
          // coverage:ignore-end
        );
      }
    } catch (e) {
      if (mounted) {
        final storage = ref.read(storageServiceProvider);
        final isNewDevice = storage.getSessionId() == null;
        await _handleCloudSessionConflict(
            e, isNewDevice, _deactivateAccountFlow);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _clearCloudDataFlow() async {
    final l10n = AppLocalizations.of(context)!;
    if (!await _ensureRegionSelected()) return;

    if (await _requirePinIfEnabled() == null) return;

    if (!await _confirmClearCloudData(l10n)) return;

    // 2. Perform Clear
    await _requireFreshAuth(l10n);
    final storage = ref.read(storageServiceProvider);
    final isNewDevice = storage.getSessionId() == null;

    setState(() => _isDownloading = true);
    try {
      await ref.read(cloudSyncServiceProvider).deleteCloudData();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.cloudDataClearedStatus)));
      }
    } catch (e) {
      if (mounted) {
        // coverage:ignore-line
        await _handleCloudSessionConflict(
            e, isNewDevice, _clearCloudDataFlow); // coverage:ignore-line
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  /// Re-authenticates the user; throws on failure.
  Future<void> _requireFreshAuth(AppLocalizations l10n) async {
    final authService = ref.read(authServiceProvider);
    final response = await authService.signInWithGoogle(ref);
    if (response.status != AuthStatus.success) {
      throw Exception(l10n
          .authFailedStatus(response.message ?? "")); // coverage:ignore-line
    }
  }

  // --- DIALOGS (Existing Logic) ---

  void _showCurrencyDialog() async {
    final currencies = [
      {
        'code': 'en_IN',
        'label': AppLocalizations.of(context)!.indianRupeeLabel
      },
      {'code': 'en_US', 'label': AppLocalizations.of(context)!.usDollarLabel},
      {
        'code': 'en_GB',
        'label': AppLocalizations.of(context)!.britishPoundLabel
      },
      {'code': 'en_EU', 'label': AppLocalizations.of(context)!.euroLabel},
      {
        'code': 'ja_JP',
        'label': AppLocalizations.of(context)!.japaneseYenLabel
      },
      {
        'code': 'zh_CN',
        'label': AppLocalizations.of(context)!.chineseYuanLabel
      },
      {'code': 'ar_AE', 'label': AppLocalizations.of(context)!.uaeDirhamLabel},
    ];

    await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.selectCurrencyTitle),
        children: currencies.map((c) {
          return SimpleDialogOption(
            onPressed: () {
              ref.read(currencyProvider.notifier).setCurrency(c['code']!);
              Navigator.pop(context);
            },
            child: Text(c['label']!, style: AppTheme.offlineSafeTextStyle),
          );
        }).toList(),
      ),
    );
  }

  Future<String?> _promptForEncryptionPasscode(
      BuildContext context, String title, String message,
      {bool isRestore = false}) async {
    final controller = TextEditingController();
    bool usePasscode = true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _buildEncryptionDialog(
          context,
          setDialogState,
          title,
          message,
          isRestore,
          controller,
          usePasscode,
          onTogglePasscode: (val) => usePasscode = val,
        ),
      ),
    );
    return result;
  }

  Widget _buildEncryptionDialog(
    BuildContext context,
    StateSetter setDialogState,
    String title,
    String message,
    bool isRestore,
    TextEditingController controller,
    bool usePasscode, {
    required void Function(bool) onTogglePasscode,
  }) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noteCategoriesEncryption,
            style: const TextStyle(
                fontSize: 11,
                color: Colors.orange,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          _buildEncryptionInput(context, setDialogState, isRestore, controller,
              usePasscode, onTogglePasscode),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null), // coverage:ignore-line
          child: Text(AppLocalizations.of(context)!.cancelActionCap),
        ),
        ElevatedButton(
          onPressed: () => _handleEncryptionSubmit(
              context, controller, isRestore, usePasscode),
          child: Text(_getEncryptionButtonLabel(isRestore, usePasscode)),
        ),
      ],
    );
  }

  Widget _buildEncryptionInput(
    BuildContext context,
    StateSetter setDialogState,
    bool isRestore,
    TextEditingController controller,
    bool usePasscode,
    void Function(bool) onTogglePasscode,
  ) {
    return Column(
      children: [
        if (!isRestore) ...[
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.encryptBackupQuestion),
            value: usePasscode,
            onChanged: (val) => setDialogState(() => onTogglePasscode(val)),
            contentPadding: EdgeInsets.zero,
          ),
        ],
        if (usePasscode || isRestore) ...[
          TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.encryptionPasscodeLabel,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ],
    );
  }

  void _handleEncryptionSubmit(BuildContext context,
      TextEditingController controller, bool isRestore, bool usePasscode) {
    if (!isRestore && !usePasscode) {
      Navigator.pop(context, "");
      return;
    }
    if (isRestore || controller.text.isNotEmpty) {
      Navigator.pop(context, controller.text);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context)!.pleaseEnterPasscodeError)),
    );
  }

  String _getEncryptionButtonLabel(bool isRestore, bool usePasscode) {
    if (isRestore) {
      return AppLocalizations.of(context)!
          .restoreActionCap; // coverage:ignore-line
    }
    if (usePasscode) {
      return AppLocalizations.of(context)!.encryptBackupAction;
    }
    return AppLocalizations.of(context)!.backupUnencryptedAction;
  }

  Future<String?> _showVerifyPinDialog(BuildContext context,
      {String? reason}) async {
    final controller = TextEditingController();
    const int minPinLength = 4;
    const int maxPinLength = 6;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.verifyAppPinTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                reason ?? AppLocalizations.of(context)!.verifyPinReasonDefault),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: maxPinLength,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 16),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: "",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, null), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.cancelActionCap),
          ),
          ElevatedButton(
            onPressed: () => _handlePinSubmit(
                context, controller, minPinLength, maxPinLength),
            child: Text(AppLocalizations.of(context)!.verifyAction),
          ),
        ],
      ),
    );
    return result;
  }

  void _handlePinSubmit(BuildContext context, TextEditingController controller,
      int minPinLength, int maxPinLength) {
    if (controller.text.length < minPinLength ||
        controller.text.length > maxPinLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        // coverage:ignore-line
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .pinLengthError)), // coverage:ignore-line
      );
      return;
    }
    final storage = ref.read(storageServiceProvider);
    if (storage.isPinLocked()) {
      // coverage:ignore-start
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.tooManyAttemptsError)),
        // coverage:ignore-end
      );
      controller.clear(); // coverage:ignore-line
      return;
    }
    if (storage.verifyAppPin(controller.text)) {
      Navigator.pop(context, controller.text);
    } else {
      final isLocked = storage.isPinLocked();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isLocked
              ? AppLocalizations.of(context)!
                  .tooManyAttemptsError // coverage:ignore-line
              : AppLocalizations.of(context)!.incorrectPinError),
        ),
      );
      controller.clear();
    }
  }

  void _showSetPinDialog(BuildContext context) {
    final storage = ref.read(storageServiceProvider);
    final currentPin = storage.getAppPin();
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(currentPin == null
            ? AppLocalizations.of(context)!.setAppPinTitle
            : AppLocalizations.of(context)!.setupAppLockTitle),
        content: _buildPinInputContent(controller, currentPin),
        actions:
            _buildPinDialogActions(context, storage, controller, currentPin),
      ),
    );
  }

  Widget _buildPinInputContent(
      TextEditingController controller, String? currentPin) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(currentPin == null
            ? AppLocalizations.of(context)!.enterPinToSecureNote
            : AppLocalizations.of(context)!.existingPinNote),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 16),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: "",
            hintText: AppLocalizations.of(context)!.newPinHint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
      ],
    );
  }

  List<Widget> _buildPinDialogActions(BuildContext context, dynamic storage,
      TextEditingController controller, String? currentPin) {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context), // coverage:ignore-line
        child: Text(AppLocalizations.of(context)!.cancelActionCap),
      ),
      if (currentPin != null)
        ElevatedButton(
          onPressed: () => _handleUseExistingPin(context, storage),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          child: Text(AppLocalizations.of(context)!.useExistingPinAction),
        ),
      ElevatedButton(
        onPressed: () => _handleSaveAndEnableLock(context, storage, controller),
        child: Text(AppLocalizations.of(context)!.saveEnableAction),
      ),
    ];
  }

  Future<void> _handleUseExistingPin(
      BuildContext context, dynamic storage) async {
    await storage.setAppLockEnabled(true);
    setState(() => _isAppLockEnabled = true);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.appLockEnabledStatus)),
      );
    }
  }

  Future<void> _handleSaveAndEnableLock(BuildContext context, dynamic storage,
      TextEditingController controller) async {
    if (controller.text.length < 4 || controller.text.length > 6) {
      // coverage:ignore-start
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pinLengthError)),
          // coverage:ignore-end
        );
      }
      return;
    }
    await storage.setAppPin(controller.text);
    await storage.setAppLockEnabled(true);
    setState(() => _isAppLockEnabled = true);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.pinSavedLockedStatus)),
      );
    }
  }

  void _showDeleteProfileDialog(
      BuildContext context, WidgetRef ref, Profile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteProfileQuestion),
        content: Text(
            AppLocalizations.of(context)!.deleteProfileWarning(profile.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.cancelActionCap),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(storageServiceProvider).deleteProfile(profile.id);
              ref.invalidate(profilesProvider);
              // If we deleted the active profile, switch to default
              if (ref.read(activeProfileIdProvider) == profile.id) {
                ref
                    .read(activeProfileIdProvider.notifier)
                    .setProfile('default');
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context)!.deleteActionCap,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCopyCategoriesDialog(
      BuildContext context, WidgetRef ref, String targetProfileId) {
    final profilesAsync = ref.read(profilesProvider);
    profilesAsync.whenData((profiles) {
      final otherProfiles =
          profiles.where((p) => p.id != targetProfileId).toList();
      if (otherProfiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          // coverage:ignore-line
          SnackBar(
              // coverage:ignore-line
              content: Text(AppLocalizations.of(context)!
                  .noOtherProfilesError)), // coverage:ignore-line
        );
        return;
      }

      showDialog(
        context: context,
        builder: (c) => _CopyCategoriesDialog(
          profiles: otherProfiles,
          targetProfileId: targetProfileId,
          allProfiles: profiles,
          onCopy: (sourceId) async {
            final storage = ref.read(storageServiceProvider);
            await storage.copyCategories(sourceId, targetProfileId);
          },
        ),
      );
    });
  }
}

class _CopyCategoriesDialog extends StatelessWidget {
  final List<Profile> profiles;
  final String targetProfileId;
  final List<Profile> allProfiles;
  final Future<void> Function(String sourceId) onCopy;

  const _CopyCategoriesDialog({
    required this.profiles,
    required this.targetProfileId,
    required this.allProfiles,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.copyCategoriesTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              profiles.map((p) => _buildProfileOption(context, p)).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // coverage:ignore-line
          child: Text(AppLocalizations.of(context)!.closeAction),
        ),
      ],
    );
  }

  Widget _buildProfileOption(BuildContext context, Profile p) {
    return ListTile(
      title: Text(p.name),
      onTap: () async {
        await onCopy(p.id);
        if (context.mounted) {
          final targetName =
              allProfiles.firstWhere((pr) => pr.id == targetProfileId).name;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(AppLocalizations.of(context)!
                    .categoriesCopiedStatus(targetName))),
          );
          Navigator.pop(context);
        }
      },
    );
  }
}
