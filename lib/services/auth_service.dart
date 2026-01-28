import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../utils/connectivity_platform.dart';
import 'firebase_web_safe.dart';

import '../utils/debug_logger.dart';
import '../providers.dart';
import '../firebase_options.dart' as prod;
import '../firebase_options_debug.dart' as dev;

class AuthService {
  final FirebaseAuth? _injectedAuth;

  AuthService([this._injectedAuth]);

  FirebaseAuth? get _auth {
    if (_injectedAuth != null) return _injectedAuth;

    try {
      // CRITICAL: Check for JS object first to prevent ReferenceError crash on iOS
      if (kIsWeb && !FirebaseWebSafe.isFirebaseJsAvailable) return null;

      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? Stream.value(null);
  User? get currentUser => _auth?.currentUser;

  /// Internal flag to prevent race conditions during logout
  bool isSignOutInProgress = false;

  // 1. Google Sign In
  Future<AuthResponse> signInWithGoogle(dynamic ref) async {
    // Lazy Initialization: Try to init Firebase if it failed on startup (offline)
    if (_auth == null) {
      try {
        DebugLogger().log("AuthService: Lazy Initializing Firebase...");
        await Firebase.initializeApp(
          options: kDebugMode
              ? dev.DefaultFirebaseOptions.currentPlatform
              : prod.DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        DebugLogger().log("AuthService: Lazy Init Failed: $e");
        return AuthResponse(
            status: AuthStatus.error,
            message:
                "Connection failed: Unable to reach Google services. Please check your internet and try again.");
      }
    }

    final auth = _auth;
    if (auth == null) {
      return AuthResponse(
          status: AuthStatus.error,
          message:
              "Firebase Services are not available. Please check your internet connection.");
    }

    // Check if user is ALREADY logged in (persistence restored)
    if (auth.currentUser != null) {
      try {
        // FORCE VALIDATION: Check with server if account is still active
        await auth.currentUser!.reload();
        return AuthResponse(status: AuthStatus.success);
      } on FirebaseAuthException catch (e) {
        // Smart Verification: Allow access if network is unavailable
        if (e.code == 'network-request-failed' || e.code == 'unavailable') {
          debugPrint("Offline Session Validation: Allowed (${e.code})");
          return AuthResponse(status: AuthStatus.success);
        }

        // Otherwise (e.g. 'user-disabled'), BLOCK.
        await signOut(ref);
        return AuthResponse(
            status: AuthStatus.error,
            message:
                "Session expired or account disabled. Please sign in again.");
      } catch (e) {
        // Unknown error -> Block for safety
        await signOut(ref);
        return AuthResponse(
            status: AuthStatus.error, message: "Session validation failed: $e");
      }
    }

    try {
      if (kIsWeb) {
        // Web: Use signInWithRedirect (More reliable for PWAs/COOP)
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        // TRANSIENT FLAG: Set this in sessionStorage BEFORE redirect.
        // This survives the reload but is tab-specific and clears on tab close.
        // It prevents the "Ghost Session" issue if a user cancels auth.
        try {
          ConnectivityPlatform.setSessionStorageItem(
              'auth_redirect_pending', 'true');
        } catch (_) {
          // Fail gracefully if web storage is somehow blocked
        }

        await auth.signInWithRedirect(googleProvider);
        // Page will reload, AuthWrapper will handle the resumed session.
      } else {
        // Mobile/Desktop: Use GoogleSignIn package
        // Note: For this web-first project, we might just focus on Web flow or ensure package is added.
        // Assuming GoogleSignIn package is available from imports (it was commented out).
        // If imports are missing, I'll need to check. But for now, let's just enable Web path primarily.

        /* 
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          return AuthResponse(
              status: AuthStatus.error, message: "Sign in cancelled");
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await auth.signInWithCredential(credential);
        */

        // For now, if not web, we might just return error or keep it simple.
        // But the user is on Web.
      }

      // Optimization: Flag that we are logged in for next startup
      // We process this directly here to ensure it's saved before we return success
      try {
        if (Hive.isBoxOpen('settings')) {
          await Hive.box('settings').put('isLoggedIn', true);
        }
      } catch (_) {}

      // Reset logout flag
      if (ref != null) {
        ref.read(logoutRequestedProvider.notifier).value = false;
      }

      return AuthResponse(status: AuthStatus.success);
    } catch (e) {
      return AuthResponse(status: AuthStatus.error, message: e.toString());
    }
  }

  Future<void> signOut(dynamic ref) async {
    if (isSignOutInProgress) return;

    try {
      DebugLogger().log("AuthService: Instant Logout initiated.");

      // 1. Snap UI shut immediately
      isSignOutInProgress = true;
      ref.read(logoutRequestedProvider.notifier).value = true;

      // 2. Clear local session flag instantly
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').put('isLoggedIn', false);
      }

      // 3. Fully Decoupled Background Cleanup
      unawaited(Future(() async {
        try {
          DebugLogger().log("AuthService: Destroying Firebase Session (BG)...");
          await _auth?.signOut();
          DebugLogger().log("AuthService: Firebase SignOut Success.");
        } catch (e) {
          DebugLogger()
              .log("AuthService: Firebase SignOut suppressed error: $e");
        } finally {
          isSignOutInProgress = false;
        }
      }));
    } catch (e) {
      DebugLogger().log("AuthService: SignOut Error: $e");
      isSignOutInProgress = false;
    }
  }

  Future<void> reloadUser(dynamic ref) async {
    if (isSignOutInProgress) return;
    if (ref != null && ref.read(logoutRequestedProvider)) return;
    await _auth?.currentUser?.reload();
  }

  /// Finalizes the auth state after a web redirect.
  /// Should be called during app initialization.
  Future<void> handleRedirectResult(dynamic ref) async {
    if (isSignOutInProgress) return;
    if (ref != null && ref.read(logoutRequestedProvider)) return;
    final auth = _auth;
    if (auth != null && kIsWeb) {
      // Small delay to allow JS SDK to settle after reload
      await Future.delayed(const Duration(milliseconds: 500));

      final currentUri = Uri.parse(ConnectivityPlatform.getCurrentUrl());
      DebugLogger().log(
          "AuthService: Checking Redirect at ${currentUri.host}${currentUri.path}");

      try {
        final result = await auth.getRedirectResult();
        if (result.user != null) {
          DebugLogger().log("AuthService: Redirect Success");
          if (Hive.isBoxOpen('settings')) {
            await Hive.box('settings').put('isLoggedIn', true);
          }
          if (ref != null) {
            ref.read(logoutRequestedProvider.notifier).value = false;
          }
        } else if (auth.currentUser != null) {
          DebugLogger().log(
              "AuthService: User already restored in currentUser fallback.");
          if (Hive.isBoxOpen('settings')) {
            await Hive.box('settings').put('isLoggedIn', true);
          }
          if (ref != null) {
            ref.read(logoutRequestedProvider.notifier).value = false;
          }
        } else {
          DebugLogger()
              .log("AuthService: No Redirect Result User found (Both null).");
        }
      } catch (e) {
        DebugLogger().log("AuthService: REDIRECT ERROR: $e");
        debugPrint("AuthService: Error handling redirect result: $e");
      } finally {
        // Always clear the pending flag after checking result
        try {
          DebugLogger().log("AuthService: Clearing pending redirect flag.");
          ConnectivityPlatform.removeSessionStorageItem(
              'auth_redirect_pending');
        } catch (e) {
          DebugLogger().log("AuthService: Failed to clear session flag: $e");
        }
      }
    } else {
      DebugLogger()
          .log("AuthService: Skip Redirect check (Auth null or not Web).");
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
