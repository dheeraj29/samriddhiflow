import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../theme/app_theme.dart';

class UIUtils {
  static Future<void> handleLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(logoutRequestedProvider.notifier).value = true;
      await ref.read(authServiceProvider).signOut(ref);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  static Widget buildSectionHeader(String title, {bool showDivider = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDivider) const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  static void showCommonAboutDialog(BuildContext context, String version) {
    showAboutDialog(
      context: context,
      applicationName: 'Samriddhi Flow',
      applicationVersion: version,
      applicationIcon: const FlutterLogo(size: 40),
      children: const [
        Text('Personal Finance Management made simple and secure.'),
      ],
    );
  }
}
