import 'package:flutter_riverpod/flutter_riverpod.dart';

// Interface / Stub
class ConnectivityPlatform {
  static void setupWebListeners(Ref ref, void Function(bool) updateState) {
    // No-op for non-web platforms
  }

  static bool getInitialWebStatus() {
    return false; // Default for non-web
  }

  static bool checkWebOnline() {
    return true; // Assume online for non-web check
  }

  static Future<bool> checkActualWebReachability() async {
    return true;
  }

  static String? getSessionStorageItem(String key) => null;
  static void setSessionStorageItem(String key, String value) {}
  static void removeSessionStorageItem(String key) {}
  static String getCurrentUrl() => '';

  static Future<String> saveFileWeb(String fileName, List<int> bytes) async =>
      '';

  static void listenForInstallPrompt(Function(Object) onPrompt) {}
  static Future<void> triggerInstallPrompt(Object handle) async {}

  static Future<bool> checkForServiceWorkerUpdate() async => false;
  static Future<void> reloadAndClearCache() async {}
}
