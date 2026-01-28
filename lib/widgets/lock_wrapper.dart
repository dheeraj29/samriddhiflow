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
    if (state == AppLifecycleState.resumed) {
      try {
        final storage = ref.read(storageServiceProvider);
        if (storage.isAppLockEnabled() && storage.getAppPin() != null) {
          setState(() => _isLocked = true);
        }
      } catch (_) {}
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
    final effectiveLocked =
        (shouldBeLocked && !_isLocked && !_isFallbackMode) ? true : _isLocked;

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

    if ((effectiveLocked || _isLocked) && !_isFallbackMode) {
      return AppLockScreen(
        onUnlocked: () => setState(() => _isLocked = false),
        onFallback: () {
          // Sign out to force re-authentication (Forgot PIN flow)
          ref.read(authServiceProvider).signOut(ref);
          setState(() {
            _isLocked =
                false; // Will trigger rebuild showing AuthWrapper -> Login
            _isFallbackMode = false;
          });
        },
      );
    }
    return widget.child;
  }
}
