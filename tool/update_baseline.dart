import 'dart:io';

void main() async {
  final lcovFile = File('coverage/lcov.info');
  if (!await lcovFile.exists()) {
    stdout.writeln('coverage/lcov.info not found!');
    return;
  }

  final lines = await lcovFile.readAsLines();
  final stats = <String, _FileStats>{};
  String? currentFile;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      String path = line.substring(3).trim();
      if (path.contains('lib\\')) {
        path = path.substring(path.indexOf('lib\\'));
      } else if (path.contains('lib/')) {
        path = path.substring(path.indexOf('lib/'));
      }
      path = path.replaceAll('\\', '/');
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

  final exclusions = [
    '.g.dart',
    '.freezed.dart',
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
        if (path.startsWith(val)) return true;
      } else {
        if (path.endsWith(val) || path == val) return true;
      }
    }
    return false;
  }

  int totalLines = 0;
  int coveredLines = 0;

  for (final key in stats.keys) {
    if (key.startsWith('lib/') && !isExcluded(key)) {
      totalLines += stats[key]!.totalLines;
      coveredLines += stats[key]!.coveredLines;
    }
  }

  final coverage = totalLines == 0 ? 0.0 : (coveredLines / totalLines * 100);
  final coverageStr = coverage.toStringAsFixed(1);

  stdout.writeln('Calculated Baseline Coverage: $coverageStr%');

  final aiFile = File('AI.md');
  if (await aiFile.exists()) {
    final aiLines = await aiFile.readAsLines();
    final newLines = aiLines.map((line) {
      // Look for the specific baseline line pattern
      if (line.contains(
          '2. **Baselines**: The current project coverage baseline is')) {
        // Replace the percentage
        final pattern = RegExp(r'baseline is \*\*[\d.]+%?\*\*');
        if (pattern.hasMatch(line)) {
          return line.replaceFirst(pattern, 'baseline is **$coverageStr%**');
        }
      }
      return line;
    }).toList();

    await aiFile.writeAsString('${newLines.join('\n')}\n');
    stdout.writeln('Updated AI.md coverage baseline to $coverageStr%');
  }
}

class _FileStats {
  int totalLines = 0;
  int coveredLines = 0;
}
