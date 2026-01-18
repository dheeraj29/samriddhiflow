import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/core/app_constants.dart';
import '../utils/network_utils.dart';
import '../utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../providers.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../theme/app_theme.dart';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  StreamSubscription? _connectivitySubscription;
  bool _isRedirectingLocal = false;
  bool _bootGracePeriodFinished = false;

  @override
  void initState() {
    super.initState();
    // 1. Initial State Check (Read sessionStorage immediately before it gets cleared)
    if (kIsWeb) {
      try {
        final pending =
            web.window.sessionStorage.getItem('auth_redirect_pending');
        if (pending == 'true') {
          _isRedirectingLocal = true;
          // Safety timeout: If Firebase fails to sign us in within 10s, release the screen
          Future.delayed(const Duration(seconds: 10), () {
            if (mounted && _isRedirectingLocal) {
              DebugLogger().log("AuthWrapper: Redirect Timeout reached.");
              setState(() => _isRedirectingLocal = false);
            }
          });
        }
      } catch (e) {
        debugPrint("Error reading session storage: $e");
      }
    }

    // 2. Start Boot Grace Period (5 seconds)
    // This prevents "Ghost Session" logic from firing until the stream is stable.
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _bootGracePeriodFinished = true;
      }
    });

    // 3. Initial Framework Check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSafeListeners();
    });
  }

  void _initSafeListeners() {
    // 1. Initial Connectivity Check
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      // 1. Wait for Storage FIRST (Critical for background revalidation safety)
      await ref.read(storageInitializerProvider.future);

      // 2. Check offline status to avoid unnecessary waits
      final isOffline = await NetworkUtils.isOffline();
      if (isOffline) {
        DebugLogger().log("AuthWrapper: Offline. Skipping revalidation.");
        return;
      }

      // 3. If online, wait for Firebase to settle
      await ref.read(firebaseInitializerProvider.future).timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );

      DebugLogger().log("AuthWrapper: Online. Revalidating Session...");
      await _revalidateSession();
    } catch (e) {
      DebugLogger().log("AuthWrapper: Initial Check suppressed error: $e");
    }
  }

  Future<void> _revalidateSession() async {
    final authService = ref.read(authServiceProvider);

    try {
      final user = authService.currentUser;
      if (user != null && !authService.isSignOutInProgress) {
        debugPrint("Connectivity restored: Revalidating session...");
        await authService.reloadUser(ref);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'user-disabled' ||
          e.code == 'min-app-version-error') {
        DebugLogger().log("Critical Session Error (${e.code}): Force Logout.");
        await authService.signOut(ref);
      } else {
        DebugLogger().log("Revalidation warning (${e.code}) - Keeping Session");
      }
    } catch (e) {
      debugPrint("Revalidation warning: $e");
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storageInit = ref.watch(storageInitializerProvider);

    // BACKGROUND VERIFICATION:
    ref.listen(authStreamProvider, (previous, next) async {
      try {
        if (!storageInit.hasValue) return;

        final authService = ref.read(authServiceProvider);

        // Finalize redirect weight if user arrives
        if (next.value != null && _isRedirectingLocal) {
          setState(() => _isRedirectingLocal = false);
        }

        if (!_bootGracePeriodFinished ||
            _isRedirectingLocal ||
            authService.isSignOutInProgress ||
            ref.read(logoutRequestedProvider)) {
          return;
        }

        final isOffline = await NetworkUtils.isOffline();
        final isLoggedIn = ref.read(isLoggedInProvider);
        final user = next.value;

        if (next.hasValue && user == null && !isOffline && isLoggedIn) {
          DebugLogger()
              .log("AuthWrapper: Ghost Session detected. Cleaning up.");
          await authService.signOut(ref);
        }
      } catch (e) {
        DebugLogger()
            .log("AuthWrapper: Background Listener suppressed error: $e");
      }
    });

    // Removed: "Hard Guard" to prevent logout hangs.
    // We now rely on reactive Hive state to snap to Login screen.

    return storageInit.when(
      loading: () => _buildLoadingScreen("Starting ${AppConstants.appName}..."),
      error: (e, s) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.amber),
                const SizedBox(height: 16),
                Text(
                  "Storage Access Issue",
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final isOffline = await NetworkUtils.isOffline();
                    if (isOffline) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                "Still Offline. Please check your data/WiFi."),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      // ignore: unused_result
                      ref.refresh(storageInitializerProvider);
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (_) {
        // 1. FAST PATH: Connectivity (Synchronous initial check on Web)
        final isOffline = ref.watch(isOfflineProvider);
        final isPersistentLogin = ref.watch(isLoggedInProvider);

        if (isOffline) {
          // Check for actual value, not AsyncValue state
          if (isPersistentLogin) {
            DebugLogger()
                .log("AuthWrapper: Persistent + Offline. Entry Granted.");
            return const DashboardScreen();
          }

          return _buildErrorScreen(
            context,
            title: "Connection Required",
            message:
                "You are currently offline. Please connect to the internet to sign in.",
            icon: Icons.wifi_off_rounded,
            onRetry: () async {
              // Manual retry just refreshes the providers
              // ignore: unused_result
              ref.refresh(isOfflineProvider);
              if (ref.read(isOfflineProvider) == false) {
                // Check for actual value
                // ignore: unused_result
                ref.refresh(firebaseInitializerProvider);
              }
            },
          );
        }

        // 2. ONLINE PATH
        // Pre-fetch Firebase status in background if we think we are logged in
        if (isPersistentLogin) {
          // ignore: unused_result
          ref.read(firebaseInitializerProvider);
        }

        final firebaseInit = ref.watch(firebaseInitializerProvider);

        return firebaseInit.when(
          loading: () => _buildLoadingScreen(
              _isRedirectingLocal ? "Finalizing Account..." : "Connecting..."),
          error: (e, s) {
            DebugLogger().log("AuthWrapper: Firebase Init Error: $e");
            final isTimeout = e.toString().toLowerCase().contains("timeout");
            return _buildErrorScreen(
              context,
              title: isTimeout ? "Slow Connection" : "Connection Required",
              message: isTimeout
                  ? "Connection reached a timeout. Please try again."
                  : "You are currently offline. Please connect to the internet to sign in.",
              icon: isTimeout ? Icons.timer_outlined : Icons.wifi_off_rounded,
              onRetry: () async {
                // ignore: unused_result
                ref.refresh(firebaseInitializerProvider);
              },
            );
          },
          data: (_) => _buildAuthStream(context, isPersistentLogin),
        );
      },
    );
  }

  Widget _buildLoadingScreen(String message) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(message,
                style: AppTheme.offlineSafeTextStyle
                    .copyWith(color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Text(AppConstants.appVersion,
                style: AppTheme.offlineSafeTextStyle
                    .copyWith(color: Colors.grey[400], fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthStream(BuildContext context, bool isPersistentLogin) {
    final authState = ref.watch(authStreamProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // Sync flag if user is active (Auto-Login Recovery)
          _ensureOptimisticFlag();
          return const DashboardScreen();
        }

        if (_isRedirectingLocal) {
          return _buildLoadingScreen("Finalizing Account...");
        }

        // If we reached here, user is null.
        // We already checked for offline at the top level of build(),
        // so we can assume we are online here.
        return const LoginScreen();
      },
      loading: () => _buildLoadingScreen("Verifying Session..."),
      error: (e, s) {
        DebugLogger().log("AuthWrapper: Auth Stream Error: $e");
        return const LoginScreen();
      },
    );
  }

  Widget _buildErrorScreen(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required VoidCallback onRetry,
  }) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: AppTheme.primary.withOpacity(0.8)),
              const SizedBox(height: 24),
              Text(
                title,
                style: AppTheme.offlineSafeTextStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: AppTheme.offlineSafeTextStyle.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("RETRY CONNECTION"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // ignore: unused_result
                    ref.read(localModeProvider.notifier).value = true;
                  },
                  child: const Text("Continue in Local Mode (Debug Only)"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ensureOptimisticFlag() async {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        if (box.get('isLoggedIn', defaultValue: false) == false) {
          DebugLogger().log("AuthWrapper: Setting Optimistic Flag.");
          await box.put('isLoggedIn', true);
        }
      }
    } catch (e) {
      DebugLogger().log("AuthWrapper: Failed to set Optimistic Flag: $e");
    }
  }
}
