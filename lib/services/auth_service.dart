import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../utils/connectivity_platform.dart';
import 'firebase_web_safe.dart';

import '../utils/debug_logger.dart';
import 'storage_service.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../firebase_options.dart' as prod;
import '../firebase_options_debug.dart' as dev;

class AuthService {
  final FirebaseAuth? _injectedAuth;
  final StorageService? _storageService;
  final bool isWeb;

  AuthService([this._injectedAuth, this._storageService, this.isWeb = kIsWeb]);

  FirebaseAuth? get _auth {
    if (_injectedAuth != null) return _injectedAuth;

    try {
      // CRITICAL: Check for JS object first to prevent ReferenceError crash on iOS
      if (isWeb && !FirebaseWebSafe.isFirebaseJsAvailable) return null;

      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance; // coverage:ignore-line
      }
    } catch (_) {}
    return null;
  }

  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? const Stream.empty();
  User? get currentUser => _auth?.currentUser;

  /// Internal flag to prevent race conditions during logout
  bool isSignOutInProgress = false;

  // 1. Google Sign In
  Future<AuthResponse> signInWithGoogle(dynamic ref) async {
    // Lazy Initialization: Try to init Firebase if it failed on startup (offline)
    if (_auth == null) {
      final initResult = await _lazyInitFirebase();
      if (initResult != null) return initResult;
    }

    final auth = _auth;
    if (auth == null) {
      return AuthResponse(
          // coverage:ignore-line
          status: AuthStatus.error,
          message:
              "Firebase Services are not available. Please check your internet connection.");
    }

    // Check if user is ALREADY logged in (persistence restored)
    if (auth.currentUser != null) {
      return _validateExistingSession(auth, ref);
    }

    return _performNewSignIn(auth, ref); // coverage:ignore-line
  }

  Future<AuthResponse?> _lazyInitFirebase() async {
    try {
      await Firebase.initializeApp(
        // coverage:ignore-line
        options: kDebugMode
            ? dev.DefaultFirebaseOptions.currentPlatform
            : prod
                .DefaultFirebaseOptions.currentPlatform, // coverage:ignore-line
      ).timeout(const Duration(seconds: 10)); // coverage:ignore-line
      return null; // Success, continue with sign in
    } catch (e) {
      DebugLogger().log("AuthService: Lazy Init Failed: $e");
      return AuthResponse(
          status: AuthStatus.error,
          message:
              "Connection failed: Unable to reach Google services. Please check your internet and try again.");
    }
  }

  Future<AuthResponse> _validateExistingSession(
      FirebaseAuth auth, dynamic ref) async {
    try {
      await auth.currentUser!.reload();
      return AuthResponse(status: AuthStatus.success);
    } on FirebaseAuthException catch (e) {
      // Use .contains() to handle cross-platform discrepancies (auth/ prefix on Web/PWA)
      if (e.code.contains('network-request-failed') ||
          e.code.contains('unavailable')) {
        return AuthResponse(status: AuthStatus.success);
      }
      await signOut(ref);
      return AuthResponse(
          status: AuthStatus.error,
          message:
              "Session expired or account disabled. Please sign in again.");
    } catch (e) {
      // coverage:ignore-start
      await signOut(ref);
      return AuthResponse(
          status: AuthStatus.error, message: "Session validation failed: $e");
      // coverage:ignore-end
    }
  }

  Future<AuthResponse> _performNewSignIn(FirebaseAuth auth, dynamic ref) async {
    // coverage:ignore-line
    try {
      // coverage:ignore-start
      if (isWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        // coverage:ignore-end
        try {
          ConnectivityPlatform.setSessionStorageItem(
              // coverage:ignore-line
              'auth_redirect_pending',
              'true');
        } catch (_) {}
        await auth.signInWithRedirect(googleProvider); // coverage:ignore-line
      }

      // Optimization: Flag that we are logged in for next startup
      try {
        await _setLoggedInFlag(true); // coverage:ignore-line
      } catch (_) {}

      // Reset logout flag
      if (ref != null) {
        ref.read(logoutRequestedProvider.notifier).value =
            false; // coverage:ignore-line
      }

      return AuthResponse(status: AuthStatus.success); // coverage:ignore-line
    } catch (e) {
      return AuthResponse(
          status: AuthStatus.error,
          message: e.toString()); // coverage:ignore-line
    }
  }

  Future<void> signOut(dynamic ref) async {
    if (isSignOutInProgress) return;

    try {
      final uid = _auth?.currentUser?.uid;

      // 1. Snap UI shut immediately
      isSignOutInProgress = true;
      if (ref != null) {
        ref.read(logoutRequestedProvider.notifier).value = true;
      }

      // 2. Clear local session flag instantly
      await _setLoggedInFlag(false);

      // 3. Fully Decoupled Background Cleanup
      unawaited(_performBackgroundSignOutCleanup(ref, uid));
    } catch (e) {
      DebugLogger()
          .log("AuthService: SignOut Error: $e"); // coverage:ignore-line
      isSignOutInProgress = false; // coverage:ignore-line
    }
  }

  /// Fully Decoupled Background Cleanup for SignOut
  Future<void> _performBackgroundSignOutCleanup(
      dynamic ref, String? uid) async {
    try {
      if (uid != null && _storageService != null) {
        await _clearSessionIfMatching(ref, uid);
      }
      await _auth?.signOut();
    } catch (e) {
      DebugLogger().log("AuthService: Firebase SignOut suppressed error: $e");
    } finally {
      isSignOutInProgress = false;
    }
  }

  /// Clears session Lock from Cloud if the local ID matches
  Future<void> _clearSessionIfMatching(dynamic ref, String uid) async {
    final storage = _storageService;
    if (storage == null) return;

    final localSessionId = storage.getSessionId();
    if (localSessionId == null) return;

    try {
      // coverage:ignore-start
      final cloudSync = ref.read(cloudSyncServiceProvider);
      final cloudSessionId = await cloudSync.getCloudSessionId(uid);
      if (cloudSessionId == localSessionId) {
        await cloudSync.clearActiveSessionId(uid);
        // coverage:ignore-end
      }
    } catch (_) {
      // Ignore cloud failures during logout
    } finally {
      // Always clear local session ID
      await storage.clearSessionId(); // coverage:ignore-line
    }
  }

  Future<void> reloadUser(dynamic ref) async {
    if (isSignOutInProgress) return;
    if (ref != null && ref.read(logoutRequestedProvider)) return;

    final user = _auth?.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } catch (e) {
        // Quiet failure for background reload - standard for JS SDK during recovery
        DebugLogger().log("AuthService: Reload failed (likely offline): $e");
      }
    }
  }

  /// Finalizes the auth state after a web redirect.
  /// Should be called during app initialization.
  Future<User?> handleRedirectResult() async {
    if (isSignOutInProgress) return null;

    final auth = _auth;
    if (auth != null && isWeb) {
      // Small delay to allow JS SDK to settle after reload
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        final result = await auth.getRedirectResult();
        if (result.user != null) {
          await _setLoggedInFlag(true);
          return result.user;
        } else if (auth.currentUser != null) {
          await _setLoggedInFlag(true);
          return auth.currentUser;
        } else {
          // No Redirect Result User found
        }
      } catch (e) {
        DebugLogger().log("AuthService: REDIRECT ERROR: $e");
      } finally {
        // Always clear the pending flag after checking result
        try {
          ConnectivityPlatform.removeSessionStorageItem(
              'auth_redirect_pending');
        } catch (e) {
          // Failed to clear session flag
        }
      }
    } else {
      // Skip Redirect check
    }
    return null;
  }

  Future<void> _setLoggedInFlag(bool value) async {
    if (_storageService != null) {
      await _storageService.setAuthFlag(value);
    } else if (Hive.isBoxOpen('settings')) {
      // coverage:ignore-line
      await Hive.box('settings')
          .put('isLoggedIn', value); // coverage:ignore-line
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth?.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}

enum AuthStatus { success, error }

class AuthResponse {
  final AuthStatus status;
  final String? message;

  AuthResponse({required this.status, this.message});
}
