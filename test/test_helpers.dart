import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';

/// Wraps a widget with the necessary localization delegates and providers for testing.
Widget wrapWithLocalization(Widget child, {List overrides = const []}) {
  return ProviderScope(
    overrides: [...overrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}
