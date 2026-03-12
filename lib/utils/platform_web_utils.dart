// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

bool isStandaloneMode() {
  try {
    return html.window.matchMedia('(display-mode: standalone)').matches ||
        (html.window.navigator as dynamic).standalone == true;
  } catch (_) {
    return false;
  }
}

bool isIOS() {
  try {
    final navigator = html.window.navigator;
    final userAgent = navigator.userAgent.toLowerCase();
    final platform = navigator.platform?.toLowerCase() ?? '';

    // Use regex to consolidate device checks
    final deviceRegex = RegExp(r'iphone|ipad|ipod');
    if (deviceRegex.hasMatch(userAgent) || deviceRegex.hasMatch(platform)) {
      return true;
    }

    // Handle iPadOS 13+ which reports as Macintosh but has touch points
    if (platform.contains('mac') && (navigator.maxTouchPoints ?? 0) > 0) {
      return true;
    }

    return false;
  } catch (_) {
    return false;
  }
}

void reloadApp() {
  try {
    html.window.location.reload();
  } catch (_) {}
}
