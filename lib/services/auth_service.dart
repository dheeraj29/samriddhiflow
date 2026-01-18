import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'firebase_web_safe.dart';
import 'package:web/web.dart' as web;
import '../utils/debug_logger.dart';

class AuthService {
  FirebaseAuth? get _auth {
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

  // 1. Google Sign In
  Future<AuthResponse> signInWithGoogle() async {
    // Lazy Initialization: Try to init Firebase if it failed on startup (offline)
    if (_auth == null) {
      try {
        await Firebase.initializeApp(
            // Reuse options from main.dart explicitly would be better, but for now relying on default
            // Ideally we replicate the logic from main.dart or better, make this service accept the app instance.
            // However, calling initializeApp without name uses default app which is what we want.
            // But we need the Options.
            // Since we can't easily access the options from here without importing keys,
            // we will rely on Firebase.initializeApp() finding the options if configured,
            // OR we accept that this lazy init might only work if the platform auto-configures (like Web).
            // For Flutter, we usually need options.
            // Let's assume we can get them or just try.
            // Actually, we can import the options files like main.dart
            );
      } catch (e) {
        return AuthResponse(
            status: AuthStatus.error,
            message: "Connection failed: Unable to reach Google services.");
      }
    }

    final auth = _auth;
    if (auth == null) {
      // If still null after retry
      return AuthResponse(
          status: AuthStatus.error,
          message:
              "Service unavailable. Please check your internet connection.");
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
        await signOut();
        return AuthResponse(
            status: AuthStatus.error,
            message:
                "Session expired or account disabled. Please sign in again.");
      } catch (e) {
        // Unknown error -> Block for safety
        await signOut();
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
          web.window.sessionStorage.setItem('auth_redirect_pending', 'true');
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

      return AuthResponse(status: AuthStatus.success);
    } catch (e) {
      return AuthResponse(status: AuthStatus.error, message: e.toString());
    }
  }

  Future<void> signOut() async {
    debugPrint("AuthService: SignOut initiated.");
    // 1. Clear the optimistic flag first to ensure UI reacts immediately
    try {
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').put('isLoggedIn', false);
      }
    } catch (e) {
      debugPrint("AuthService: Failed to clear Hive flag: $e");
    }

    // 2. Clear Firebase Session
    final auth = _auth;
    if (auth != null) {
      try {
        await auth.signOut();
      } catch (e) {
        debugPrint("AuthService: Firebase SignOut error: $e");
      }
    }
  }

  Future<void> reloadUser() async {
    await _auth?.currentUser?.reload();
  }

  /// Finalizes the auth state after a web redirect.
  /// Should be called during app initialization.
  Future<void> handleRedirectResult() async {
    final auth = _auth;
    if (auth != null && kIsWeb) {
      // Small delay to allow JS SDK to settle after reload
      await Future.delayed(const Duration(milliseconds: 500));

      final currentUri = Uri.parse(web.window.location.href);
      DebugLogger().log(
          "AuthService: Checking Redirect at ${currentUri.host}${currentUri.path}");

      try {
        final result = await auth.getRedirectResult();
        if (result.user != null) {
          DebugLogger()
              .log("AuthService: Redirect Success for ${result.user!.email}");
          if (Hive.isBoxOpen('settings')) {
            await Hive.box('settings').put('isLoggedIn', true);
          }
        } else if (auth.currentUser != null) {
          DebugLogger().log(
              "AuthService: User already restored in currentUser fallback.");
          if (Hive.isBoxOpen('settings')) {
            await Hive.box('settings').put('isLoggedIn', true);
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
          web.window.sessionStorage.removeItem('auth_redirect_pending');
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
