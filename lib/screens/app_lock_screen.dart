import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../widgets/pure_icons.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onFallback;
  const AppLockScreen(
      {super.key, required this.onUnlocked, required this.onFallback});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _pin = "";
  String? _error;

  void _onDigit(String d) {
    if (_pin.length < 4) {
      setState(() {
        _pin += d;
        _error = null;
      });

      if (_pin.length == 4) {
        _verify();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  void _verify() {
    final storage = ref.read(storageServiceProvider);
    final storedPin = storage.getAppPin();

    if (_pin == storedPin) {
      widget.onUnlocked();
    } else {
      setState(() {
        _pin = "";
        _error = "Incorrect PIN";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            PureIcons.lockOutline(size: 64, color: Colors.teal),
            const SizedBox(height: 24),
            const Text(
              'Enter PIN',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                bool filled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? Colors.teal : Colors.grey.withOpacity(0.3),
                  ),
                );
              }),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            // Numeric Keypad
            _buildKeypad(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onFallback,
              child: const Text('Forgot PIN? / Use Password'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((d) => _buildKey(d)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 80), // Empty placeholder
            _buildKey('0'),
            _buildKey('backspace',
                icon: null), // We'll handle icon inside _buildKey
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String value, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.all(8),
      width: 80,
      height: 80,
      child: InkWell(
        onTap: value == 'backspace' ? _onBackspace : () => _onDigit(value),
        borderRadius: BorderRadius.circular(40),
        child: Center(
          child: value == 'backspace'
              ? PureIcons.backspace(size: 28)
              : Text(
                  value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}
