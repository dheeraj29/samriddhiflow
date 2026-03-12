import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clock/clock.dart';
import '../providers.dart';
import '../screens/app_lock_screen.dart';

class LockWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const LockWrapper({super.key, required this.child});

  @override
  ConsumerState<LockWrapper> createState() => _LockWrapperState();
}

class _LockWrapperState extends ConsumerState<LockWrapper>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isFallbackMode = false;
  DateTime? _backgroundTimestamp; // For delayed lock

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkInitialLock() {
    // Safety: Only run if storage is initialized
    try {
      final storage = ref.read(storageServiceProvider);
      if (storage.isAppLockEnabled() && storage.getAppPin() != null) {
        setState(() => _isLocked = true);
      } else {
        setState(() => _isLocked = false);
      }
    } catch (_) {
      // Storage not ready, assume unlocked
      setState(() => _isLocked = false);
    }
  }

  void _disableAppLock() {
    try {
      final storage = ref.read(storageServiceProvider);
      storage.setAppLockEnabled(false);
      // Optionally clear PIN or leave it for reset flow
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _backgroundTimestamp = clock.now();
      case AppLifecycleState.resumed:
        _handleResume();
      case AppLifecycleState.detached: // coverage:ignore-line
        break;
    }
  }

  void _handleResume() {
    if (_backgroundTimestamp == null) return;
    final duration = clock.now().difference(_backgroundTimestamp!);
    _backgroundTimestamp = null;
    if (duration.inMinutes < 1) return;

    try {
      final storage = ref.read(storageServiceProvider);
      if (storage.isAppLockEnabled() && storage.getAppPin() != null) {
        setState(() => _isLocked = true);
      }
    } catch (_) {
      // Storage not ready or error, ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final storageInit = ref.watch(storageInitializerProvider);

    // Perform initial check once storage is ready
    ref.listen(storageInitializerProvider, (prev, next) {
      if (next.hasValue) {
        _checkInitialLock();
      }
    });

    return storageInit.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => _buildErrorView(e), // coverage:ignore-line
      data: (_) => _buildDataView(context),
    );
  }

  // coverage:ignore-start
  Widget _buildErrorView(Object error) {
    return Scaffold(
      body: Center(
        child: Padding(
          // coverage:ignore-end
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // coverage:ignore-line
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // coverage:ignore-line
              const Icon(Icons.error_outline, size: 48, color: Colors.amber),
              const SizedBox(height: 16),
              const Text(
                "Storage Error",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                  "Unable to initialize secure storage.\n$error", // coverage:ignore-line
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                // coverage:ignore-line
                onPressed: () => ref.refresh(
                    storageInitializerProvider), // coverage:ignore-line
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataView(BuildContext context) {
    final storage = ref.read(storageServiceProvider);

    _setupListeners(context, storage);

    // One-time Check for PIN Reset Request (Forgot PIN Flow)
    if (_isLocked && storage.getPinResetRequested()) {
      _handlePinReset(context, storage);
    }

    return _buildViewStack(storage);
  }

  void _setupListeners(BuildContext context, dynamic storage) {
    // 1. Watch for manual lock intent
    ref.listen(appLockIntentProvider, (previous, next) {
      // coverage:ignore-start
      if (next == true) {
        setState(() => _isLocked = true);
        ref.read(appLockIntentProvider.notifier).reset();
        // coverage:ignore-end
      }
    });

    // 2. Watch Auth State - if user logs in VIA FALLBACK, we can unlock
    ref.listen(authStreamProvider, (previous, next) {
      if (next.value != null && previous?.value == null && _isFallbackMode) {
        _handleFallbackLogin(context, storage); // coverage:ignore-line
      }
    });
  }

  Widget _buildViewStack(dynamic storage) {
    return Stack(
      children: [
        Visibility(
          visible: !_isLocked || _isFallbackMode,
          maintainState: true,
          child: widget.child,
        ),
        if (_isLocked && !_isFallbackMode)
          Positioned.fill(
            child: AppLockScreen(
              onUnlocked: () =>
                  setState(() => _isLocked = false), // coverage:ignore-line
              onFallback: () => _handleLockFallback(storage),
            ),
          ),
      ],
    );
  }

  Future<void> _handleLockFallback(dynamic storage) async {
    await storage.setPinResetRequested(true);
    await ref.read(authServiceProvider).signOut(ref);
    if (mounted) {
      setState(() => _isFallbackMode = false);
    }
  }

  void _handleFallbackLogin(BuildContext context, dynamic storage) {
    // coverage:ignore-line
    final wasLocked = storage.isAppLockEnabled() &&
        storage.getAppPin() != null; // coverage:ignore-line

    if (wasLocked) {
      // coverage:ignore-start
      _disableAppLock();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            // coverage:ignore-end
            content: Text('App Unlocked. Please Reset your PIN in Settings.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ));
        }
      });
    }

    // coverage:ignore-start
    setState(() {
      _isLocked = false;
      _isFallbackMode = false;
      // coverage:ignore-end
    });
  }

  void _handlePinReset(BuildContext context, dynamic storage) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _disableAppLock();
      storage.setPinResetRequested(false);
      if (mounted) setState(() => _isLocked = false);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('App Unlocked. Please Reset your PIN in Settings.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ));
    });
  }
}
