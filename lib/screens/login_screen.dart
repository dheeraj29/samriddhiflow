import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/core/app_constants.dart';
import '../services/auth_service.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../widgets/pure_icons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo or Icon
                PureIcons.lockPerson(
                    size: 80, color: Theme.of(context).primaryColor),
                const SizedBox(height: 32),
                const Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppConstants.appTagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 48),

                // Google Sign In Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.white,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white24
                              : Colors.grey.shade300,
                        )),
                    elevation: 0,
                  ),
                  icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                    height: 24,
                    // Note: SVG might need flutter_svg, using a fallback for now or simple icon
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.login),
                  ),
                  label: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          'Continue with Google',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87),
                        ),
                ),

                const SizedBox(height: 24),

                if (kDebugMode || Uri.base.host == 'localhost') ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(localModeProvider.notifier).value = true;
                    },
                    icon: PureIcons.cloudOff(size: 20),
                    label: const Text('Continue Offline / Use Locally'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final response = await ref.read(authServiceProvider).signInWithGoogle(ref);

    if (response.status == AuthStatus.success) {
      if (mounted) {
        await ref.read(isLoggedInProvider.notifier).setLoggedIn(true);
        // FORCE RE-EVALUATION of AuthWrapper immediately after flag is set
        ref.invalidate(isLoggedInProvider);
        await _autoRestore();
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        // Special case: Sign in cancelled/returned from redirect without completion
        // (usually message will be error, but we ensure button isn't stuck)
        if (response.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login Status: ${response.message}')),
          );
        }
      }
    }

    // Safety fallback for Redirect: If we aren't unmounted (redirect hasn't happened yet)
    // and we are still loading, reset after 10s to let user try again.
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
        debugPrint("Login: Safety timeout triggered.");
      }
    });
  }

  Future<void> _autoRestore() async {
    try {
      if (ref.read(authServiceProvider).currentUser != null) {
        // SAFETY CHECK: Only auto-restore if local data is empty
        final storage = ref.read(storageServiceProvider);
        final hasData = storage.getAllAccounts().isNotEmpty ||
            storage.getAllTransactions().isNotEmpty;

        if (hasData) {
          debugPrint("Auto-restore: Local data exists, skipping.");
          return;
        }

        setState(() => _isLoading = true);
        final syncService = ref.read(cloudSyncServiceProvider);
        await syncService
            .restoreFromCloud()
            .timeout(const Duration(seconds: 15));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cloud Data Restored!')),
          );
        }
      }
    } catch (e) {
      debugPrint("Auto-restore skipped or failed: $e");
    } finally {
      // Invalidate providers so Dashboard sees the new logged-in state and data
      // (This is safe to call even if unmounted as it updates the global Provider state)
      ref.invalidate(authStreamProvider);
      ref.invalidate(firebaseInitializerProvider);
      ref.invalidate(isLoggedInProvider);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
