import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
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
        if (!web.window.navigator.onLine) {
          DebugLogger()
              .log("NetworkUtils: navigator.onLine is FALSE (Offline)");
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
          DebugLogger()
              .log("NetworkUtils: Connectivity Plugin reported OFFLINE");
        }
        return isOffline;
      }
    } catch (e) {
      // 2. Fallback for Web/PWA
      if (kIsWeb) {
        final isMissingPlugin =
            e.toString().contains("MissingPluginException") ||
                e.toString().contains("No implementation found");

        if (isMissingPlugin) {
          DebugLogger().log(
              "NetworkUtils: Connectivity plugin missing. Using Web Fallback.");
          try {
            // true if NOT onLine
            final webOffline = !web.window.navigator.onLine;
            DebugLogger().log(
                "NetworkUtils: Web Navigator reports ${webOffline ? 'OFFLINE' : 'ONLINE'}");
            return webOffline;
          } catch (webE) {
            DebugLogger().log("NetworkUtils: Web Fallback Failed: $webE");
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
}
