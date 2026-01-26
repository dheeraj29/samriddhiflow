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
    final shouldBeLocked =
        storage.isAppLockEnabled() && storage.getAppPin() != null;

    // We only force _isLocked to true if it hasn't been verified yet and we KNOW it should be.
    // But setState during build is tricky, so we rely on the flags.
    final effectiveLocked =
        (shouldBeLocked && !_isLocked && !_isFallbackMode) ? true : _isLocked;

    // Watch Auth State - if user logs in, we can optionally unlock
    ref.listen(authStreamProvider, (previous, next) {
      if (next.value != null && previous?.value == null) {
        // User just logged in (e.g. via Forgot PIN fallback)
        setState(() {
          _isLocked = false;
          _isFallbackMode = false;
        });
      }
    });

    if ((effectiveLocked || _isLocked) && !_isFallbackMode) {
      return AppLockScreen(
        onUnlocked: () => setState(() => _isLocked = false),
        onFallback: () => setState(() => _isFallbackMode = true),
      );
    }
    return widget.child;
  }
}
