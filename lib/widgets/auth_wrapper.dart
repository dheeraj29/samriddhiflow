import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/core/app_constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
    // 1. Initial Check
    _checkInitialConnectivity();

    // 2. Active Listener
    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          (List<ConnectivityResult> results) {
        if (_isOnline(results)) {
          DebugLogger()
              .log("AuthWrapper: Connection Restored. Retrying Init...");
          // ignore: unused_result
          ref.refresh(firebaseInitializerProvider);
          _revalidateSession();
        }
      }, onError: (e) {
        DebugLogger().log("AuthWrapper: Connectivity Stream Error: $e");
      });
    } catch (e) {
      DebugLogger().log("AuthWrapper: Connectivity Listener Crash: $e");
    }
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
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
      // ignore: unused_local_variable
      final init = await ref.read(firebaseInitializerProvider.future).timeout(
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

    // Only attempt reload if we think we have a user (from Firebase perspective)
    // If Firebase isn't initialized, this might return null or throw.
    // Safe check:
    try {
      final user = authService.currentUser;
      if (user != null) {
        debugPrint("Connectivity restored: Revalidating session...");
        await authService.reloadUser();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'user-disabled' ||
          e.code == 'min-app-version-error') {
        DebugLogger().log("Critical Session Error (${e.code}): Force Logout.");
        await authService.signOut();
      } else {
        DebugLogger().log("Revalidation warning (${e.code}) - Keeping Session");
      }
    } catch (e) {
      // Ignore other errors (network etc) during background revalidation
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
    // Only run if storage is ready.
    ref.listen(authStreamProvider, (previous, next) async {
      try {
        final user = next.value;

        // If a user arrives and we were waiting for a redirect, clear the wait
        if (user != null && _isRedirectingLocal) {
          setState(() => _isRedirectingLocal = false);
        }

        // Safety: Only proceed if storageInit is finished and boxes are open
        if (!ref.read(storageInitializerProvider).hasValue) return;

        // Skip ghost check if we are in the middle of a redirect or grace period
        if (!_bootGracePeriodFinished || _isRedirectingLocal) return;

        final isOffline = await NetworkUtils.isOffline();
        if (Hive.isBoxOpen('settings')) {
          final box = Hive.box('settings');
          final isPersistentLogin =
              box.get('isLoggedIn', defaultValue: false) as bool;

          if (next.hasValue &&
              user == null &&
              !isOffline &&
              isPersistentLogin) {
            DebugLogger()
                .log("AuthWrapper: Ghost Session detected. Cleaning up.");
            await ref.read(authServiceProvider).signOut();
          }
        }
      } catch (e) {
        DebugLogger()
            .log("AuthWrapper: Background Listener suppressed error: $e");
      }
    });

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
                  onPressed: () => ref.refresh(storageInitializerProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (_) {
        return ValueListenableBuilder(
          valueListenable:
              Hive.box('settings').listenable(keys: ['isLoggedIn']),
          builder: (context, box, _) {
            final isPersistentLogin =
                box.get('isLoggedIn', defaultValue: false) as bool;

            if (isPersistentLogin) {
              // ignore: unused_result
              ref.read(firebaseInitializerProvider);
              return const DashboardScreen();
            }

            final firebaseInit = ref.watch(firebaseInitializerProvider);

            return firebaseInit.when(
              loading: () {
                return _buildLoadingScreen(_isRedirectingLocal
                    ? "Finalizing Account..."
                    : "Connecting...");
              },
              error: (e, s) {
                DebugLogger().log("AuthWrapper: Firebase Init Error: $e");
                return const LoginScreen();
              },
              data: (_) {
                // Firebase Ready.
                // 3. SPECIAL REDIRECT WAIT:
                // If we are still in a redirect-pending session, we wait for the AuthStream
                // even if it currently says 'null', because it might be loading.
                return _buildAuthStream(context, isPersistentLogin);
              },
            );
          },
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
          _ensureOptimisticFlag();
          return const DashboardScreen();
        }

        if (_isRedirectingLocal) {
          return _buildLoadingScreen("Finalizing Account...");
        }

        return const LoginScreen();
      },
      loading: () => _buildLoadingScreen("Verifying Session..."),
      error: (e, s) {
        DebugLogger().log("AuthWrapper: Auth Stream Error: $e");
        return const LoginScreen();
      },
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
