import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'screens/settings_screen.dart';
import 'widgets/lock_wrapper.dart';
import 'navigator_key.dart';
import 'widgets/auth_wrapper.dart';
import 'widgets/global_overlay.dart';
import 'feature_providers.dart';

void main() {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

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

class BudgetApp extends ConsumerWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Samriddhi Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
      builder: (context, child) {
        return LockWrapper(
          child: GlobalOverlay(child: child),
        );
      },
      home: const AuthWrapper(),
    );
  }
}
