import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/core/app_constants.dart';
import '../utils/network_utils.dart';
import '../utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../navigator_key.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../theme/app_theme.dart';
import '../utils/connectivity_platform.dart';
import 'package:flutter/foundation.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _isRedirectingLocal = false;
  bool _bootGracePeriodFinished = false;
  bool _hasVerificationTimedOut = false;
  bool _isSlowConnection = false;
  Timer? _verificationSafetyTimer;
  Timer? _slowConnectionTimer;
  Timer? _bootGraceTimer;
  Timer? _autoHealTimer;

  @override
  void initState() {
    super.initState();
    // 1. Initial State Check (Read sessionStorage immediately before it gets cleared)
    if (kIsWeb) {
      try {
        final pending =
            ConnectivityPlatform.getSessionStorageItem('auth_redirect_pending');
        if (pending == 'true') {
          _isRedirectingLocal = true;
          // Safety timeout: If Firebase fails to sign us in within 120s, release the screen
          Future.delayed(const Duration(seconds: 120), () {
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
    // 2. Start Boot Grace Period (5 seconds)
    _bootGraceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _bootGracePeriodFinished = true;
      }
    });

    // 3. Initial Framework Check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSafeListeners();
    });

    // 4. Session Verification Safety Timeout
    _verificationSafetyTimer = Timer(const Duration(seconds: 120), () {
      if (mounted && !_hasVerificationTimedOut) {
        setState(() => _hasVerificationTimedOut = true);
        DebugLogger()
            .log("AuthWrapper: Session Verification Timeout triggered.");
      }
    });

    // 5. Slow Connection Detector
    _slowConnectionTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && !_isSlowConnection) {
        setState(() => _isSlowConnection = true);
        DebugLogger().log("AuthWrapper: Slow Connection detected.");
      }
    });
  }

  @override
  void dispose() {
    _verificationSafetyTimer?.cancel();
    _slowConnectionTimer?.cancel();
    _bootGraceTimer?.cancel();
    _autoHealTimer?.cancel();
    super.dispose();
  }

  void _initSafeListeners() {
    // 1. Initial Connectivity Check
    _checkInitialConnectivity();
  }

  void _setupAutoHealTimer() {
    _autoHealTimer?.cancel();
    _autoHealTimer = Timer(const Duration(seconds: 15), () async {
      if (mounted && _hasVerificationTimedOut && !ref.read(isOfflineProvider)) {
        final hasInternet = await NetworkUtils.hasActualInternet();
        if (hasInternet && mounted) {
          DebugLogger().log(
              "AuthWrapper: Background Reachability Detected. Auto-healing...");
          ref.invalidate(firebaseInitializerProvider);
        }
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      // 1. Wait for Storage FIRST (Critical for background revalidation safety)
      await ref.read(storageInitializerProvider.future);

      // 2. Check offline status to avoid unnecessary waits
      final checkFn = ref.read(connectivityCheckProvider);
      final isOffline = await checkFn();
      if (isOffline) {
        DebugLogger().log("AuthWrapper: Offline. Skipping revalidation.");
        // If we are persistently logged in, mark as "Timed Out" immediately
        // so we enter Failover Mode (Dashboard) and stay there when network returns.
        if (ref.read(isLoggedInProvider) && mounted) {
          setState(() => _hasVerificationTimedOut = true);
        }
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
        // OPTIONAL: We could show a dialog here if we had context, but for now we trust the error.
        await authService.signOut(ref);
      } else if (e.code == 'network-request-failed' ||
          e.code == 'unavailable') {
        DebugLogger()
            .log("Revalidation: Network Issue (${e.code}). Keeping Session.");
      } else {
        DebugLogger().log("Revalidation warning (${e.code}) - Keeping Session");
      }
    } catch (e) {
      debugPrint("Revalidation warning: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final storageInit = ref.watch(storageInitializerProvider);

    // 1. RE-INITIALIZE ON NETWORK RECOVERY
    ref.listen(isOfflineProvider, (previous, next) async {
      if (!_bootGracePeriodFinished) return; // Ignore startup noise

      final wasOffline = previous ?? false;
      final isOnline = !next;
      if (wasOffline && isOnline) {
        // Wait a small moment for DNS/Interface to settle
        await Future.delayed(const Duration(seconds: 2));

        // ACTUAL reachability check
        final hasActualInternet = await NetworkUtils.hasActualInternet();
        if (!hasActualInternet) {
          DebugLogger().log(
              "AuthWrapper: Network event Online but ACTUAL reachability failed. Staying in failover.");
          return;
        }

        DebugLogger().log("AuthWrapper: Network Restored. Re-triggering Init.");
        ref.invalidate(firebaseInitializerProvider);

        // Wait for Firebase to settle then revalidate
        try {
          await ref
              .read(firebaseInitializerProvider.future)
              .timeout(const Duration(seconds: 10));
          await _revalidateSession();
        } catch (e) {
          DebugLogger().log("AuthWrapper: Restoration revalidate failed: $e");
        }
      }
    });

    // 1.0 GLOBAL LOGOUT NAVIGATION
    ref.listen(logoutRequestedProvider, (previous, next) {
      if (next == true) {
        DebugLogger()
            .log("AuthWrapper: Logout requested. Clearing navigator stack.");
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });

    // 1.1 AUTO-HEAL: Background Reachability Retry
    // If we are currently "Timed Out" (Offline Failover Mode), but the interface
    // says we are Online, we should periodically check if ACTUAL internet
    // has finally arrived (DNS settled).
    if (_hasVerificationTimedOut && !ref.watch(isOfflineProvider)) {
      _setupAutoHealTimer();
    } else {
      _autoHealTimer?.cancel(); // Cancel if conditions are no longer met
    }

    // 2. BACKGROUND VERIFICATION:
    ref.listen(authStreamProvider, (previous, next) async {
      try {
        if (!storageInit.hasValue) return;

        final authService = ref.read(authServiceProvider);

        // Finalize redirect weight if user arrives
        if (next.value != null && _isRedirectingLocal) {
          setState(() => _isRedirectingLocal = false);
        }

        final firebaseInit = ref.read(firebaseInitializerProvider);
        final isLoggedIn = ref.read(isLoggedInProvider);
        final user = next.value;

        debugPrint(
            "DEBUG: Listener fired. BootFinished: $_bootGracePeriodFinished, Redirecting: $_isRedirectingLocal, FirebaseInit: ${firebaseInit.isLoading}, SignOut: ${authService.isSignOutInProgress}");

        if (!_bootGracePeriodFinished ||
            // _isRedirectingLocal should not block logic, it's just a UI state
            firebaseInit
                .isLoading || // Strict Guard: Wait for initialization to finish
            firebaseInit
                .isRefreshing || // Strict Guard: Wait for re-initialization to finish
            !firebaseInit.hasValue ||
            authService.isSignOutInProgress ||
            ref.read(logoutRequestedProvider)) {
          return;
        }

        final checkFn = ref.read(connectivityCheckProvider);
        final isOffline = await checkFn();

        debugPrint(
            "Ghost Session Check Logic: next.hasValue=${next.hasValue} user=$user isOffline=$isOffline isLoggedIn=$isLoggedIn");

        // 3. GHOST SESSION DETECTION (Prompt User instead of Force Logout)
        if (next.hasValue && user == null && !isOffline && isLoggedIn) {
          // Extra Guard: Wait for 30s before flagging it
          await Future.delayed(const Duration(seconds: 30));
          final stillOffline = await checkFn();

          if (!stillOffline && context.mounted) {
            DebugLogger()
                .log("AuthWrapper: Ghost Session confirmed. Prompting user.");
            // Only show if not already showing a dialog or snackbar loop
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    const Text("Session verification failed. Sync paused."),
                duration: const Duration(seconds: 10),
                action: SnackBarAction(
                  label: "FIX",
                  onPressed: () => _showSessionFixDialog(context, ref),
                ),
              ),
            );
          }
        }

        // 4. AUTO-RESTORE CHECK
        // Fix: Don't rely on 'isLoggedIn' (local flag) for fresh installs/logins.
        // If we have a valid firebase user, and local data is empty, we MUST restore.
        if (next.value != null) {
          final storage = ref.read(storageServiceProvider);
          final accounts = storage.getAccounts();
          if (accounts.isEmpty) {
            DebugLogger().log(
                "AuthWrapper: Local data empty. Triggering Auto-Restore...");

            // Run in background, don't await blocking the UI
            ref.read(cloudSyncServiceProvider).restoreFromCloud().then((_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Cloud Restore Completed"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
                // Refresh providers to show data
                ref.invalidate(accountsProvider);
                ref.invalidate(transactionsProvider);
                // Ensure flag is set after successful restore
                _ensureOptimisticFlag();
              }
            }).catchError((e) {
              DebugLogger().log("AuthWrapper: Auto-Restore failed/skipped: $e");
              // Optional: Show error only if it's not "No cloud data found"
              if (context.mounted && !e.toString().contains("No cloud data")) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Restore Info: ${e.toString()}")),
                );
              }
            });
          }
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
        final isOffline = ref.watch(isOfflineProvider);
        final isPersistentLogin = ref.watch(isLoggedInProvider);

        // 2. OFFLINE FAILOVER (User choice or auto-mode)
        if (isPersistentLogin && (isOffline || _hasVerificationTimedOut)) {
          return const DashboardScreen();
        }

        // 3. DEBUG BYPASS (Web Only)
        // Bypass authentication for quicker local testing
        if (kDebugMode && kIsWeb) {
          // Ensure isLoggedIn flag is set so other components behave correctly
          // We do this optimistically.
          return const DashboardScreen();
        }

        // 4. REGULAR OFFLINE GUARD (For guests/logged-out)
        if (isOffline && !isPersistentLogin) {
          return _buildErrorScreen(
            context,
            title: "Connection Required",
            message:
                "You are currently offline. Please connect to the internet to sign in.",
            icon: Icons.wifi_off,
            showOfflineBypass: false,
          );
        }

        // Pre-fetch Firebase status in background if we think we are logged in
        if (isPersistentLogin) {
          // ignore: unused_result
          ref.read(firebaseInitializerProvider);
        }

        final firebaseInit = ref.watch(firebaseInitializerProvider);

        // --- OPTIMIZATION: Background Revalidation ---
        // If we have a persistent local session, don't block the UI with a full-screen loading spinner
        // while Firebase is initializing or re-validating. Show the Dashboard optimistically.
        if (isPersistentLogin &&
            (firebaseInit.isLoading || !_bootGracePeriodFinished) &&
            !_isRedirectingLocal) {
          return _buildAuthStream(context, isPersistentLogin);
        }

        return firebaseInit.when(
          loading: () => _buildLoadingScreen(
            _isRedirectingLocal
                ? (_isSlowConnection
                    ? "Slow link. Finalizing Account..."
                    : "Finalizing Account...")
                : (_isSlowConnection
                    ? "Slow link. Connecting..."
                    : "Connecting..."),
            showOfflineBypass: isPersistentLogin && !_isRedirectingLocal,
          ),
          error: (e, s) {
            DebugLogger().log("AuthWrapper: Firebase Init Error: $e");
            final isTimeout = e.toString().toLowerCase().contains("timeout");

            // SOFT FAILOVER: If we are already logged in locally, don't show the error screen.
            // Just show a snackbar and let the user into the app (Offline Mode).
            if (isPersistentLogin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text("Connection failed. Switching to Offline Mode."),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              });
              return _buildAuthStream(context, isPersistentLogin);
            }

            return _buildErrorScreen(
              context,
              title: isTimeout ? "Slow Connection" : "Connection Required",
              message: isTimeout
                  ? "Connection reached a timeout. Please try again."
                  : "You are currently offline. Please connect to the internet to sign in.",
              icon: isTimeout ? Icons.timer : Icons.wifi_off,
              showOfflineBypass: isPersistentLogin,
            );
          },
          data: (_) => _buildAuthStream(context, isPersistentLogin),
        );
      },
    );
  }

  Widget _buildLoadingScreen(String message, {bool showOfflineBypass = false}) {
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
            if (_isSlowConnection && showOfflineBypass) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _hasVerificationTimedOut = true);
                },
                icon: const Icon(Icons.cloud_off_rounded),
                label: const Text("Continue Offline"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.grey[700],
                ),
              ),
            ],
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

        // --- PERSISTENT SESSION GUARD ---
        if (isPersistentLogin) {
          if (!_hasVerificationTimedOut) {
            // OPTIMIZATION: If we are already in a persistent session, just show the Dashboard.
            // Verification will happen in the background or via the Firebase init check above.
            return const DashboardScreen();
          } else {
            // Safety/Manual Timeout: Grant entry to local data
            DebugLogger()
                .log("AuthWrapper: Entering Dashboard via Offline Failover.");
            return const DashboardScreen();
          }
        }

        // If we reached here, user is null.
        // We already checked for offline at the top level of build(),
        // so we can assume we are online here.
        return const LoginScreen();
      },
      loading: () {
        if (isPersistentLogin) return const DashboardScreen();
        return _buildLoadingScreen("Verifying Session...",
            showOfflineBypass: isPersistentLogin);
      },
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
    bool showOfflineBypass = false,
  }) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 64, color: AppTheme.primary.withValues(alpha: 0.8)),
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
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(firebaseInitializerProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Retry Connection"),
              ),
              if (showOfflineBypass) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _hasVerificationTimedOut = true);
                  },
                  icon: const Icon(Icons.cloud_off_rounded),
                  label: const Text("Continue Offline"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSessionFixDialog(
      BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Session Issue"),
        content: const Text(
            "Your secure cloud session could not be restored. You can continue offline, try to reconnect, or login again."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Continue Offline"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.invalidate(firebaseInitializerProvider);
            },
            child: const Text("Retry"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authServiceProvider).signOut(ref);
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text("Login Again"),
          ),
        ],
      ),
    );
  }

  Future<void> _ensureOptimisticFlag() async {
    try {
      final storage = ref.read(storageServiceProvider);
      // We rely on StorageService to abstract the underlying box check if needed,
      // but getAuthFlag() usually returns default false if key missing.
      if (storage.getAuthFlag() == false) {
        DebugLogger().log("AuthWrapper: Setting Optimistic Flag.");
        await storage.setAuthFlag(true);
      }
    } catch (e) {
      DebugLogger().log("AuthWrapper: Failed to set Optimistic Flag: $e");
    }
  }
}
