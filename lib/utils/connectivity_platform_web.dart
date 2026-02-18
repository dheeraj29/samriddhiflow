import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:typed_data';

class ConnectivityPlatform {
  static void setupWebListeners(Ref ref, void Function(bool) updateState) {
    final onlineHandler = (web.Event _) {
      updateState(false); // isOffline = false
    }.toJS;
    final offlineHandler = (web.Event _) {
      updateState(true); // isOffline = true
    }.toJS;

    web.window.addEventListener('online', onlineHandler);
    web.window.addEventListener('offline', offlineHandler);

    ref.onDispose(() {
      web.window.removeEventListener('online', onlineHandler);
      web.window.removeEventListener('offline', offlineHandler);
    });
  }

  static bool getInitialWebStatus() {
    return !web.window.navigator.onLine;
  }

  static bool checkWebOnline() {
    return web.window.navigator.onLine;
  }

  static Future<bool> checkActualWebReachability() async {
    if (!web.window.navigator.onLine) return false;
    try {
      final response = await web.window
          .fetch(
              'https://www.google.com/generate_204?pb=${DateTime.now().millisecondsSinceEpoch}'
                  .toJS,
              web.RequestInit(method: 'HEAD', mode: 'no-cors'))
          .toDart;
      return response.type != 'error';
    } catch (e) {
      return false;
    }
  }

  static String? getSessionStorageItem(String key) {
    return web.window.sessionStorage.getItem(key);
  }

  static void setSessionStorageItem(String key, String value) {
    web.window.sessionStorage.setItem(key, value);
  }

  static void removeSessionStorageItem(String key) {
    web.window.sessionStorage.removeItem(key);
  }

  static String getCurrentUrl() {
    return web.window.location.href;
  }

  static Future<String> saveFileWeb(String fileName, List<int> bytes) async {
    final uint8List = Uint8List.fromList(bytes);
    final blob = web.Blob([uint8List.toJS].toJS,
        web.BlobPropertyBag(type: "application/octet-stream"));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
    return "Download triggered in browser";
  }

  static void listenForInstallPrompt(Function(Object) onPrompt) {
    web.window.addEventListener(
        'beforeinstallprompt',
        (web.Event event) {
          event.preventDefault();
          onPrompt(event);
        }.toJS);
  }

  static Future<void> triggerInstallPrompt(Object handle) async {
    final event = handle as BeforeInstallPromptEvent;
    await event.prompt().toDart;
  }

  static Future<bool> checkForServiceWorkerUpdate() async {
    try {
      final registration =
          await web.window.navigator.serviceWorker.ready.toDart;
      await registration.update().toDart;
      await Future.delayed(const Duration(seconds: 1));
      return registration.waiting != null || registration.installing != null;
    } catch (e) {
      return false;
    }
  }

  static Future<void> reloadAndClearCache() async {
    try {
      // 1. Unregister Service Workers
      final registrations =
          await web.window.navigator.serviceWorker.getRegistrations().toDart;
      final swList = registrations.toDart;
      for (final registration in swList) {
        await registration.unregister().toDart;
      }

      // 2. Clear Caches
      final caches = web.window.caches;
      final keysArray = await caches.keys().toDart;
      final keys = keysArray.toDart;
      for (final key in keys) {
        await caches.delete(key.toDart).toDart;
      }
    } catch (_) {
      // Ignore errors, proceed to reload
    } finally {
      web.window.location.reload();
    }
  }
}

// Private extension for the event within this file
extension type BeforeInstallPromptEvent(JSObject o) implements web.Event {
  external JSPromise<JSAny?> prompt();
  external JSPromise<JSObject> get userChoice;
}
