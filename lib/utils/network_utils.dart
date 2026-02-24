import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'connectivity_platform.dart';
import 'debug_logger.dart';

class NetworkUtils {
  /// Safely checks connectivity with specific handling for Web/PWA logic.
  /// If [Connectivity] plugin fails (MissingPluginException), it falls back
  /// to standard browser [navigator.onLine] API.
  static Future<bool> isOffline() async {
    // 1. Try Standard Plugin
    try {
      // 0. Web Optimization: Trust navigator.onLine (Synchronous & Reliable)
      if (kIsWeb) {
        if (!ConnectivityPlatform.checkWebOnline()) { // coverage:ignore-line
          return true;
        }
      }

      final results = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));
      if (results.isNotEmpty) {
        final isOffline = !results.contains(ConnectivityResult.mobile) &&
            !results.contains(ConnectivityResult.wifi) &&
            !results.contains(ConnectivityResult.ethernet);

        if (isOffline) {
          return isOffline;
        }
      }
    } catch (e) {
      // 2. Fallback for Web/PWA
      if (kIsWeb) {
        final isMissingPlugin =
            e.toString().contains("MissingPluginException") || // coverage:ignore-line
                e.toString().contains("No implementation found"); // coverage:ignore-line

        if (isMissingPlugin) {
          try {
            // true if NOT onLine
            final webOffline = !ConnectivityPlatform.checkWebOnline(); // coverage:ignore-line
            return webOffline;
          } catch (webE) {
            DebugLogger().log("NetworkUtils: Web Fallback Failed: $webE"); // coverage:ignore-line
            // Fallback failed? Assume online.
            return false;
          }
        }
      }
      DebugLogger().log("NetworkUtils Exception: $e");
    }

    // Default: Assume Online if check fails (Fail Open)
    return false;
  }

  /// Extra check for actual internet reachability (beyond just interface status).
  /// This helps detect DNS resolution delays or captive portals on iOS.
  static Future<bool> hasActualInternet() async {
    if (kIsWeb) {
      return ConnectivityPlatform.checkActualWebReachability(); // coverage:ignore-line
    }
    // For non-web, standard connectivity is usually enough or we'd use a package.
    return true;
  }
}
