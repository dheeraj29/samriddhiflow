import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A simple in-memory logger for debugging production issues on mobile/PWA.
class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  final List<String> _logs = [];
  final int _maxLogs = 200;
  final ValueNotifier<int> _notifier = ValueNotifier(0);

  ValueNotifier<int> get notifier => _notifier;

  void log(String message) {
    // Also print to console for dev
    debugPrint("[AppLog] $message");

    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    _logs.add("[$timestamp] $message");

    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    _notifier.value++;
  }

  List<String> get logs => List.unmodifiable(_logs.reversed);

  void clear() {
    _logs.clear();
    _notifier.value++;
  }
}

/// A widget to display the logs
class LogViewerScreen extends StatelessWidget {
  const LogViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Debug Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              // TODO: Implement copy to clipboard
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              DebugLogger().clear();
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: DebugLogger().notifier,
        builder: (context, _, __) {
          final logs = DebugLogger().logs;
          if (logs.isEmpty) {
            return const Center(child: Text("No logs yet."));
          }
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                child: Text(
                  logs[index],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
