import '../utils/connectivity_platform.dart';
import '../utils/network_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:samriddhi_flow/core/app_constants.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../theme/app_theme.dart';
import '../models/profile.dart';
import 'package:uuid/uuid.dart';

import '../services/auth_service.dart';
import '../widgets/pure_icons.dart';
import 'recycle_bin_screen.dart';
import 'recurring_manager_screen.dart';
import 'holiday_manager_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../utils/ui_utils.dart';
import '../widgets/common_dialogs.dart';
import '../widgets/category_manager_dialog.dart';
import '../services/repair_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Cloud State
  bool _isUploading = false;
  bool _isDownloading = false;
  bool _isAppLockEnabled = false;

  // PWA Install Prompt
  Object? _installPrompt;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _isAppLockEnabled = storage.isAppLockEnabled();

// coverage:ignore-start
    // Listen for PWA Install Prompt (Web Only)
    if (kIsWeb) {
      ConnectivityPlatform.listenForInstallPrompt((event) {
        setState(() {
          _installPrompt = event;
        });
      });
    }
// coverage:ignore-end
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStreamProvider).value;
    // Watch connectivity stream to force rebuild on network changes
    ref.watch(connectivityStreamProvider);
    ref.watch(isOfflineProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildAppearanceSection(),
          const Divider(),
          _buildDashboardSection(),
          const Divider(),
          _buildCloudSectionHeader(context, user),
          const Divider(),
          _buildDataManagementSection(context),
          const Divider(),
          _buildFeatureManagementSection(context),
          const Divider(),
          _buildProfileManagementSection(context),
          const Divider(),
          _buildPreferencesSection(context),
          if (user != null && !ref.watch(isOfflineProvider)) ...[
            const Divider(),
            _buildAuthSection(context),
          ],
          const Divider(),
          _buildSecuritySection(context),
          const Divider(),
          _buildAppInfoSection(context),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Appearance', showDivider: false),
        ListTile(
          title: const Text('Theme Mode'),
          subtitle: Text(ref.watch(themeModeProvider).name.toUpperCase()),
          leading: Icon(
            ref.watch(themeModeProvider) == ThemeMode.dark
                ? Icons.dark_mode
                : ref.watch(themeModeProvider) == ThemeMode.light
                    ? Icons.light_mode
                    : Icons.brightness_auto,
            color: Colors.amber,
          ),
          trailing: DropdownButton<ThemeMode>(
            value: ref.watch(themeModeProvider),
            onChanged: (ThemeMode? newValue) {
              if (newValue != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(newValue);
              }
            },
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardSection() {
    final config = ref.watch(dashboardConfigProvider);
    final notifier = ref.read(dashboardConfigProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Dashboard Customization'),
        SwitchListTile(
          title: const Text('Show Income & Expense'),
          subtitle: const Text('Display monthly summary cards'),
          value: config.showIncomeExpense,
          onChanged: (val) => notifier.updateConfig(showIncomeExpense: val),
          secondary: const Icon(Icons.analytics_outlined, color: Colors.blue),
        ),
        SwitchListTile(
          title: const Text('Show Budget Indicator'),
          subtitle: const Text('Display monthly budget progress bar'),
          value: config.showBudget,
          onChanged: (val) => notifier.updateConfig(showBudget: val),
          secondary: const Icon(Icons.pie_chart_outline, color: Colors.green),
        ),
      ],
    );
  }

  Widget _buildCloudSectionHeader(BuildContext context, dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Cloud & Sync'),
        _buildCloudSection(context, user),
      ],
    );
  }

  Widget _buildCloudSection(BuildContext context, dynamic user) {
    if (user == null) {
      bool isOfflineLoggedIn = false;
      try {
        if (Hive.isBoxOpen('settings')) {
          isOfflineLoggedIn = Hive.box('settings')
              .get('isLoggedIn', defaultValue: false) as bool;
        }
      } catch (_) {}

      if (isOfflineLoggedIn) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text('Connection Paused',
                  style: AppTheme.offlineSafeTextStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(
                'You are in Offline Mode. Cloud Sync is deferred.',
                textAlign: TextAlign.center,
                style: AppTheme.offlineSafeTextStyle.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Retrying connection...")),
                    );
                  }
                  // Force a network check first
                  await NetworkUtils.hasActualInternet();
                  ref.invalidate(firebaseInitializerProvider);
                  // refresh offline status check
                  ref.invalidate(isOfflineProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('Enable Cloud Sync',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Keep your data synchronized across devices securely.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text('Login to Setup Cloud'),
            )
          ],
        ),
      );
    }

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
                    Text('Account: ${user.email ?? "User"}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    const Text('Cloud Synchronization Active',
                        style: TextStyle(color: Colors.green, fontSize: 12)),
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
                  label: const Text('Migrate/Sync Now'),
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
                  label: const Text('Restore'),
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

  Widget _buildDataManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Data Management'),
        ListTile(
          title: const Text('Export Data to Excel'),
          subtitle: const Text('Backup all transactions (.xlsx)'),
          leading: PureIcons.download(color: AppTheme.primary),
          onTap: _exportLocalFile,
        ),
        ListTile(
          title: const Text('Restore Data from Excel (Local)'),
          subtitle: const Text('Restore from local backup file'),
          leading: PureIcons.upload(color: Colors.green),
          onTap: _importLocalFile,
        ),
        ListTile(
          title: const Text('Recycle Bin'),
          subtitle: const Text('Restore deleted transactions'),
          leading: PureIcons.recycleBin(color: Colors.red),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RecycleBinScreen())),
        ),
        ListTile(
          title: const Text('Repair Data'),
          subtitle: const Text('Fix data consistency issues'),
          leading: const Icon(Icons.build_circle, color: Colors.amber),
          onTap: () => _showRepairDialog(context),
        ),
      ],
    );
  }

  void _showRepairDialog(BuildContext parentContext) {
    final jobs = ref.read(repairServiceProvider).jobs;
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Data Repair'),
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
                onTap: () async {
                  Navigator.pop(dialogContext);
                  // Show loading or progress?
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('Running repair...')));

                  try {
                    final int count = await job.run(ref.reader);
                    if (context.mounted) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(
                          content: Text(
                              '${job.name}: Successfully repaired $count items.')));
                      // Invalidate providers to reflect changes
                      ref.invalidate(accountsProvider);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(
                          content: Text('Repair Failed: $e'),
                          backgroundColor: Colors.red));
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildFeatureManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Feature Management'),
        ListTile(
          title: const Text('Manage Recurring Payments'),
          subtitle: const Text('View or delete automated payments'),
          leading: PureIcons.refresh(color: Colors.orange),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const RecurringManagerScreen())),
        ),
        ListTile(
          title: const Text('Holiday Manager'),
          subtitle: const Text('Configure non-working days'),
          leading: PureIcons.calendar(color: Colors.red),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HolidayManagerScreen())),
        ),
        ListTile(
          title: const Text('Manage Categories'),
          subtitle: const Text('Add, edit, or delete categories'),
          leading: PureIcons.icon(Icons.category, color: Colors.blue),
          onTap: () => showDialog(
            context: context,
            builder: (context) => const CategoryManagerDialog(),
          ),
        ),
        SwitchListTile(
          title: const Text('Smart Calculator'),
          subtitle: const Text('Enable Quick Sum Tracker on transactions'),
          secondary: PureIcons.calculate(color: Colors.teal),
          value: ref.watch(smartCalculatorEnabledProvider),
          onChanged: (_) =>
              ref.read(smartCalculatorEnabledProvider.notifier).toggle(),
        ),
      ],
    );
  }

  Widget _buildProfileManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Profile Management'),
        ref.watch(profilesProvider).when(
              data: (profiles) => Column(
                children: profiles.map((p) {
                  final isActive = p.id == ref.watch(activeProfileIdProvider);
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(isActive ? 'Active' : 'Tap to switch'),
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                      child: PureIcons.person(
                          color: isActive ? Colors.white : Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: PureIcons.copy(),
                          tooltip: 'Copy Categories from another profile',
                          onPressed: () =>
                              _showCopyCategoriesDialog(context, ref, p.id),
                        ),
                        if (profiles.length > 1 && !isActive)
                          IconButton(
                            icon: PureIcons.deleteOutlined(color: Colors.red),
                            onPressed: () =>
                                _showDeleteProfileDialog(context, ref, p),
                          ),
                      ],
                    ),
                    onTap: isActive
                        ? null
                        : () {
                            ref
                                .read(activeProfileIdProvider.notifier)
                                .setProfile(p.id);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text("Switched to ${p.name}")));
                          },
                  );
                }).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => ListTile(title: Text('Error: $e')),
            ),
        ListTile(
          title: const Text('Add New Profile'),
          leading: PureIcons.addCircle(color: Colors.blue),
          onTap: () => CommonDialogs.showTextFieldDialog(
            context: context,
            title: "Create Profile",
            labelText: "Profile Name",
            hintText: "Enter name (e.g. Business)",
            initialValue: "",
            saveLabel: "CREATE",
            onSave: (val) async {
              if (val.trim().isEmpty) return;
              final newProfile = Profile(
                id: const Uuid().v4(),
                name: val.trim(),
              );
              await ref.read(storageServiceProvider).saveProfile(newProfile);
              ref.invalidate(profilesProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Preferences'),
        ListTile(
          title: const Text('Currency'),
          subtitle: Text(
              'Current: ${ref.watch(currencyProvider) == 'en_IN' ? 'Indian Rupee (₹)' : ref.watch(currencyProvider) == 'en_GB' ? 'British Pound (£)' : ref.watch(currencyProvider) == 'en_EU' ? 'Euro (€)' : 'US Dollar (\$)'}'),
          leading: PureIcons.money(color: Colors.green),
          onTap: _showCurrencyDialog,
        ),
        ListTile(
          title: const Text('Monthly Budget'),
          subtitle: Text(
              'Limit: ${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).format(ref.watch(monthlyBudgetProvider))}'),
          leading: PureIcons.reports(color: Colors.blue),
          onTap: () => CommonDialogs.showTextFieldDialog(
            context: context,
            title: "Set Monthly Budget",
            labelText: "Amount",
            prefixText:
                '${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).currencySymbol} ',
            initialValue: ref.read(monthlyBudgetProvider).toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            onSave: (val) {
              final amount = double.tryParse(val) ?? 0;
              ref.read(monthlyBudgetProvider.notifier).setBudget(amount);
            },
          ),
        ),
        ListTile(
          title: const Text('Backup Reminder'),
          subtitle: Text(
              'Remind after every ${ref.watch(backupThresholdProvider)} transactions'),
          leading: PureIcons.sync(color: Colors.purple),
          onTap: () => CommonDialogs.showTextFieldDialog(
            context: context,
            title: "Backup Interval",
            labelText: "Number of transactions",
            helperText: "Default: 20",
            initialValue: ref.read(backupThresholdProvider).toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSave: (val) {
              final threshold = int.tryParse(val) ?? 20;
              ref
                  .read(backupThresholdProvider.notifier)
                  .setThreshold(threshold);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuthSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Authentication'),
        ListTile(
          title: const Text('Logout'),
          leading: PureIcons.logout(color: Colors.red),
          onTap: () => UIUtils.handleLogout(context, ref),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Security'),
        SwitchListTile(
          title: const Text('App Lock (PIN)'),
          subtitle: const Text('Require PIN on startup/resume'),
          secondary: PureIcons.lock(color: Colors.grey),
          value: _isAppLockEnabled,
          onChanged: (val) async {
            if (val) {
              _showSetPinDialog(context);
            } else {
              final verified = await _showVerifyPinDialog(context);
              if (verified) {
                setState(() => _isAppLockEnabled = false);
                await ref.read(storageServiceProvider).setAppLockEnabled(false);
              }
            }
          },
        ),
        if (_isAppLockEnabled)
          ListTile(
            title: const Text('Change PIN'),
            leading: PureIcons.security(size: 20),
            onTap: () => _showSetPinDialog(context),
          ),
      ],
    );
  }

  Widget _buildAppInfoSection(BuildContext context) {
    final user = ref.watch(authStreamProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('App Information'),
        ListTile(
          title: const Text('Update Application'),
          subtitle: const Text('Clear cache and reload latest version'),
          leading:
              const Icon(Icons.system_update_rounded, color: Colors.blueAccent),
          onTap: _updateApplication,
        ),
        ListTile(
          title: const Text('About'),
          subtitle: const Text(AppConstants.appVersion),
          leading: PureIcons.info(size: 20),
          onTap: () =>
              UIUtils.showCommonAboutDialog(context, AppConstants.appVersion),
        ),
        if (_installPrompt != null) ...[
          const Divider(),
          ListTile(
            title: const Text('Install App'),
            subtitle: const Text('Add to Home Screen for Offline use'),
            leading: const Icon(Icons.install_mobile, color: Colors.blue),
            onTap: () async {
              if (_installPrompt != null) {
                await ConnectivityPlatform.triggerInstallPrompt(
                    _installPrompt!);
                setState(() => _installPrompt = null);
              }
            },
          ),
        ] else if (kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS)) ...[
          const Divider(),
          ListTile(
            title: const Text('Install on iPhone'),
            subtitle: const Text('Tap "Share" → "Add to Home Screen"'),
            leading: const Icon(Icons.ios_share, color: Colors.blue),
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Install on iPhone"),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("To install this app for offline use:\n"),
                    ListTile(
                      leading: Icon(Icons.ios_share),
                      title: Text('1. Tap the Share button'),
                    ),
                    ListTile(
                      leading: Icon(Icons.add_box_outlined),
                      title:
                          Text('2. Scroll down and tap "Add to Home Screen"'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("OK")),
                ],
              ),
            ),
          ),
        ],
        if (user != null && !ref.watch(isOfflineProvider)) ...[
          const Divider(),
          UIUtils.buildSectionHeader('Danger Zone', showDivider: false),
          ListTile(
            title: const Text('Clear Cloud Data (Keep Account)',
                style: TextStyle(color: Colors.orange)),
            subtitle: const Text('Remove cloud backup, keep account active'),
            leading: PureIcons.cloudOff(size: 20, color: Colors.orange),
            onTap: _clearCloudDataFlow,
          ),
          ListTile(
            title: const Text('Deactivate & Wipe Cloud Data',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text('Move back to Local-Only mode'),
            leading: PureIcons.deleteForever(color: Colors.red),
            onTap: _deactivateAccountFlow,
          ),
        ],
      ],
    );
  }

  // --- ACTIONS ---

// coverage:ignore-start
  Future<void> _updateApplication() async {
    if (ref.read(isOfflineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Internet connection required to check for updates.")),
      );
      return;
    }

    // Checking phase
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Checking for updates...")),
    );

    bool updateFound = false;
    if (!updateFound) {
      if (kIsWeb) {
        // Double check offline status before potentially throwing
        if (ref.read(isOfflineProvider)) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Offline: Unable to check for updates."),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        try {
          updateFound =
              await ConnectivityPlatform.checkForServiceWorkerUpdate();
        } catch (e) {
          debugPrint("Update check failed: $e");
          // Explicitly warn user if the check threw an exception
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Unable to check for updates: $e"),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          updateFound = false;
        }
      }
    }

    if (!updateFound) {
      if (mounted) {
        final wantReload = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Up to Date'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'You are consistent with the latest version (${AppConstants.appVersion}).'),
                SizedBox(height: 16),
                Text(
                    'If you don\'t see expected changes, you can force a reload.'),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('OK')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Force Reload')),
            ],
          ),
        );

        if (wantReload == true && kIsWeb) {
          try {
            await ConnectivityPlatform.reloadAndClearCache();
          } catch (e) {
            debugPrint("Failed to clear cache: $e");
            // Reload is handled in platform
          }
        }
      }
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.system_update_rounded,
            color: Colors.blueAccent, size: 40),
        title: const Text('Update Application'),
        content: const Text(
            'This will clear the application cache and reload the latest version. Your local data (Hive) will remain safe. Do you want to proceed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update & Reload')),
        ],
      ),
    );

    if (confirmed == true) {
      if (kIsWeb) {
        try {
          await ConnectivityPlatform.reloadAndClearCache();
        } catch (e) {
          debugPrint("Failed to clear cache: $e");
          // Reload is handled in platform
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Update not available for this platform.')),
        );
      }
    }
  }
