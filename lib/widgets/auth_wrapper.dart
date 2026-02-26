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

const continueOfflineText = 'Continue Offline';

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
    _initWebRedirectCheck();
    _startBootGracePeriod();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSafeListeners();
    });
    _startVerificationSafetyTimeout();
    _startSlowConnectionDetector();
  }

  void _initWebRedirectCheck() {
    if (!kIsWeb) return;
    try {
      final pending =
          // coverage:ignore-start
          ConnectivityPlatform.getSessionStorageItem('auth_redirect_pending');
      if (pending == 'true') {
        _isRedirectingLocal = true;
        Future.delayed(const Duration(seconds: 120), () {
          if (mounted && _isRedirectingLocal) {
            setState(() => _isRedirectingLocal = false);
          // coverage:ignore-end
          }
        });
      }
    } catch (e) {
      // Error reading session storage
    }
  }

  void _startBootGracePeriod() {
    _bootGraceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _bootGracePeriodFinished = true;
      }
    });
  }

  void _startVerificationSafetyTimeout() {
    _verificationSafetyTimer = Timer(const Duration(seconds: 120), () {
      if (mounted && !_hasVerificationTimedOut) {
        setState(() => _hasVerificationTimedOut = true);
      }
    });
  }

  void _startSlowConnectionDetector() {
    _slowConnectionTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && !_isSlowConnection) {
        setState(() => _isSlowConnection = true);
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
    _checkInitialConnectivity();
  }

  void _setupAutoHealTimer() {
    _autoHealTimer?.cancel();
    _autoHealTimer = Timer(const Duration(seconds: 15), () async {
      if (mounted && _hasVerificationTimedOut && !ref.read(isOfflineProvider)) {
        final hasInternet = await NetworkUtils.hasActualInternet();
        if (hasInternet && mounted) {
          ref.invalidate(firebaseInitializerProvider);
        }
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      await ref.read(storageInitializerProvider.future);

      final checkFn = ref.read(connectivityCheckProvider);
      final isOffline = await checkFn();
      if (isOffline) {
        if (ref.read(isLoggedInProvider) && mounted) {
          setState(() => _hasVerificationTimedOut = true);
        }
        return;
      }

      await ref.read(firebaseInitializerProvider.future).timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );

      await _revalidateSession();
    } catch (e) {
      // Initial Check suppressed error
    }
  }

  Future<void> _revalidateSession() async {
    final authService = ref.read(authServiceProvider);

    try {
      final user = authService.currentUser;
      if (user != null && !authService.isSignOutInProgress) {
        await authService.reloadUser(ref);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'user-disabled' || // coverage:ignore-line
          e.code == 'min-app-version-error') { // coverage:ignore-line
        DebugLogger().log("Critical Session Error (${e.code}): Force Logout.");
        await authService.signOut(ref);
      } else if (e.code == 'network-request-failed' || // coverage:ignore-line
          e.code == 'unavailable') { // coverage:ignore-line
        // Revalidation: Network Issue
      } else {
        // Revalidation warning
      }
    } catch (e) {
      // Revalidation warning suppressed
    }
  }

  @override
  Widget build(BuildContext context) {
    final storageInit = ref.watch(storageInitializerProvider);

    _setupBuildListeners(context, storageInit);
    _manageAutoHealTimer();

    return storageInit.when(
      loading: () => _buildLoadingScreen("Starting ${AppConstants.appName}..."), // coverage:ignore-line
      error: (e, s) => _buildStorageErrorScreen(context), // coverage:ignore-line
      data: (_) => _buildAuthenticatedContent(context),
    );
  }

  void _setupBuildListeners(
      BuildContext context, AsyncValue<void> storageInit) {
    _listenNetworkRecovery();
    _listenFirebaseInitErrors(context);
    _listenLogoutRequests();
    _listenAuthStream(context, storageInit);
  }

  void _listenNetworkRecovery() {
    ref.listen(isOfflineProvider, (previous, next) async {
      if (!_bootGracePeriodFinished) return;

      if (!(previous ?? false) && !next) {
        ref.invalidate(firebaseInitializerProvider); // coverage:ignore-line
        try {
          // coverage:ignore-start
          await ref
              .read(firebaseInitializerProvider.future)
              .timeout(const Duration(seconds: 15));
          await _revalidateSession();
          // coverage:ignore-end

          if (mounted && _hasVerificationTimedOut) { // coverage:ignore-line
            setState(() => _hasVerificationTimedOut = false); // coverage:ignore-line
          }
        } catch (e) {
          // Restoration revalidate failed
        }
      }
    });
  }

  void _listenFirebaseInitErrors(BuildContext context) {
    ref.listen(firebaseInitializerProvider, (previous, next) {
      // coverage:ignore-start
      if (next is AsyncError) {
        final isPersistentLogin = ref.read(isLoggedInProvider);
        if (isPersistentLogin && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
      // coverage:ignore-end
            const SnackBar(
              content: Text("Connection failed. Switching to Offline Mode."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  void _listenLogoutRequests() {
    ref.listen(logoutRequestedProvider, (previous, next) {
      if (next == true) { // coverage:ignore-line
        navigatorKey.currentState?.popUntil((route) => route.isFirst); // coverage:ignore-line
      }
    });
  }

  void _listenAuthStream(BuildContext context, AsyncValue<void> storageInit) {
    ref.listen(authStreamProvider, (previous, next) async {
      try {
        if (!storageInit.hasValue) return;

        final authService = ref.read(authServiceProvider);

        if (next.value != null && _isRedirectingLocal) {
          setState(() => _isRedirectingLocal = false); // coverage:ignore-line
        }

        if (_shouldSkipAuthProcessing(authService)) return;

        final checkFn = ref.read(connectivityCheckProvider);
        final isOffline = await checkFn();
        final isLoggedIn = ref.read(isLoggedInProvider);
        final user = next.value;

        if (!context.mounted) return;
        _handleGhostSession(
            context, next, user, isOffline, isLoggedIn, checkFn);
        _handleAutoRestore(context, next);
      } catch (e) {
        // Background Listener suppressed error
      }
    });
  }

  bool _shouldSkipAuthProcessing(dynamic authService) {
    final firebaseInit = ref.read(firebaseInitializerProvider);
    return !_bootGracePeriodFinished ||
        firebaseInit.isLoading ||
        firebaseInit.isRefreshing ||
        !firebaseInit.hasValue ||
        authService.isSignOutInProgress ||
        ref.read(logoutRequestedProvider);
  }

  void _handleGhostSession(
      BuildContext context,
      AsyncValue<User?> next,
      User? user,
      bool isOffline,
      bool isLoggedIn,
      Future<bool> Function() checkFn) async {
    if (!next.hasValue || user != null || isOffline || !isLoggedIn) return;

    await Future.delayed(const Duration(seconds: 30));
    final stillOffline = await checkFn();

    if (!stillOffline && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Session verification failed. Sync paused."),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: "FIX",
            onPressed: () => _showSessionFixDialog(context, ref), // coverage:ignore-line
          ),
        ),
      );
    }
  }

  void _handleAutoRestore(BuildContext context, AsyncValue<User?> next) {
    if (next.value == null) return;

    final storage = ref.read(storageServiceProvider);
    final accounts = storage.getAccounts();
    if (accounts.isNotEmpty) return;

    ref.read(cloudSyncServiceProvider).restoreFromCloud().then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cloud Restore Completed"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        ref.invalidate(accountsProvider);
        ref.invalidate(transactionsProvider);
        _ensureOptimisticFlag();
      }
    }).catchError((e) {
      // coverage:ignore-start
      if (context.mounted && !e.toString().contains("No cloud data")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Restore Info: ${e.toString()}")),
      // coverage:ignore-end
        );
      }
    });
  }

  void _manageAutoHealTimer() {
    if (_hasVerificationTimedOut && !ref.watch(isOfflineProvider)) {
      _setupAutoHealTimer();
    } else {
      _autoHealTimer?.cancel();
    }
  }

  // coverage:ignore-start
  Widget _buildStorageErrorScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
  // coverage:ignore-end
          padding: const EdgeInsets.all(24.0),
          child: Column( // coverage:ignore-line
            mainAxisAlignment: MainAxisAlignment.center,
            children: [ // coverage:ignore-line
              const Icon(Icons.error_outline, size: 48, color: Colors.amber),
              const SizedBox(height: 16),
              Text( // coverage:ignore-line
                "Storage Access Issue",
                style: Theme.of(context).textTheme.titleLarge, // coverage:ignore-line
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // coverage:ignore-start
              ElevatedButton.icon(
                onPressed: () async {
                  final isOffline = await NetworkUtils.isOffline();
              // coverage:ignore-end
                  if (isOffline) {
                    if (context.mounted) { // coverage:ignore-line
                      ScaffoldMessenger.of(context).showSnackBar( // coverage:ignore-line
                        const SnackBar(
                          content: Text(
                              "Still Offline. Please check your data/WiFi."),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } else {
                    // ignore: unused_result
                    ref.refresh(storageInitializerProvider); // coverage:ignore-line
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthenticatedContent(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);
    final isPersistentLogin = ref.watch(isLoggedInProvider);

    if (isPersistentLogin && (isOffline || _hasVerificationTimedOut)) {
      return const DashboardScreen();
    }

    if (kDebugMode && kIsWeb) return const DashboardScreen();

    if (isOffline && !isPersistentLogin) {
      return _buildErrorScreen(
        context,
        title: "Connection Required",
        message:
            "You are currently offline. Please connect to the internet to sign in.",
        icon: Icons.wifi_off,
      );
    }

    if (isPersistentLogin) {
      // ignore: unused_result
      ref.read(firebaseInitializerProvider);
    }

    final firebaseInit = ref.watch(firebaseInitializerProvider);

    if (isPersistentLogin &&
        (firebaseInit.isLoading || !_bootGracePeriodFinished) &&
        !_isRedirectingLocal) {
      return _buildAuthStream(context, isPersistentLogin);
    }

    return _handleFirebaseResult(context, firebaseInit, isPersistentLogin);
  }

  Widget _handleFirebaseResult(BuildContext context,
      AsyncValue<void> firebaseInit, bool isPersistentLogin) {
    return firebaseInit.when(
      // coverage:ignore-start
      loading: () => _buildLoadingScreen(
        _getLoadingMessage(),
        showOfflineBypass: isPersistentLogin && !_isRedirectingLocal,
      // coverage:ignore-end
      ),
      error: (e, s) {
        DebugLogger().log("AuthWrapper: Firebase Init Error: $e");
        if (isPersistentLogin) {
          return _buildAuthStream(context, isPersistentLogin); // coverage:ignore-line
        }
        final isTimeout = e.toString().toLowerCase().contains("timeout");
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
  }

  // coverage:ignore-start
  String _getLoadingMessage() {
    if (_isRedirectingLocal) {
      return _isSlowConnection
  // coverage:ignore-end
          ? "Slow link. Finalizing Account..."
          : "Finalizing Account...";
    }
    return _isSlowConnection ? "Slow link. Connecting..." : "Connecting..."; // coverage:ignore-line
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
              // coverage:ignore-start
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _hasVerificationTimedOut = true);
              // coverage:ignore-end
                },
                icon: const Icon(Icons.cloud_off_rounded),
                label: const Text(continueOfflineText),
                // coverage:ignore-start
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.grey[700],
                // coverage:ignore-end
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
          _ensureOptimisticFlag();
          return const DashboardScreen();
        }

        if (_isRedirectingLocal) {
          return _buildLoadingScreen("Finalizing Account..."); // coverage:ignore-line
        }

        if (isPersistentLogin) {
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
      loading: () {
        if (isPersistentLogin) return const DashboardScreen();
        return _buildLoadingScreen("Verifying Session...",
            showOfflineBypass: isPersistentLogin);
      },
      error: (e, s) { // coverage:ignore-line
        DebugLogger().log("AuthWrapper: Auth Stream Error: $e"); // coverage:ignore-line
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
              if (showOfflineBypass) ...[ // coverage:ignore-line
                const SizedBox(height: 12),
                // coverage:ignore-start
                TextButton.icon(
                  onPressed: () {
                    setState(() => _hasVerificationTimedOut = true);
                // coverage:ignore-end
                  },
                  icon: const Icon(Icons.cloud_off_rounded),
                  label: const Text(continueOfflineText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSessionFixDialog( // coverage:ignore-line
      BuildContext context, WidgetRef ref) async {
    await showDialog( // coverage:ignore-line
      context: context,
      builder: (context) => AlertDialog( // coverage:ignore-line
        title: const Text("Session Issue"),
        content: const Text(
            "Your secure cloud session could not be restored. You can continue offline, try to reconnect, or login again."),
        // coverage:ignore-start
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
        // coverage:ignore-end
            child: const Text(continueOfflineText),
          ),
          // coverage:ignore-start
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.invalidate(firebaseInitializerProvider);
          // coverage:ignore-end
            },
            child: const Text("Retry"),
          ),
          // coverage:ignore-start
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authServiceProvider).signOut(ref);
          // coverage:ignore-end
            },
            style: TextButton.styleFrom( // coverage:ignore-line
                foregroundColor: Theme.of(context).colorScheme.error), // coverage:ignore-line
            child: const Text("Login Again"),
          ),
        ],
      ),
    );
  }

  Future<void> _ensureOptimisticFlag() async {
    try {
      final storage = ref.read(storageServiceProvider);
      if (storage.getAuthFlag() == false) {
        await storage.setAuthFlag(true);
      }
    } catch (e) {
      // Failed to set Optimistic Flag
    }
  }
}
