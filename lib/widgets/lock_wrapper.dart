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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // App is going to background or app switcher
      // Record timestamp for delayed lock
      _backgroundTimestamp = clock.now();
    } else if (state == AppLifecycleState.resumed) {
      // App is back
      // Check duration
      if (_backgroundTimestamp != null) {
        final now = clock.now();
        final duration = now.difference(_backgroundTimestamp!);
        if (duration.inMinutes >= 1) {
          // Time exceeded, Lock!
          try {
            final storage = ref.read(storageServiceProvider);
            if (storage.isAppLockEnabled() && storage.getAppPin() != null) {
              setState(() => _isLocked = true);
            }
          } catch (_) {
            // Storage not ready or error, ignore
          }
        }
        _backgroundTimestamp = null;
      }
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

    // If storage is not ready, don't show anything yet to prevent glitch
    if (!storageInit.hasValue) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Safety: If storage JUST finished but listener hasn't fired yet,
    // we do a one-time sync check to prevent that 1-frame glitch.
    final storage = ref.read(storageServiceProvider);

    // Watch for manual lock intent
    ref.listen(appLockIntentProvider, (previous, next) {
      if (next == true) {
        setState(() => _isLocked = true);
        // Reset intent
        ref.read(appLockIntentProvider.notifier).reset();
      }
    });

    // Watch Auth State - if user logs in VIA FALLBACK, we can unlock
    ref.listen(authStreamProvider, (previous, next) {
      if (next.value != null && previous?.value == null && _isFallbackMode) {
        // User just logged in via Forgot PIN fallback
        // Disable App Lock to prevent immediate re-lock.
        final storage = ref.read(storageServiceProvider);
        final wasLocked =
            storage.isAppLockEnabled() && storage.getAppPin() != null;

        if (wasLocked) {
          _disableAppLock();

          // Use a post-frame callback to show snackbar since we are in build/listener
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('App Unlocked. Please Reset your PIN in Settings.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ));
          });
        }

        setState(() {
          _isLocked = false;
          _isFallbackMode = false;
        });
      }
    });

    // Check for PIN Reset Request (Forgot PIN Flow)
    // This executes when user logs BACK IN (or on app start if already logged in but flag is set)
    if (_isLocked && storage.getPinResetRequested()) {
      _disableAppLock();
      storage.setPinResetRequested(false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _isLocked = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('App Unlocked. Please Reset your PIN in Settings.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ));
      });
      return widget.child;
    }

    return _buildContent();
  }

  Widget _buildContent() {
    if (_isLocked && !_isFallbackMode) {
      return AppLockScreen(
        onUnlocked: () => setState(() => _isLocked = false),
        onFallback: () async {
          // Sign out to force re-authentication (Forgot PIN flow)
          // Set persistent flag so we know to reset PIN on next login
          final storage = ref.read(storageServiceProvider);
          await storage.setPinResetRequested(true);

          await ref.read(authServiceProvider).signOut(ref);
          if (mounted) {
            setState(() => _isFallbackMode = false); // Cleanup state
          }
        },
      );
    }
    return widget.child;
  }
}
