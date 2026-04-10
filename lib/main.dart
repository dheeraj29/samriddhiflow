import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/settings_screen.dart';
import 'screens/taxes/tax_dashboard_screen.dart';
import 'widgets/lock_wrapper.dart';
import 'navigator_key.dart';
import 'widgets/auth_wrapper.dart';
import 'widgets/global_overlay.dart';
import 'feature_providers.dart';
import 'screens/investments_screen.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('settings');

  // Custom Error Widget (Replaces Red Screen of Death)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text("Something went wrong",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                    "We encountered an unexpected error.\nPlease restart the app.",
                    textAlign: TextAlign.center),
              ),
              ElevatedButton(
                onPressed: () {
                  // Simple reload attempt (works well on Web)
                  // On native, this might just rebuild this widget, but it's better than nothing.
                  // For PWA web, triggering a reload is best.
                  // Since we can't easily access 'html.window' here without imports,
                  // we just try to re-render the app.
                  WidgetsBinding.instance.reassembleApplication();
                },
                child: const Text("Retry"),
              )
            ],
          ),
        ),
      ),
    );
  };

  // Hive & Storage initialization is now fully handled by `storageInitializerProvider`
  // in `providers.dart`. This ensures the UI (Splash Screen) renders INSTANTLY
  // without waiting for any async storage operations, preventing white screens.

  runApp(
    const ProviderScope(
      child: BudgetApp(),
    ),
  );
}

class ClearFocusObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

class BudgetApp extends ConsumerWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      navigatorObservers: [ClearFocusObserver()],
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/taxes': (context) => const TaxDashboardScreen(),
        '/investments': (context) => const InvestmentsScreen(),
      },
      builder: (context, child) {
        return PopScope(
          canPop: false,
          child: LockWrapper(
            child: GlobalOverlay(child: child),
          ),
        );
      },
      home: const AuthWrapper(),
    );
  }
}