// coverage:ignore-end

  Future<void> _exportLocalFile() async {
    // 1. Check Connectivity
    if (ref.read(isOfflineProvider)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Internet connection required for Excel operations (Premium Feature Validation).',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final excelService = ref.read(excelServiceProvider);
    final List<int> excelData = await excelService.exportData();

    final profile = ref.read(activeProfileProvider);
    final profileName =
        profile?.name.replaceAll(RegExp(r'[^\w\s-]'), '_') ?? 'budget';
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = '${profileName}_backup_$timestamp.xlsx';

    final accounts = ref.read(accountsProvider).value?.length ?? 0;
    final loans = ref.read(loansProvider).value?.length ?? 0;
    final txns = ref.read(transactionsProvider).value?.length ?? 0;

    final loansData = ref.read(loansProvider).value ?? [];
    int loanTxns = 0;
    for (var l in loansData) {
      loanTxns += l.transactions.length;
    }

    try {
      final fileService = ref.read(fileServiceProvider);
      await fileService.saveFile(fileName, excelData);

      ref.read(txnsSinceBackupProvider.notifier).reset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Exported: $accounts accounts, $loans loans, $txns txns, $loanTxns loan txns')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export Failed: $e')),
        );
      }
    }
  }

  Future<void> _importLocalFile() async {
    // 1. Check Connectivity
    if (ref.read(isOfflineProvider)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Internet connection required for Excel operations (Premium Feature Validation).',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final excelService = ref.read(excelServiceProvider);
    try {
      final results = await excelService.importData();
      final status = results['status']!;

      if (!mounted) return;

      if (status == 1) {
        // Success
        // Success
        ref.invalidate(accountsProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(loansProvider);
        ref.invalidate(recurringTransactionsProvider);

        String msg = 'Imported: ';
        List<String> parts = [];
        if ((results['profiles'] ?? 0) > 0) {
          parts.add('${results['profiles']} profiles');
        }
        if ((results['accounts'] ?? 0) > 0) {
          parts.add('${results['accounts']} accounts');
        }
        if ((results['loans'] ?? 0) > 0) parts.add('${results['loans']} loans');
        if ((results['categories'] ?? 0) > 0) {
          parts.add('${results['categories']} categories');
        }
        if ((results['transactions'] ?? 0) > 0) {
          String txnDetails = '${results['transactions']} transactions';

          List<String> types = [];
          if ((results['type_income'] ?? 0) > 0) {
            types.add('In: ${results['type_income']}');
          }
          if ((results['type_expense'] ?? 0) > 0) {
            types.add('Ex: ${results['type_expense']}');
          }
          if ((results['type_transfer'] ?? 0) > 0) {
            types.add('Tr: ${results['type_transfer']}');
          }

          if (types.isNotEmpty) {
            txnDetails += ' (${types.join(', ')})';
          }
          if ((results['skipped_error'] ?? 0) > 0) {
            txnDetails += ' [Skipped Errors: ${results['skipped_error']}]';
          }
          if ((results['skipped_selftransfer'] ?? 0) > 0) {
            txnDetails +=
                ' [Skipped Self-Transfers: ${results['skipped_selftransfer']}]';
          }

          parts.add(txnDetails);
        }
        if ((results['loanTransactions'] ?? 0) > 0) {
          parts.add('${results['loanTransactions']} loan transactions');
        }

        if (parts.isEmpty) {
          msg += "Data processed successfully.";
        } else {
          msg += parts.join(', ');
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      } else if (status == 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No new data found.')));
      } else if (status == -2) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Error reading file.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Import Error: $e")));
      }
    }
  }

  Future<void> _backupToCloud() async {
    // Check PIN if enabled
    if (_isAppLockEnabled) {
      final verified = await _showVerifyPinDialog(context);
      if (!verified) return;
    }

    setState(() => _isUploading = true);
    try {
      await ref
          .read(cloudSyncServiceProvider)
          .syncToCloud()
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception("Request timed out. Please check your connection.");
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Cloud Sync Success!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Sync Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _smartRestoreFlow() async {
    // Check PIN if enabled
    if (_isAppLockEnabled) {
      final verified = await _showVerifyPinDialog(context);
      if (!verified) return;
    }

    // 1. Safety Dialog
    if (!mounted) return;
    final decision = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Critical Warning"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Use Cloud Restore?",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text(
                "This will PERMANENTLY WIPE all local data and replace it with your cloud data."),
            SizedBox(height: 16),
            Text(
                "Do you want to download a safety backup (Excel) of your CURRENT data first?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'CANCEL'),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'NO_BACKUP_RESTORE'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("No, Just Restore"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'BACKUP_THEN_RESTORE'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Yes, Backup First"),
          ),
        ],
      ),
    );

    if (decision == 'CANCEL' || decision == null) return;

    if (decision == 'BACKUP_THEN_RESTORE') {
      final excelService = ref.read(excelServiceProvider);
      final currentBytes = await excelService.exportData(allProfiles: true);
      final fileService = ref.read(fileServiceProvider);
      await fileService.saveFile(
          'safety_backup_before_restore.xlsx', currentBytes);
      await Future.delayed(const Duration(seconds: 2));
    }

    // 2. Perform Restore
    setState(() => _isDownloading = true);
    try {
      await ref
          .read(cloudSyncServiceProvider)
          .restoreFromCloud()
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception("Request timed out. Please check your connection.");
      });

      if (mounted) {
        // Force refresh providers
        ref.invalidate(accountsProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(loansProvider);
        ref.invalidate(recurringTransactionsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Restore Complete! Reloading...")));
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Restore Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _deactivateAccountFlow() async {
    // Check PIN if enabled
    if (_isAppLockEnabled) {
      final verified = await _showVerifyPinDialog(context);
      if (!verified) return;
    }

    // 1. Verify Intent
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Deactivate Cloud Account?"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "This will PERMANENTLY WIPE all your data from the cloud and delete your online account."),
            SizedBox(height: 16),
            Text(
                "Your LOCAL data will remain intact, but you will return to Local-Only mode."),
            SizedBox(height: 16),
            Text("Do you want to proceed?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("WIPE & DEACTIVATE"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. Perform Deactivate
    setState(() => _isUploading = true); // Use uploading spinner for progress
    try {
      final syncService = ref.read(cloudSyncServiceProvider);
      final authService = ref.read(authServiceProvider);

      // A. Re-authenticate first to ensure session is fresh (Google Auth handles it or we call signIn)
      final response = await authService.signInWithGoogle(ref);
      if (response.status != AuthStatus.success) {
        throw Exception("Re-authentication Failed: ${response.message}");
      }

      // B. Wipe Cloud Data
      await syncService.deleteCloudData();

      // C. Delete Account
      await authService.deleteAccount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Account Deactivated and Cloud Data Wiped.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Deactivation Failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _clearCloudDataFlow() async {
    // Check PIN if enabled
    if (_isAppLockEnabled) {
      final verified = await _showVerifyPinDialog(context);
      if (!verified) return;
    }

    // 1. Verify Intent
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Clear Cloud Data?"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "This will PERMANENTLY DELETE all your data from the cloud server."),
            SizedBox(height: 8),
            Text("Your Local Data will be SAFE."),
            Text("Your Account will remain ACTIVE."),
            SizedBox(height: 16),
            Text("Proceed?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("CLEAR CLOUD DATA"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. Perform Clear
    setState(() => _isUploading = true);
    try {
      // Re-authenticate first
      final authService = ref.read(authServiceProvider);
      final response = await authService.signInWithGoogle(ref);
      if (response.status != AuthStatus.success) {
        throw Exception("Authentication Failed: ${response.message}");
      }

      await ref.read(cloudSyncServiceProvider).deleteCloudData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cloud Data Cleared Successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Clear Failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- DIALOGS (Existing Logic) ---

  void _showCurrencyDialog() async {
    const currencies = [
      {'code': 'en_IN', 'label': 'Indian Rupee (₹)'},
      {'code': 'en_US', 'label': 'US Dollar (\$)'},
      {'code': 'en_GB', 'label': 'British Pound (£)'},
      {'code': 'en_EU', 'label': 'Euro (€)'},
    ];

    await showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Currency'),
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

  Future<bool> _showVerifyPinDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Verify App PIN"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your 4-digit PIN to disable App Lock."),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              final storedPin = ref.read(storageServiceProvider).getAppPin();
              if (controller.text == storedPin) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Incorrect PIN")),
                );
                controller.clear();
              }
            },
            child: const Text("VERIFY"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSetPinDialog(BuildContext context) {
    final storage = ref.read(storageServiceProvider);
    final currentPin = storage.getAppPin();
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(currentPin == null ? "Set App PIN" : "Setup App Lock"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentPin == null
                ? "Enter a 4-digit PIN to secure the app."
                : "You have an existing PIN. Do you want to use it or set a new one?"),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 16),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: "",
                hintText: "NEW PIN",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          if (currentPin != null)
            ElevatedButton(
              onPressed: () async {
                await storage.setAppLockEnabled(true);
                setState(() => _isAppLockEnabled = true);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("App Lock Enabled")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text("USE EXISTING"),
            ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.length == 4) {
                await storage.setAppPin(controller.text);
                await storage.setAppLockEnabled(true);
                setState(() => _isAppLockEnabled = true);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("PIN Saved & Locked")),
                  );
                }
              }
            },
            child: const Text("SAVE & ENABLE"),
          ),
        ],
      ),
    );
  }

  void _showDeleteProfileDialog(
      BuildContext context, WidgetRef ref, Profile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Profile?"),
        content: Text(
            "This will PERMANENTLY delete the profile '${profile.name}' and ALL its associated data (accounts, transactions, loans). This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
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
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
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
          const SnackBar(content: Text('No other profiles to copy from.')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Copy Categories'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: otherProfiles
                  .map((p) => ListTile(
                        title: Text(p.name),
                        onTap: () async {
                          final storage = ref.read(storageServiceProvider);
                          await storage.copyCategories(p.id, targetProfileId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Categories copied to ${profiles.firstWhere((pr) => pr.id == targetProfileId).name}')),
                            );
                            Navigator.pop(c);
                          }
                        },
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Close')),
          ],
        ),
      );
    });
  }
}
