import 'package:samriddhi_flow/utils/regex_utils.dart';
import '../utils/connectivity_platform.dart';
import '../utils/network_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/services.dart';
import 'package:samriddhi_flow/core/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../feature_providers.dart';

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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildAppearanceSection(),
          _buildDashboardSection(),
          _buildCloudSectionHeader(context, user),
          _buildDataManagementSection(context),
          _buildFeatureManagementSection(context),
          _buildProfileManagementSection(context),
          _buildPreferencesSection(context),
          if (user != null && !ref.watch(isOfflineProvider)) ...[
            _buildAuthSection(context),
          ],
          _buildSecuritySection(context),
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
            () {
              final mode = ref.watch(themeModeProvider);
              if (mode == ThemeMode.dark) return Icons.dark_mode;
              if (mode == ThemeMode.light) return Icons.light_mode;
              return Icons.brightness_auto;
            }(),
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
          onChanged: (val) => // coverage:ignore-line
              notifier.updateConfig(showBudget: val), // coverage:ignore-line
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
      return _buildNoUserCloudSection(context);
    }
    return _buildActiveCloudCard(context, user);
  }

  Widget _buildNoUserCloudSection(BuildContext context) {
    if (ref.watch(isLoggedInProvider)) {
      return _buildOfflinePausedCard(context); // coverage:ignore-line
    }
    return _buildEnableCloudCard(context);
  }

  Widget _buildOfflinePausedCard(BuildContext context) { // coverage:ignore-line


    return Container( // coverage:ignore-line


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
          Text('Connection Paused',
              style: AppTheme.offlineSafeTextStyle.copyWith(
      // coverage:ignore-end
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  // coverage:ignore-start
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface)),
                  // coverage:ignore-end
          const SizedBox(height: 8),
          Text( // coverage:ignore-line


            'You are in Offline Mode. Cloud Sync is deferred.',
            textAlign: TextAlign.center,
            style: AppTheme.offlineSafeTextStyle.copyWith( // coverage:ignore-line


                fontSize: 12,
                // coverage:ignore-start
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant),
                // coverage:ignore-end
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          // coverage:ignore-start
          ElevatedButton.icon(
            onPressed: () async {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
          // coverage:ignore-end
                  const SnackBar(content: Text("Retrying connection...")),
                );
              }
              // coverage:ignore-start
              final hasNet = await NetworkUtils.hasActualInternet();
              if (hasNet && context.mounted) {
                ref.read(isOfflineProvider.notifier).setOffline(false);
                ref.invalidate(firebaseInitializerProvider);
                ScaffoldMessenger.of(context).showSnackBar(
              // coverage:ignore-end
                  const SnackBar(
                      content:
                          Text("Internet restored. Reconnecting cloud...")),
                );
              } else if (context.mounted) { // coverage:ignore-line

                ScaffoldMessenger.of(context).showSnackBar( // coverage:ignore-line

                  const SnackBar(content: Text("Still offline.")),
                );
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Connection'),
            // coverage:ignore-start
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

  Widget _buildEnableCloudCard(BuildContext context) {
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
            onPressed: () => Navigator.push( // coverage:ignore-line


                context,
                MaterialPageRoute( // coverage:ignore-line


                    builder: (_) => // coverage:ignore-line
                        const LoginScreen())),
            child: const Text('Login to Setup Cloud'),
          )
        ],
      ),
    );
  }

  Widget _buildActiveCloudCard(BuildContext context, dynamic user) {
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
                    const Text('* Categories aren\'t encrypted',
                        style: TextStyle(color: Colors.orange, fontSize: 10)),
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
          title: const Text('Recycle Bin'),
          subtitle: const Text('Restore deleted transactions'),
          leading: PureIcons.recycleBin(color: Colors.red),
          onTap: () => Navigator.push( // coverage:ignore-line


              context,
              MaterialPageRoute( // coverage:ignore-line


                  builder: (_) => // coverage:ignore-line
                      const RecycleBinScreen())),
        ),
        ListTile(
          title: const Text('Backup Data (ZIP)'),
          subtitle: const Text('Export all data to a ZIP file'),
          leading: const Icon(Icons.archive, color: Colors.purple),
          onTap: _isUploading ? null : _backupToZip,
          trailing: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
        ),
        ListTile(
          title: const Text('Restore Data (ZIP)'),
          subtitle: const Text('Import data from a ZIP file'),
          leading: const Icon(Icons.unarchive, color: Colors.teal),
          onTap: _isDownloading ? null : _restoreFromZip,
          trailing: _isDownloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
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
    final allJobs = ref.read(repairServiceProvider).jobs;
    final jobs = allJobs.where((j) => j.showInSettings).toList();
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
                onTap: () {
                  Navigator.pop(dialogContext);
                  _handleRepairJobTap(parentContext, job);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => // coverage:ignore-line
                  Navigator.pop(dialogContext), // coverage:ignore-line
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _handleRepairJobTap(
      BuildContext parentContext, dynamic job) async {
    Map<String, dynamic>? args;

    if (job.id == 'repair_cc_balances') {
      args = await _selectCreditCardForRepair( // coverage:ignore-line
          parentContext);
      if (args == null && !context.mounted) return; // coverage:ignore-line
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(parentContext)
        .showSnackBar(const SnackBar(content: Text('Running repair...')));

    try {
      final int count = await job.run(ref.reader, args: args);
      if (context.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(
            content: Text('${job.name}: Successfully repaired $count items.')));
        ref.invalidate(accountsProvider);
      }
    } catch (e) {
      // coverage:ignore-start
      if (context.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(
            content: Text('Repair Failed: $e'), backgroundColor: Colors.red));
      // coverage:ignore-end
      }
    }
  }

  Future<Map<String, dynamic>?> _selectCreditCardForRepair( // coverage:ignore-line


      BuildContext parentContext) async {
    // coverage:ignore-start
    final accounts = (ref.read(accountsProvider).asData?.value ?? [])
        .where((a) => a.type == AccountType.creditCard)
        .toList();
    // coverage:ignore-end

    if (accounts.isEmpty || !context.mounted) { // coverage:ignore-line


      return null;
    }

    final result = await showDialog<String>( // coverage:ignore-line


      context: parentContext,
      builder: (ctx) => SimpleDialog( // coverage:ignore-line


        title: const Text('Select Credit Card'),
        // coverage:ignore-start
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'all'),
        // coverage:ignore-end
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('All Credit Cards',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildFeatureManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Feature Management'),
        ListTile(
          title: const Text('Manage Recurring Payments'),
          subtitle: const Text('View or delete automated payments'),
          leading: PureIcons.refresh(color: Colors.orange),
          onTap: () => Navigator.push( // coverage:ignore-line


              context,
              MaterialPageRoute( // coverage:ignore-line


                  builder: (_) => // coverage:ignore-line
                      const RecurringManagerScreen())),
        ),
        ListTile(
          title: const Text('Holiday Manager'),
          subtitle: const Text('Configure non-working days'),
          leading: PureIcons.calendar(color: Colors.red),
          onTap: () => Navigator.push( // coverage:ignore-line


              context,
              MaterialPageRoute( // coverage:ignore-line


                  builder: (_) => // coverage:ignore-line
                      const HolidayManagerScreen())),
        ),
        ListTile(
          title: const Text('Manage Categories'),
          subtitle: const Text('Add, edit, or delete categories'),
          leading: PureIcons.icon(Icons.category, color: Colors.blue),
          onTap: () => showDialog( // coverage:ignore-line


            context: context,
            builder: (context) => // coverage:ignore-line
                const CategoryManagerDialog(),
          ),
        ),
        SwitchListTile(
          title: const Text('Smart Calculator'),
          subtitle: const Text('Enable Quick Sum Tracker on transactions'),
          secondary: PureIcons.calculate(color: Colors.teal),
          value: ref.watch(smartCalculatorEnabledProvider),
          // coverage:ignore-start
          onChanged: (_) =>
              ref
                  .read(smartCalculatorEnabledProvider.notifier)
                  .toggle(),
          // coverage:ignore-end
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
                children: profiles
                    .map((p) => _buildProfileListItem(context, profiles, p))
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => // coverage:ignore-line
                  ListTile(title: Text('Error: $e')), // coverage:ignore-line
            ),
        _buildAddProfileItem(context),
      ],
    );
  }

  Widget _buildProfileListItem(
      BuildContext context, List<Profile> profiles, Profile p) {
    final isActive = p.id == ref.watch(activeProfileIdProvider);
    return ListTile(
      title: Text(p.name),
      subtitle: Text(isActive ? 'Active' : 'Tap to switch'),
      leading: CircleAvatar(
        backgroundColor:
            isActive ? Theme.of(context).primaryColor : Colors.grey[300],
        child: PureIcons.person(color: isActive ? Colors.white : Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: PureIcons.copy(),
            tooltip: 'Copy Categories from another profile',
            onPressed: () => _showCopyCategoriesDialog( // coverage:ignore-line


                context,
                ref, // coverage:ignore-line
                p.id), // coverage:ignore-line
          ),
          if (profiles.length > 1 && !isActive)
            IconButton(
              icon: PureIcons.deleteOutlined(color: Colors.red),
              onPressed: () => _showDeleteProfileDialog( // coverage:ignore-line


                  context,
                  ref, // coverage:ignore-line
                  p),
            ),
        ],
      ),
      onTap: isActive
          ? null
          : () {
              ref.read(activeProfileIdProvider.notifier).setProfile(p.id);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Switched to ${p.name}")));
            },
    );
  }

  Widget _buildAddProfileItem(BuildContext context) {
    return ListTile(
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
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIUtils.buildSectionHeader('Preferences'),
        ListTile(
          title: const Text('Currency'),
          subtitle: Text('Current: ${() {
            final code = ref.watch(currencyProvider);
            if (code == 'en_IN') return 'Indian Rupee (₹)';
            if (code == 'en_GB') return 'British Pound (£)';
            if (code == 'en_EU') return 'Euro (€)';
            return 'US Dollar (\$)';
          }()}'),
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
              FilteringTextInputFormatter.allow(RegexUtils.amountExp)
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
              final verified =
                  await _showVerifyPinDialog(context); // coverage:ignore-line
              if (verified) {
                // coverage:ignore-start
                setState(
                    () => _isAppLockEnabled = false);
                await ref
                    .read(storageServiceProvider)
                    .setAppLockEnabled(false);
                // coverage:ignore-end
              }
            }
          },
        ),
        if (_isAppLockEnabled)
          ListTile(
            title: const Text('Change PIN'),
            leading: PureIcons.security(size: 20),
            onTap: () => _showSetPinDialog(context), // coverage:ignore-line
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
          onTap: () => // coverage:ignore-line
              UIUtils.showCommonAboutDialog( // coverage:ignore-line


                  context,
                  AppConstants.appVersion),
        ),
        if (_installPrompt != null) ...[
          const Divider(),
          ListTile( // coverage:ignore-line


            title: const Text('Install App'),
            subtitle: const Text('Add to Home Screen for Offline use'),
            leading: const Icon(Icons.install_mobile, color: Colors.blue),
            // coverage:ignore-start
            onTap: () async {
              if (_installPrompt != null) {
                await ConnectivityPlatform.triggerInstallPrompt(
                    _installPrompt!);
                setState(() => _installPrompt = null);
            // coverage:ignore-end
              }
            },
          ),
        ] else if (kIsWeb &&
            (defaultTargetPlatform == // coverage:ignore-line
                    TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS)) ...[ // coverage:ignore-line


          const Divider(),
          ListTile( // coverage:ignore-line


            title: const Text('Install on iPhone'),
            subtitle: const Text('Tap "Share" → "Add to Home Screen"'),
            leading: const Icon(Icons.ios_share, color: Colors.blue),
            onTap: () => showDialog( // coverage:ignore-line


              context: context,
              builder: (ctx) => AlertDialog( // coverage:ignore-line


                title: const Text("Install on iPhone"),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("To install this app for offline use:"),
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
                // coverage:ignore-start
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                // coverage:ignore-end
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
  // coverage:ignore-end
        const SnackBar(
            content:
                Text("Internet connection required to check for updates.")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar( // coverage:ignore-line


      const SnackBar(content: Text("Checking for updates...")),
    );

    final updateFound = await _checkForWebUpdate(); // coverage:ignore-line

    if (!updateFound) {
      if (mounted) await _showUpToDateDialog(); // coverage:ignore-line
      return;
    }

    if (!mounted) return; // coverage:ignore-line
    await _showUpdateConfirmDialog(); // coverage:ignore-line
  }

  Future<bool> _checkForWebUpdate() async { // coverage:ignore-line


    if (!kIsWeb) return false;

    // coverage:ignore-start
    if (ref.read(isOfflineProvider)) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
    // coverage:ignore-end
          const SnackBar(
            content: Text("Offline: Unable to check for updates."),
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
  // coverage:ignore-end
        title: const Text('Up to Date'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'You are consistent with the latest version (${AppConstants.appVersion}).'),
            SizedBox(height: 16),
            Text('If you don\'t see expected changes, you can force a reload.'),
          ],
        ),
        // coverage:ignore-start
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
        // coverage:ignore-end
              child: const Text('OK')),
          // coverage:ignore-start
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          // coverage:ignore-end
              child: const Text('Force Reload')),
        ],
      ),
    );

    if (wantReload == true && kIsWeb) { // coverage:ignore-line


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
        title: const Text('Update Application'),
        content: const Text(
            'This will clear the application cache and reload the latest version. Your local data (Hive) will remain safe. Do you want to proceed?'),
        // coverage:ignore-start
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
        // coverage:ignore-end
              child: const Text('Cancel')),
          ElevatedButton( // coverage:ignore-line


              onPressed: () => // coverage:ignore-line
                  Navigator.pop(context, true), // coverage:ignore-line
              child: const Text('Update & Reload')),
        ],
      ),
    );

    if (confirmed == true) { // coverage:ignore-line


      if (kIsWeb) {
        try {
          await ConnectivityPlatform
              .reloadAndClearCache(); // coverage:ignore-line
        } catch (e) {
          // Reload failure
        }
      } else {
        if (!mounted) return; // coverage:ignore-line
        ScaffoldMessenger.of(context).showSnackBar( // coverage:ignore-line


          const SnackBar(
              content: Text('Update not available for this platform.')),
        );
      }
    }
  }

  Future<void> _backupToCloud() async { // coverage:ignore-line


    // Check PIN if enabled
    if (_isAppLockEnabled) { // coverage:ignore-line


      final verified =
          await _showVerifyPinDialog(context); // coverage:ignore-line
      if (!verified) return;
    }

    // coverage:ignore-start
    if (!mounted) return;
    final passcode = await _promptForEncryptionPasscode(
        context,
    // coverage:ignore-end
        "Cloud Backup",
        "Secure your sensitive financial data (accounts, transactions, etc.) with a passcode. This passcode is NEVER stored and is required to restore.");

    if (passcode == null) return; // User Cancelled

    setState(() => _isUploading = true); // coverage:ignore-line
    try {
      // coverage:ignore-start
      await ref
          .read(cloudSyncServiceProvider)
          .syncToCloud(passcode: passcode)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception("Request timed out. Please check your connection.");
      // coverage:ignore-end
      });

      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Cloud Sync Success!")));
      // coverage:ignore-end
      }
    } catch (e) {
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Sync Error: $e")));
      // coverage:ignore-end
      }
    } finally {
      if (mounted) setState(() => _isUploading = false); // coverage:ignore-line
    }
  }

  Future<void> _backupToZip() async {
    // Check PIN if enabled
    if (_isAppLockEnabled) {
      final verified =
          await _showVerifyPinDialog(context); // coverage:ignore-line
      if (!verified) return;
    }

    setState(() => _isUploading = true);
    try {
      // 1. Generate ZIP bytes
      final bytes =
          await ref.read(jsonDataServiceProvider).createBackupPackage();

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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Backup Failed: $e')));
      // coverage:ignore-end
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _restoreFromZip() async {
    // 1. Check PIN first if enabled (User requirement: PIN should pop immediately)
    if (_isAppLockEnabled) {
      final verified = await _showVerifyPinDialog(context);
      if (!verified) return;
    }

    // 2. Pick File
    final bytes = await ref
        .read(fileServiceProvider)
        .pickFile(allowedExtensions: ['zip']);
    if (bytes == null) return;

    if (!mounted) return;
    final confirmed = await _confirmRestoreFromZip();
    if (!confirmed) return;

    await _performZipRestore(bytes);
  }

  Future<bool> _confirmRestoreFromZip() async {
    final decision = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Restoring from ZIP"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Are you sure?"),
            SizedBox(height: 8),
            Text(
                "This will PERMANENTLY WIPE all local data and replace it with the backup content."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => // coverage:ignore-line
                Navigator.pop(ctx, 'CANCEL'), // coverage:ignore-line
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'RESTORE'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Yes, Restore"),
          ),
        ],
      ),
    );
    return decision == 'RESTORE';
  }

  Future<void> _performZipRestore(dynamic bytes) async {
    setState(() => _isDownloading = true);
    try {
      // 1. Capture pure authentic local state before overwriting DB
      final wasLoggedInBeforeRestore = ref.read(isLoggedInProvider);
      final wasLocalModeBeforeRestore = ref.read(localModeProvider);

      final stats =
          await ref.read(jsonDataServiceProvider).restoreFromPackage(bytes);

      if (mounted) {
        // 2. Prevent the ZIP DB payload from corrupting our auth session
        await ref
            .read(storageServiceProvider)
            .setAuthFlag(wasLoggedInBeforeRestore);

        // 3. Keep localMode persistent
        ref.read(localModeProvider.notifier).value = wasLocalModeBeforeRestore;

        ref.invalidate(accountsProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(loansProvider);
        ref.invalidate(recurringTransactionsProvider);
        ref.invalidate(profilesProvider);

        final summaryItems =
            stats.entries.map((e) => "${e.key}: ${e.value}").toList();

        if (!mounted) return;

        await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text("Restore Complete"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Restored items:",
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                              MaterialPageRoute(
                                  builder: (_) => const AuthWrapper()),
                              (route) => false);
                          // coverage:ignore-end
                        },
                        child: const Text("OK, Reload"))
                  ],
                ));
      }
    } catch (e) {
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore Failed: $e')));
      // coverage:ignore-end
      }
    } finally {
      if (mounted) { // coverage:ignore-line


        setState(() => _isDownloading = false); // coverage:ignore-line
      }
    }
  }

  Future<void> _smartRestoreFlow() async { // coverage:ignore-line

    if (!await _verifyAppLockIfNeeded()) return; // coverage:ignore-line

    // 1. Safety Dialog
    if (!mounted) return; // coverage:ignore-line
    final confirmed = await _showRestoreWarningDialog(); // coverage:ignore-line
    if (!confirmed) return;

    // coverage:ignore-start
    if (!mounted) return;
    final passcode = await _promptForEncryptionPasscode(
        context,
    // coverage:ignore-end
        "Cloud Restore",
        "If your cloud backup was encrypted, please enter the passcode. If it was not encrypted, leave this blank and continue.",
        isRestore: true);

    if (passcode == null) return; // User cancelled

    // 2. Perform Restore
    await _executeCloudRestore(passcode); // coverage:ignore-line
  }

  // coverage:ignore-start
  Future<bool> _verifyAppLockIfNeeded() async {
    if (_isAppLockEnabled) {
      final verified = await _showVerifyPinDialog(context);
  // coverage:ignore-end
      if (!verified) return false;
    }
    return true;
  }

  // coverage:ignore-start
  Future<bool> _showRestoreWarningDialog() async {
    final decision = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
  // coverage:ignore-end
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
          ],
        ),
        // coverage:ignore-start
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'CANCEL'),
        // coverage:ignore-end
            child: const Text("Cancel"),
          ),
          // coverage:ignore-start
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'RESTORE'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          // coverage:ignore-end
            child: const Text("Yes, Restore"),
          ),
        ],
      ),
    );
    return decision == 'RESTORE'; // coverage:ignore-line
  }

  Future<void> _executeCloudRestore(String passcode) async { // coverage:ignore-line
    setState(() => _isDownloading = true); // coverage:ignore-line
    try {
      // coverage:ignore-start
      await ref
          .read(cloudSyncServiceProvider)
          .restoreFromCloud(passcode: passcode)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception("Request timed out. Please check your connection.");
      // coverage:ignore-end
      });

      if (mounted) { // coverage:ignore-line
        // Force refresh providers
        // coverage:ignore-start
        ref.invalidate(accountsProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(loansProvider);
        ref.invalidate(recurringTransactionsProvider);
        // coverage:ignore-end

        ScaffoldMessenger.of(context).showSnackBar( // coverage:ignore-line
            const SnackBar(content: Text("Restore Complete! Reloading...")));
        // coverage:ignore-start
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false);
        // coverage:ignore-end
      }
    } catch (e) {
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Restore Failed: $e")));
      // coverage:ignore-end
      }
    } finally {
      if (mounted) { // coverage:ignore-line
        setState(() => _isDownloading = false); // coverage:ignore-line
      }
    }
  }

  Future<void> _deactivateAccountFlow() async {
    // Check PIN if enabled
    if (_isAppLockEnabled) {
      final verified =
          await _showVerifyPinDialog(context); // coverage:ignore-line
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
            onPressed: () => Navigator.pop(ctx, false), // coverage:ignore-line
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
        throw Exception( // coverage:ignore-line
            "Re-authentication Failed: ${response.message}"); // coverage:ignore-line
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
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Deactivation Failed: $e")),
      // coverage:ignore-end
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _clearCloudDataFlow() async {
    // Check PIN if enabled
    if (_isAppLockEnabled) {
      final verified =
          await _showVerifyPinDialog(context); // coverage:ignore-line
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
            onPressed: () => Navigator.pop(ctx, false), // coverage:ignore-line
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
        throw Exception( // coverage:ignore-line
            "Authentication Failed: ${response.message}"); // coverage:ignore-line
      }

      await ref.read(cloudSyncServiceProvider).deleteCloudData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cloud Data Cleared Successfully.")),
        );
      }
    } catch (e) {
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Clear Failed: $e")),
      // coverage:ignore-end
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

  Future<String?> _promptForEncryptionPasscode( // coverage:ignore-line


      BuildContext context,
      String title,
      String message,
      {bool isRestore = false}) async {
    final controller = TextEditingController(); // coverage:ignore-line
    bool usePasscode = true;

    final result = await showDialog<String>( // coverage:ignore-line


      context: context,
      barrierDismissible: false,
      // coverage:ignore-start
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
      // coverage:ignore-end
            mainAxisSize: MainAxisSize.min,
            children: [ // coverage:ignore-line


              Text(message), // coverage:ignore-line
              const SizedBox(height: 8),
              const Text(
                "Note: Categories are stored as metadata and are NOT encrypted.",
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              if (!isRestore) ...[ // coverage:ignore-line


                SwitchListTile( // coverage:ignore-line


                  title: const Text("Encrypt Backup?"),
                  value: usePasscode,
                  onChanged: (val) => // coverage:ignore-line
                      setState(() => usePasscode = val), // coverage:ignore-line
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (usePasscode || isRestore) ...[ // coverage:ignore-line


                TextField( // coverage:ignore-line


                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Encryption Passcode",
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ],
          ),
          // coverage:ignore-start
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
          // coverage:ignore-end
              child: const Text("CANCEL"),
            ),
            ElevatedButton( // coverage:ignore-line


              onPressed: () => _handleEncryptionSubmit( // coverage:ignore-line


                  context,
                  controller,
                  isRestore,
                  usePasscode),
              child: Text(_getEncryptionButtonLabel( // coverage:ignore-line


                  isRestore,
                  usePasscode)),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  void _handleEncryptionSubmit( // coverage:ignore-line


      BuildContext context,
      TextEditingController controller,
      bool isRestore,
      bool usePasscode) {
    if (!isRestore && !usePasscode) {
      Navigator.pop(context, ""); // coverage:ignore-line
      return;
    }
    if (isRestore || controller.text.isNotEmpty) { // coverage:ignore-line


      Navigator.pop(context, controller.text); // coverage:ignore-line
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar( // coverage:ignore-line


      const SnackBar(content: Text("Please enter a passcode")),
    );
  }

  String _getEncryptionButtonLabel(bool isRestore, bool usePasscode) { // coverage:ignore-line


    if (isRestore) return "RESTORE";
    if (usePasscode) return "ENCRYPT & BACKUP";
    return "BACKUP (UNENCRYPTED)";
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
              inputFormatters: [


                FilteringTextInputFormatter.digitsOnly
              ],
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
            onPressed: () => Navigator.pop(context, false), // coverage:ignore-line
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              final storedPin = ref.read(storageServiceProvider).getAppPin();
              if (controller.text == storedPin) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar( // coverage:ignore-line


                  const SnackBar(content: Text("Incorrect PIN")),
                );
                controller.clear(); // coverage:ignore-line
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
    );
  }

  List<Widget> _buildPinDialogActions(BuildContext context, dynamic storage,
      TextEditingController controller, String? currentPin) {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context), // coverage:ignore-line
        child: const Text("CANCEL"),
      ),
      if (currentPin != null)
        // coverage:ignore-start
        ElevatedButton(
          onPressed: () => _handleUseExistingPin(context, storage),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        // coverage:ignore-end
          child: const Text("USE EXISTING"),
        ),
      ElevatedButton(
        onPressed: () => _handleSaveAndEnableLock(context, storage, controller),
        child: const Text("SAVE & ENABLE"),
      ),
    ];
  }

  Future<void> _handleUseExistingPin( // coverage:ignore-line


      BuildContext context,
      dynamic storage) async {
    // coverage:ignore-start
    await storage.setAppLockEnabled(true);
    setState(() => _isAppLockEnabled = true);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
    // coverage:ignore-end
        const SnackBar(content: Text("App Lock Enabled")),
      );
    }
  }

  Future<void> _handleSaveAndEnableLock(BuildContext context, dynamic storage,
      TextEditingController controller) async {
    if (controller.text.length != 4) return;
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

  void _showDeleteProfileDialog( // coverage:ignore-line


      BuildContext context,
      WidgetRef ref,
      Profile profile) {
    showDialog( // coverage:ignore-line


      context: context,
      builder: (context) => AlertDialog( // coverage:ignore-line


        title: const Text("Delete Profile?"),
        // coverage:ignore-start
        content: Text(
            "This will PERMANENTLY delete the profile '${profile.name}' and ALL its associated data (accounts, transactions, loans). This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
        // coverage:ignore-end
            child: const Text("CANCEL"),
          ),
          // coverage:ignore-start
          TextButton(
            onPressed: () async {
              await ref.read(storageServiceProvider).deleteProfile(profile.id);
              ref.invalidate(profilesProvider);
          // coverage:ignore-end
              // If we deleted the active profile, switch to default
              if (ref.read(activeProfileIdProvider) == profile.id) { // coverage:ignore-line


                ref
                    // coverage:ignore-start
                    .read(activeProfileIdProvider
                        .notifier)
                    .setProfile('default');
                    // coverage:ignore-end
              }
              if (context.mounted) { // coverage:ignore-line


                Navigator.pop(context); // coverage:ignore-line
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCopyCategoriesDialog( // coverage:ignore-line


      BuildContext context,
      WidgetRef ref,
      String targetProfileId) {
    final profilesAsync = ref.read(profilesProvider); // coverage:ignore-line
    profilesAsync.whenData((profiles) { // coverage:ignore-line


      final otherProfiles =
          // coverage:ignore-start
          profiles.where((p) => p.id != targetProfileId).toList();
      if (otherProfiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          // coverage:ignore-end
          const SnackBar(content: Text('No other profiles to copy from.')),
        );
        return;
      }

      showDialog( // coverage:ignore-line


        context: context,
        builder: (c) => AlertDialog( // coverage:ignore-line


          title: const Text('Copy Categories'),
          content: SingleChildScrollView( // coverage:ignore-line


            child: Column( // coverage:ignore-line


              mainAxisSize: MainAxisSize.min,
              children: otherProfiles
                  // coverage:ignore-start
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
                  // coverage:ignore-end
                            );
                            Navigator.pop(c); // coverage:ignore-line
                          }
                        },
                      ))
                  .toList(), // coverage:ignore-line
            ),
          ),
          // coverage:ignore-start
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Close')),
          // coverage:ignore-end
          ],
        ),
      );
    });
  }
}
