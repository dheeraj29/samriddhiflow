import 'dart:io';

void main() async {
  final file = File('coverage/lcov.info');
  if (!await file.exists()) {
    stdout.writeln('coverage/lcov.info not found!');
    return;
  }

  final lines = await file.readAsLines();
  final stats = <String, _FileStats>{};
  String? currentFile;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      // SF:lib\path\to\file.dart -> normalize to relative path
      String path = line.substring(3).trim();
      // Fix windows paths if needed or normalize to lib/
      if (path.contains('lib\\')) {
        path = path.substring(path.indexOf('lib\\'));
      } else if (path.contains('lib/')) {
        path = path.substring(path.indexOf('lib/'));
      }
      path = path.replaceAll('\\', '/'); // Standardize
      currentFile = path;
      stats[currentFile] = _FileStats();
    } else if (line.startsWith('DA:')) {
      if (currentFile == null) continue;
      final parts = line.substring(3).split(',');
      final hits = int.parse(parts[1]);
      stats[currentFile]!.totalLines++;
      if (hits > 0) stats[currentFile]!.coveredLines++;
    }
  }

  // Coverage Exclusions (Sonar Definitions)
  final exclusions = [
    '**/*.g.dart',
    '**/*.freezed.dart',
    'lib/widgets/pure_icons.dart',
    'lib/theme/',
    'lib/main.dart',
    'lib/firebase_options.dart',
    'lib/firebase_options_debug.dart',
    'lib/utils/debug_logger.dart',
    'lib/navigator_key.dart',
    'lib/services/firebase_web_safe.dart',
    'lib/services/firestore_storage_service.dart',
    'lib/utils/connectivity_platform_stub.dart',
  ];

  bool isExcluded(String path) {
    for (var val in exclusions) {
      if (val.endsWith('/')) {
        // Directory match
        if (path.startsWith(val)) return true;
      } else if (val.contains('*')) {
        // Simple Glob-like match (Suffix)
        if (val.startsWith('**/*')) {
          if (path.endsWith(val.substring(4))) return true;
        }
      } else {
        // Exact
        if (path == val) return true;
      }
    }
    return false;
  }

  // Filter for key files we care about (lib/) and exclude generated (.g.dart)
  final keys =
      stats.keys.where((k) => k.startsWith('lib/') && !isExcluded(k)).toList();

  // Sort by coverage percentage (ascending)
  keys.sort((a, b) {
    final startA = stats[a]!.percent;
    final startB = stats[b]!.percent;
    if (startA != startB) return startA.compareTo(startB);
    return a.compareTo(b); // Stable sort by name
  });

  // Calculate Total Coverage
  int grandTotalLines = 0;
  int grandCoveredLines = 0;
  for (final key in keys) {
    grandTotalLines += stats[key]!.totalLines;
    grandCoveredLines += stats[key]!.coveredLines;
  }
  double totalPercent =
      grandTotalLines == 0 ? 0 : (grandCoveredLines / grandTotalLines * 100);

  final buffer = StringBuffer();
  buffer.writeln('# Samriddhi Flow - Test Coverage Report');
  buffer.writeln('');
  buffer.writeln('## Test Coverage Summary');
  buffer.writeln('> [!IMPORTANT]');
  buffer.writeln('> **Generated on: ${DateTime.now().toIso8601String()}**');
  buffer.writeln('> based on `lcov.info` from `flutter test --coverage`');
  buffer.writeln('');
  buffer.writeln(
      '### **Total Project Coverage: ${totalPercent.toStringAsFixed(1)}%**');
  buffer.writeln('');
  buffer.writeln('| File | Coverage % | Hit / Total | Status |');
  buffer.writeln('| :--- | :---: | :---: | :---: |');

  for (final key in keys) {
    final s = stats[key]!;
    final percent = s.percent;
    final status = s.statusText;
    final fileName = key.replaceFirst('lib/', '');

    // Bold important files (Screens/Providers)
    final displayName =
        (key.contains('/screens/') || key.contains('/providers'))
            ? '**$fileName**'
            : fileName;

    buffer.writeln(
        '| $displayName | **${percent.toStringAsFixed(1)}%** | ${s.coveredLines}/${s.totalLines} | $status |');
  }

  final outFile = File('coverage.md');
  await outFile.writeAsString(buffer.toString());
  stdout.writeln('Coverage report written to coverage.md');
}

class _FileStats {
  int totalLines = 0;
  int coveredLines = 0;

  double get percent =>
      totalLines == 0 ? 100.0 : (coveredLines / totalLines * 100);

  String get statusText {
    if (percent >= 80) return 'PASS';
    if (percent >= 60) return 'WARN';
    return 'FAIL';
  }
}
