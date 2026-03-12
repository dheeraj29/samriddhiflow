import 'platform_native_utils.dart'
    if (dart.library.html) 'platform_web_utils.dart' as platform;

// coverage:ignore-start
bool isStandalone() => platform.isStandaloneMode();
bool isIOS() => platform.isIOS();
void reloadApp() => platform.reloadApp();
// coverage:ignore-end
