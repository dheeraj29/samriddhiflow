// coverage:ignore-file
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
