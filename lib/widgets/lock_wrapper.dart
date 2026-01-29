import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _isObscured = false; // For privacy screen
  DateTime? _backgroundTimestamp; // For delayed lock

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Don't check lock here immediately; wait for storage init via build or listener
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
        state == AppLifecycleState.inactive) {
      // App is going to background or app switcher
      // 1. Show Privacy Screen immediately
      setState(() => _isObscured = true);

      // 2. Record timestamp for delayed lock
      _backgroundTimestamp = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // App is back
      // 1. Check duration
      if (_backgroundTimestamp != null) {
        final duration = DateTime.now().difference(_backgroundTimestamp!);
        if (duration.inMinutes >= 1) {
          // Time exceeded, Lock!
          try {
            final storage = ref.read(storageServiceProvider);
            if (storage.isAppLockEnabled() && storage.getAppPin() != null) {
              setState(() => _isLocked = true);
            }
          } catch (_) {}
        }
        _backgroundTimestamp = null;
      }

      // 2. Hide Privacy Screen (reveal content or lock screen)
      setState(() => _isObscured = false);
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
    final user = ref.read(authServiceProvider).currentUser;
    final shouldBeLocked = user != null &&
        storage.isAppLockEnabled() &&
        storage.getAppPin() != null;

    // We only force _isLocked to true if it hasn't been verified yet and we KNOW it should be.
    // But setState during build is tricky, so we rely on the flags.
    // We only force _isLocked to true if it hasn't been verified yet and we KNOW it should be.
    // But setState during build is tricky, so we rely on the flags.

    // FIX: Do not override _isLocked with shouldBeLocked.
    // Initial lock is handled by _checkInitialLock and lifecycle observer.
    // Overriding here causes immediate re-lock after successful unlock callback.
    // final effectiveLocked = (shouldBeLocked && !_isLocked && !_isFallbackMode) ? true : _isLocked;

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

    return Stack(
      children: [
        // 1. The main app content (maybe locked)
        _buildContent(),

        // 2. Privacy Overlay (Obscures everything when backgrounded)
        if (_isObscured)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: Icon(Icons.lock, size: 80, color: Colors.grey),
              ),
            ),
          ),
      ],
    );
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
