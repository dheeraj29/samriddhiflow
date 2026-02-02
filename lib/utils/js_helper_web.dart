import 'dart:js_interop';
import 'package:web/web.dart' as web;

void setupBrowserBlurListener(void Function() onBlur) {
  web.window.addEventListener(
    'blur',
    ((web.Event event) => onBlur()).toJS as web.EventListener,
  );
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event event) {
      if (web.document.visibilityState == 'hidden') {
        onBlur();
      }
    }).toJS as web.EventListener,
  );
  web.window.addEventListener(
    'pagehide',
    ((web.Event event) => onBlur()).toJS as web.EventListener,
  );
}
