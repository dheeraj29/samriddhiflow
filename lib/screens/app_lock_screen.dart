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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                        height: 48), // Padding at top for small scrolls
                    PureIcons.lockOutline(size: 64, color: Colors.teal),
                    const SizedBox(height: 24),
                    const Text(
                      'Enter PIN',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                            color: filled
                                ? Colors.teal
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        );
                      }),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(
                        height: 48), // Spacing between header and keypad
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
          },
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
            _buildKey('submit'),
            _buildKey('0'),
            _buildKey('backspace'),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String value) {
    VoidCallback? onTap;
    Widget child;

    if (value == 'backspace') {
      onTap = _onBackspace;
      child = PureIcons.backspace(size: 28);
    } else if (value == 'submit') {
      onTap = _pin.length == 4 ? _verify : null;
      child = Icon(
        Icons.check_circle,
        size: 40,
        color:
            _pin.length == 4 ? Colors.teal : Colors.grey.withValues(alpha: 0.3),
      );
    } else {
      onTap = () => _onDigit(value);
      child = Text(
        value,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      );
    }

    return Container(
      margin: const EdgeInsets.all(8),
      width: 80,
      height: 80,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Center(child: child),
      ),
    );
  }
}
