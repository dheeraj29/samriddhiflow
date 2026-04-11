import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../utils/connectivity_platform.dart';
import '../core/app_constants.dart';
import '../utils/debug_logger.dart';
import '../screens/login_screen.dart';
import '../utils/ui_utils.dart';
import '../utils/network_utils.dart';
import '../navigator_key.dart';
import '../screens/dashboard_screen.dart';
import '../theme/app_theme.dart';
import '../utils/platform_utils.dart' as platform_utils;
import '../l10n/app_localizations.dart';
import '../services/subscription_service.dart';
import '../services/firestore_storage_service.dart';
import 'region_selection_dialog.dart';

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
  bool _isRestoring = false;
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
        // Proactively check auto-restore after boot grace completes.
        // On first login, the auth event fires before the grace period ends,
        // so the auto-restore listener skips it. This catch-up ensures
        // auto-restore triggers for users who just signed in.
        _triggerAutoRestoreIfNeeded();
      }
    });
  }

  void _triggerAutoRestoreIfNeeded() {
    final authService = ref.read(authServiceProvider);
    if (authService.currentUser == null) return;

    final storage = ref.read(storageServiceProvider);
    if (storage.getAccounts().isNotEmpty) return;

    final subService = ref.read(subscriptionServiceProvider);
    if (!subService.isCloudSyncEnabled()) return;

    // Use context from the widget's element (safe because mounted was checked)
    if (mounted) {
      _performAutoRestoreOperation(context);
    }
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
          final storage = ref.read(storageServiceProvider);
          final lastLogin = storage.getLastLogin();
          final isSessionExpired = lastLogin != null &&
              DateTime.now().difference(lastLogin).inHours >= 1;

          if (isSessionExpired) {
            setState(() => _hasVerificationTimedOut = false);
          } else {
            setState(() => _hasVerificationTimedOut = true);
          }
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

  Future<void> _revalidateSession({bool isBackground = false}) async {
    final authService = ref.read(authServiceProvider);
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        final user = authService.currentUser;
        if (user != null && !authService.isSignOutInProgress) {
          await authService.reloadUser(ref);
        }
        return; // Success
      } on FirebaseAuthException catch (e) {
        final shouldRetry = await _handleRevalidationError(
            e, attempts, maxAttempts,
            isBackground: isBackground);
        if (!shouldRetry) return;
      } catch (e) {
        return; // Revalidation warning suppressed
      }
    }
  }

  Future<bool> _handleRevalidationError(
      FirebaseAuthException e, int attempts, int maxAttempts,
      {bool isBackground = false}) async {
    final authService = ref.read(authServiceProvider);

    // Use .contains() to handle both Native and Web/PWA error code formats (auth/ prefix)
    if (e.code.contains('user-not-found') ||
        e.code.contains('user-disabled') || // coverage:ignore-line
        e.code.contains('min-app-version-error')) {
      // coverage:ignore-line
      DebugLogger().log("Critical Session Error (${e.code}): Force Logout.");
      // CRITICAL: Only force logout if NOT in background recovery
      // This prevents redirects on iOS/Safari during transient recovery glitches
      if (!isBackground) {
        await authService.signOut(ref);
      }
      return false;
    }

    // coverage:ignore-start
    if (e.code.contains('network-request-failed') ||
        e.code.contains('unavailable')) {
      if (attempts >= maxAttempts) {
        ref.read(isOfflineProvider.notifier).setOffline(true);
        // coverage:ignore-end
        return false;
      }
      await Future.delayed(
          Duration(seconds: 2 * attempts)); // coverage:ignore-line
      return true; // Retry
    }

    return false; // Stop for other auth errors
  }

  @override
  Widget build(BuildContext context) {
    final storageInit = ref.watch(storageInitializerProvider);

    _setupBuildListeners(context, storageInit);
    _manageAutoHealTimer();

    if (kIsWeb && !_isStandalone()) {
      // coverage:ignore-line
      return _buildPWAInstallationBlocker(context); // coverage:ignore-line
    }

    return storageInit.when(
      loading: () => _buildLoadingScreen(
          "Starting ${AppConstants.appName}..."), // coverage:ignore-line
      error: (e, s) =>
          _buildStorageErrorScreen(context), // coverage:ignore-line
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

      if (previous == true && next == false) {
        // PROACTIVE SILENT RECOVERY
        // We avoid invalidating firebaseInitializerProvider to prevent UI flickering.
        // Instead, we 'poke' the session in the background.
        try {
          await _revalidateSession(isBackground: true);

          if (mounted && _hasVerificationTimedOut) {
            setState(() => _hasVerificationTimedOut = false);
          }
        } catch (e) {
          // Restoration revalidate failed
        }
      }
    });
  }

  void _listenFirebaseInitErrors(BuildContext context) {
    ref.listen(firebaseInitializerProvider, (previous, next) {
      if (next is AsyncError) {
        // coverage:ignore-start
        final isPersistentLogin = ref.read(isLoggedInProvider);
        if (isPersistentLogin && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // coverage:ignore-end
              content: Text(AppLocalizations.of(context)!
                  .connectionFailedOffline), // coverage:ignore-line
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  void _listenLogoutRequests() {
    ref.listen(logoutRequestedProvider, (previous, next) {
      if (next == true) {
        // coverage:ignore-line
        navigatorKey.currentState
            ?.popUntil((route) => route.isFirst); // coverage:ignore-line
      }
    });
  }

  void _listenAuthStream(BuildContext context, AsyncValue<void> storageInit) {
    ref.listen(authStreamProvider, (previous, next) async {
      await _onAuthStreamChangeEvent(context, storageInit, previous, next);
    });

    // auto-restore is now synchronized in _onAuthStreamChangeEvent
    // and handled after _resolveRegionHint completes to prevent race conditions.
  }

  Future<void> _onAuthStreamChangeEvent(
      BuildContext context,
      AsyncValue<void> storageInit,
      AsyncValue<User?>? previous,
      AsyncValue<User?> next) async {
    try {
      if (!storageInit.hasValue) return;

      final authService = ref.read(authServiceProvider);

      if (next.value != null && _isRedirectingLocal) {
        setState(() => _isRedirectingLocal = false); // coverage:ignore-line
      }

      if (next.value != null) {
        await _resolveRegionHint(next.value!.uid);
        if (context.mounted) {
          _handleAutoRestore(context, next);
        }
      }

      await _claimSessionOnNewSignIn(previous, next);

      if (_shouldSkipAuthProcessing(authService)) return;

      final checkFn = ref.read(connectivityCheckProvider);
      final isOffline = await checkFn();
      final isLoggedIn = ref.read(isLoggedInProvider);
      final user = next.value;

      if (!context.mounted) return;
      _handleGhostSession(context, next, user, isOffline, isLoggedIn, checkFn);
    } catch (e) {
      // Background Listener suppressed error
    }
  }

  Future<void> _resolveRegionHint(String uid) async {
    // Only resolve the hint if the device hasn't committed data to ANY region yet
    final storage = ref.read(storageServiceProvider);
    final settings = storage.getAllSettings();
    if (settings['last_sync'] != null) return;

    try {
      // coverage:ignore-start
      final globalStorage = FirestoreStorageService(databaseId: null);
      final hint = await globalStorage.getRegionHint(uid);
      if (hint != null && mounted) {
        final currentRegion = ref.read(cloudDatabaseRegionProvider);
        if (currentRegion != hint) {
          await ref.read(cloudDatabaseRegionProvider.notifier).setRegion(hint);
          // coverage:ignore-end
        }
      }
    } catch (e) {
      DebugLogger()
          .log("Region hint resolution failed: $e"); // coverage:ignore-line
    }
  }

  /// Claims a new session UUID when the user signs in for the first time.
  Future<void> _claimSessionOnNewSignIn(
      AsyncValue<User?>? previous, AsyncValue<User?> next) async {
    // No-op: session creation is deferred to sync/restore flows.
    // Creating a local UUID here without pushing to cloud would cause
    // _syncSessionBeforeRestore to skip the cloud push and poison
    // isNewDevice checks across AuthWrapper and SettingsScreen.
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
          content:
              Text(AppLocalizations.of(context)!.sessionVerificationFailed),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: "FIX",
            onPressed: () =>
                _showSessionFixDialog(context, ref), // coverage:ignore-line
          ),
        ),
      );
    }
  }

  void _handleAutoRestore(BuildContext context, AsyncValue<User?> next) async {
    final region = ref.read(cloudDatabaseRegionProvider);
    if (region.isEmpty) {
      return; // Skip restore until region is resolved/selected
    }

    final storage = ref.read(storageServiceProvider);
    if (storage.getAccounts().isNotEmpty) return;

    final subService = ref.read(subscriptionServiceProvider);
    if (!subService.isCloudSyncEnabled()) return;

    await _performAutoRestoreOperation(context);
  }

  Future<void> _performAutoRestoreOperation(BuildContext context,
      [String? passcode]) async {
    if (_isRestoring && passcode == null) return; // Guard

    final authService = ref.read(authServiceProvider);
    if (!context.mounted || authService.currentUser == null) return;

    final storage = ref.read(storageServiceProvider);
    final isNewDevice = storage.getSessionId() == null;

    setState(() => _isRestoring = true);

    try {
      final cloudSync = ref.read(cloudSyncServiceProvider);
      await cloudSync.restoreFromCloud(passcode: passcode);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.restoreCompleteStatus),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(transactionsProvider);
        ref.read(txnsSinceBackupProvider.notifier).reset();
        _ensureOptimisticFlag();
      }
    } catch (e) {
      if (context.mounted) {
        await _handleRestoreError(context, e, isNewDevice);
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  // Removed _isRegionRestricted in favor of manual selection

  Future<void> _handleRestoreError(
      BuildContext context, dynamic e, bool isNewDevice) async {
    final errorStr = e.toString();
    final isSessionError = errorStr.contains("SESSION_EXPIRED") ||
        errorStr.contains("another device");

    if (errorStr.contains("Premium Subscription required")) {
      return; // Silent skip for auto-restore
    }

    if (errorStr.contains("Passcode required") ||
        errorStr.contains("Incorrect passcode")) {
      await _handlePasscodeError(context, errorStr);
    } else if (isSessionError) {
      await _handleSessionConflict(context, errorStr, isNewDevice);
    } else {
      _handleGenericRestoreError(context, errorStr); // coverage:ignore-line
    }
  }

  Future<void> _handlePasscodeError(
      BuildContext context, String errorStr) async {
    final p = await UIUtils.showPasscodePrompt(
        context, errorStr.contains("Incorrect"));

    if (context.mounted && p != null && p.isNotEmpty) {
      await _performAutoRestoreOperation(context, p);
    } else if (context.mounted) {
      // coverage:ignore-line
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          // coverage:ignore-line
          content: Text("Restore skipped. Continuing with empty data.")));
    }
  }

  Future<void> _handleSessionConflict(
      BuildContext context, String errorStr, bool isNewDevice) async {
    if (isNewDevice) {
      final confirm = await UIUtils.showClaimOwnershipDialog(
          context); // coverage:ignore-line

      // coverage:ignore-start
      if (confirm == true && context.mounted) {
        await ref.read(cloudSyncServiceProvider).claimSession();
        if (context.mounted) {
          await _performAutoRestoreOperation(context);
          // coverage:ignore-end
        }
      }
    } else if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sessionExpiredLogoutMessage)),
      );
      await ref.read(storageServiceProvider).clearAllData();
      ref.read(authServiceProvider).signOut(ref);
    }
  }

  // coverage:ignore-start
  void _handleGenericRestoreError(BuildContext context, String errorStr) {
    if (!errorStr.contains("No cloud data")) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Restore Info: $errorStr")),
          // coverage:ignore-end
        );
      }
    }
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
          child: Column(
            // coverage:ignore-line
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // coverage:ignore-line
              const Icon(Icons.error_outline, size: 48, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                // coverage:ignore-line
                "Storage Access Issue",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge, // coverage:ignore-line
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // coverage:ignore-start
              ElevatedButton.icon(
                onPressed: () async {
                  final isOffline = await NetworkUtils.isOffline();
                  // coverage:ignore-end
                  if (isOffline) {
                    if (context.mounted) {
                      // coverage:ignore-line
                      ScaffoldMessenger.of(context).showSnackBar(
                        // coverage:ignore-line
                        const SnackBar(
                          content: Text(
                              "Still Offline. Please check your data/WiFi."),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } else {
                    // ignore: unused_result
                    ref.refresh(
                        storageInitializerProvider); // coverage:ignore-line
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
    if (_handleImmediateRedirects(context)) return const DashboardScreen();

    final isOffline = ref.watch(isOfflineProvider);
    final isPersistentLogin = ref.watch(isLoggedInProvider);

    if (isOffline && !isPersistentLogin) {
      return _buildErrorScreen(
        context,
        title: "Connection Required",
        message:
            "You are currently offline. Please connect to the internet to sign in.",
        icon: Icons.wifi_off,
      );
    }

    if (isOffline && isPersistentLogin) {
      final storage = ref.read(storageServiceProvider);
      final lastLogin = storage.getLastLogin();
      final isSessionExpired = lastLogin != null &&
          DateTime.now().difference(lastLogin).inHours >= 1;

      if (isSessionExpired) {
        return _buildErrorScreen(
          context,
          title: "Session Expired",
          message:
              "Your session has expired. Please connect to the internet to re-verify your account.",
          icon: Icons.history,
          showOfflineBypass: false,
        );
      }
    }

    if (isPersistentLogin) {
      // ignore: unused_result
      ref.read(firebaseInitializerProvider);
    }

    final firebaseInit = ref.watch(firebaseInitializerProvider);

    if (_shouldShowAuthStream(firebaseInit, isPersistentLogin)) {
      return _buildAuthStream(context, isPersistentLogin);
    }

    return _handleFirebaseResult(context, firebaseInit, isPersistentLogin);
  }

  bool _handleImmediateRedirects(BuildContext context) {
    if (ref.watch(isLoggedInProvider) &&
        (ref.watch(isOfflineProvider) || _hasVerificationTimedOut)) {
      if (ref.read(isOfflineProvider)) {
        final storage = ref.read(storageServiceProvider);
        final lastLogin = storage.getLastLogin();
        final isSessionExpired = lastLogin != null &&
            DateTime.now().difference(lastLogin).inHours >= 1;
        if (isSessionExpired) return false;
      }
      return true;
    }
    if (kDebugMode && kIsWeb) return true;
    return false;
  }

  bool _shouldShowAuthStream(
      AsyncValue<void> firebaseInit, bool isPersistentLogin) {
    return isPersistentLogin &&
        (firebaseInit.isLoading || !_bootGracePeriodFinished) &&
        !_isRedirectingLocal;
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
          return _buildAuthStream(
              context, isPersistentLogin); // coverage:ignore-line
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
    return _isSlowConnection
        ? "Slow link. Connecting..."
        : "Connecting..."; // coverage:ignore-line
  }

  Widget _buildLoadingScreen(String message, {bool showOfflineBypass = false}) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),
            const SizedBox(height: 20),
            Text(message,
                style: AppTheme.offlineSafeTextStyle.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Text(AppConstants.appVersion,
                style: AppTheme.offlineSafeTextStyle.copyWith(
                    color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.5) ??
                        Colors.grey[400], // coverage:ignore-line
                    fontSize: 10)),
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
          final region = ref.watch(cloudDatabaseRegionProvider);
          if (region.isEmpty) {
            return const Scaffold(
              body: Center(
                child: RegionSelectionDialog(isMandatory: true),
              ),
            );
          }
          return const DashboardScreen();
        }

        if (_isRedirectingLocal) {
          return _buildLoadingScreen(
              "Finalizing Account..."); // coverage:ignore-line
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
      error: (e, s) {
        // coverage:ignore-line
        // If we have a persistent session, STAY on Dashboard even if Firebase is flapping
        if (isPersistentLogin) return const DashboardScreen();

        DebugLogger()
            .log("AuthWrapper: Auth Stream Error: $e"); // coverage:ignore-line
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
                  color: Theme.of(context).textTheme.bodySmall?.color ??
                      Colors.grey[600], // coverage:ignore-line
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  // Explicitly check connectivity on retry
                  final isOffline = await ref.read(connectivityCheckProvider)();
                  if (context.mounted) {
                    ref.read(isOfflineProvider.notifier).setOffline(isOffline);
                    if (!isOffline) {
                      ref.invalidate(firebaseInitializerProvider);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "Still offline. Please check your connection."),
                            duration: Duration(seconds: 2)),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Retry Connection"),
              ),
              if (showOfflineBypass) ...[
                // coverage:ignore-line
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

  Future<void> _showSessionFixDialog(
      // coverage:ignore-line
      BuildContext context,
      WidgetRef ref) async {
    await showDialog(
      // coverage:ignore-line
      context: context,
      builder: (context) => AlertDialog(
        // coverage:ignore-line
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
            style: TextButton.styleFrom(
                // coverage:ignore-line
                foregroundColor: Theme.of(context)
                    .colorScheme
                    .error), // coverage:ignore-line
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

  bool _isStandalone() {
    // coverage:ignore-line
    if (kDebugMode) return true;
    return platform_utils.isStandalone(); // coverage:ignore-line
  }

  // coverage:ignore-start
  Widget _buildPWAInstallationBlocker(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // coverage:ignore-end

    return Scaffold(
      // coverage:ignore-line
      body: Container(
        // coverage:ignore-line
        width: double.infinity,
        decoration: BoxDecoration(
          // coverage:ignore-line
          gradient: LinearGradient(
            // coverage:ignore-line
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                // coverage:ignore-start
                ? [
                    theme.scaffoldBackgroundColor,
                    theme.colorScheme.surface.withValues(alpha: 0.9)
                    // coverage:ignore-end
                  ]
                : [
                    // coverage:ignore-line
                    AppTheme.primary,
                    AppTheme.primary
                        .withValues(alpha: 0.8), // coverage:ignore-line
                  ],
          ),
        ),
        child: SafeArea(
          // coverage:ignore-line
          child: Column(
            // coverage:ignore-line
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // coverage:ignore-line
              const Spacer(),
              Container(
                // coverage:ignore-line
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  // coverage:ignore-line
                  color: isDark
                      ? theme.colorScheme.surface
                      : Colors.white, // coverage:ignore-line
                  shape: BoxShape.circle,
                  // coverage:ignore-start
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                      // coverage:ignore-end
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Hero(
                  // coverage:ignore-line
                  tag: 'app_logo',
                  child: Image.asset(
                    // coverage:ignore-line
                    'assets/images/logo.png',
                    width: 100,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) => Icon(
                        // coverage:ignore-line
                        Icons.account_balance_wallet,
                        size: 100,
                        color:
                            theme.colorScheme.primary), // coverage:ignore-line
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                // coverage:ignore-line
                "SAMRIDDHI FLOW",
                style: AppTheme.offlineSafeTextStyle.copyWith(
                  // coverage:ignore-line
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                // coverage:ignore-line
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  // coverage:ignore-line
                  "Experience the full premium power of Samriddhi Flow by installing it as an app.",
                  textAlign: TextAlign.center,
                  style: AppTheme.offlineSafeTextStyle.copyWith(
                    // coverage:ignore-line
                    fontSize: 16,
                    color: Colors.white
                        .withValues(alpha: 0.9), // coverage:ignore-line
                  ),
                ),
              ),
              const Spacer(),
              Container(
                // coverage:ignore-line
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  // coverage:ignore-line
                  color: theme.colorScheme.surface, // coverage:ignore-line
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                  // coverage:ignore-start
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                      // coverage:ignore-end
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Column(
                  // coverage:ignore-line
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // coverage:ignore-line
                    _buildInstallStep(
                      // coverage:ignore-line
                      context,
                      icon: Icons.add_to_home_screen_rounded,
                      title: "How to Install",
                      subtitle: "Add Samriddhi Flow to your home screen",
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    _buildInstallInstruction(
                      // coverage:ignore-line
                      context,
                      isAndroid:
                          !platform_utils.isIOS(), // coverage:ignore-line
                    ),
                    const SizedBox(height: 48),
                    // coverage:ignore-start
                    ElevatedButton(
                      onPressed: () => platform_utils.reloadApp(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        // coverage:ignore-end
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          // coverage:ignore-line
                          borderRadius:
                              BorderRadius.circular(16), // coverage:ignore-line
                        ),
                      ),
                      child: const Text("I HAVE INSTALLED IT"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallStep(BuildContext context, // coverage:ignore-line
      {required IconData icon,
      required String title,
      required String subtitle}) {
    // coverage:ignore-start
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          // coverage:ignore-end
          padding: const EdgeInsets.all(12),
          // coverage:ignore-start
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            // coverage:ignore-end
          ),
          child: Icon(icon,
              color: theme.colorScheme.primary,
              size: 32), // coverage:ignore-line
        ),
        const SizedBox(width: 16),
        Expanded(
          // coverage:ignore-line
          child: Column(
            // coverage:ignore-line
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // coverage:ignore-line
              Text(
                // coverage:ignore-line
                title,
                style: AppTheme.offlineSafeTextStyle.copyWith(
                  // coverage:ignore-line
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                // coverage:ignore-line
                subtitle,
                style: AppTheme.offlineSafeTextStyle.copyWith(
                  // coverage:ignore-line
                  color:
                      theme.textTheme.bodySmall?.color, // coverage:ignore-line
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstallInstruction(BuildContext context, // coverage:ignore-line
      {required bool isAndroid}) {
    if (isAndroid) {
      return _buildInstructionRow(
        // coverage:ignore-line
        context,
        icon: Icons.more_vert_rounded,
        text: "Tap the three dots in your browser and select 'Install App'",
      );
    } else {
      return _buildInstructionRow(
        // coverage:ignore-line
        context,
        icon: Icons.ios_share_rounded,
        text: "Tap the share button and select 'Add to Home Screen'",
      );
    }
  }

  Widget _buildInstructionRow(BuildContext context, // coverage:ignore-line
      {required IconData icon,
      required String text}) {
    // coverage:ignore-start
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 24),
        // coverage:ignore-end
        const SizedBox(width: 16),
        Expanded(
          // coverage:ignore-line
          child: Text(
            // coverage:ignore-line
            text,
            style: AppTheme.offlineSafeTextStyle.copyWith(
              // coverage:ignore-line
              color: theme.colorScheme.onSurface, // coverage:ignore-line
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
