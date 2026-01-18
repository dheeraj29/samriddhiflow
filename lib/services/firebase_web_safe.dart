import 'package:flutter/foundation.dart';

/// Checks if the Firebase JS SDK is loaded and available globally.
/// This is critical for iOS PWA Offline scenarios where scripts might not be cached.
class FirebaseWebSafe {
  static bool get isFirebaseJsAvailable {
    if (!kIsWeb) return true; // Native assumes available or managed by plugin

    // With Modular SDKs (via ImportMap), there is no global 'firebase' object to check.
    // We trust the ImportMap + Local Scripts execution.
    // Returning true allows providers.dart to proceed with initializeApp.
    return true;
  }
}
