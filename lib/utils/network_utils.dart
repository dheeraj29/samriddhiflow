import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'connectivity_platform.dart';
import 'debug_logger.dart';

class NetworkUtils {
  /// Internal mock flags for testing compiled web branches
  @visibleForTesting
  static bool forceWebForTest = false;

  /// Internal mock for tests
  static Future<bool> Function()? mockIsOffline;

  /// Safely checks connectivity with specific handling for Web/PWA logic.
  /// If [Connectivity] plugin fails (MissingPluginException), it falls back
  /// to standard browser [navigator.onLine] API.
  static Future<bool> isOffline() async {
    if (mockIsOffline != null) return mockIsOffline!();

    final isWebEnv = kIsWeb || forceWebForTest;

    // 1. Web Optimization: Trust navigator.onLine (Synchronous & Reliable)
    if (isWebEnv && !ConnectivityPlatform.checkWebOnline()) {
      return true;
    }

    // 2. Try Standard Plugin
    final pluginResult = await _checkConnectivityPlugin(isWebEnv);
    return pluginResult ?? false;
  }

  static Future<bool?> _checkConnectivityPlugin(bool isWebEnv) async {
    try {
      final results = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(milliseconds: 500));
      if (results.isEmpty) return null;

      final isOffline = !results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.ethernet);
      return isOffline ? true : null;
    } catch (e) {
      if (kIsWeb || forceWebForTest) return _handleWebFallback(e);
      DebugLogger().log("NetworkUtils Exception: $e");
      return null;
    }
  }

  static bool _handleWebFallback(Object e) {
    final isMissingPlugin = e.toString().contains("MissingPluginException") ||
        e.toString().contains("No implementation found");

    if (isMissingPlugin) {
      try {
        return !ConnectivityPlatform.checkWebOnline();
      } catch (webE) {
        DebugLogger().log(
            "NetworkUtils: Web Fallback Failed: $webE"); // coverage:ignore-line
        return false;
      }
    }
    DebugLogger().log("NetworkUtils Exception: $e");
    return false;
  }

  /// Extra check for actual internet reachability (beyond just interface status).
  /// This helps detect DNS resolution delays or captive portals on iOS.
  static Future<bool> hasActualInternet() async {
    if (kIsWeb || forceWebForTest) {
      return ConnectivityPlatform.checkActualWebReachability();
    }
    // For non-web, standard connectivity is usually enough or we'd use a package.
    return true;
  }
}
