import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/core/app_constants.dart';
import '../services/auth_service.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../widgets/pure_icons.dart';
import '../utils/ui_utils.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  bool _isRestoring = false;
  Timer? _safetyTimer;

  @override
  void dispose() {
    _safetyTimer?.cancel();
    super.dispose();
  }

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
                            ? Colors.white
                                .withValues(alpha: 0.05) // coverage:ignore-line
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
                  label: () {
                    if (_isLoading) {
                      return const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return Text(
                      'Continue with Google',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87),
                    );
                  }(),
                ),

                const SizedBox(height: 24),

                if (kDebugMode || Uri.base.host == 'localhost') ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      // coverage:ignore-line
                      ref.read(localModeProvider.notifier).value =
                          true; // coverage:ignore-line
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
        // coverage:ignore-line
        setState(() => _isLoading = false); // coverage:ignore-line
        // Special case: Sign in cancelled/returned from redirect without completion
        // (usually message will be error, but we ensure button isn't stuck)
        // coverage:ignore-start
        if (response.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login Status: ${response.message}')),
            // coverage:ignore-end
          );
        }
      }
    }

    // Safety fallback for Redirect: If we aren't unmounted (redirect hasn't happened yet)
    // and we are still loading, reset after 10s to let user try again.
    _safetyTimer?.cancel();
    _safetyTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        // coverage:ignore-line
        setState(() => _isLoading = false); // coverage:ignore-line
      }
    });
  }

  Future<void> _autoRestore() async {
    if (_isRestoring) return;
    try {
      if (ref.read(authServiceProvider).currentUser != null) {
        // SAFETY CHECK: Only auto-restore if local data is empty
        final storage = ref.read(storageServiceProvider);
        final hasData = storage.getAllAccounts().isNotEmpty ||
            storage.getAllTransactions().isNotEmpty;

        if (hasData) return;

        setState(() => _isLoading = true);
        await _performCloudRestoreOperation();
      }
    } catch (e) {
      // Auto-restore skipped or failed (offline or no cloud data)
    } finally {
      _invalidateProviders();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _invalidateProviders() {
    ref.invalidate(authStreamProvider);
    ref.invalidate(firebaseInitializerProvider);
    ref.invalidate(isLoggedInProvider);
  }

  Future<void> _performCloudRestoreOperation([String? passcode]) async {
    if (_isRestoring && passcode == null) return;
    setState(() => _isRestoring = true);
    final syncService = ref.read(cloudSyncServiceProvider);
    try {
      await syncService
          .restoreFromCloud(passcode: passcode)
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud Data Restored!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      await _handleAutoRestoreError(e);
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _handleAutoRestoreError(dynamic e) async {
    final errorStr = e.toString();
    if (errorStr.contains("Passcode required") ||
        errorStr.contains("Incorrect passcode")) {
      // coverage:ignore-line
      setState(() => _isLoading = false);
      final p = await UIUtils.showPasscodePrompt(
          context, errorStr.contains("Incorrect"));
      if (!mounted) return;
      if (p != null && p.isNotEmpty) {
        await _performCloudRestoreOperation(p);
      }
    } else if (!errorStr.contains("No cloud data")) {
      // coverage:ignore-line
      throw e;
    }
  }
}
