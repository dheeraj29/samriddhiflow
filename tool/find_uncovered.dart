import 'dart:io';

/// Parses lcov.info and outputs uncovered line numbers per file.
/// Usage: dart run tool/find_uncovered.dart [optional_file_filter]
void main(List<String> args) async {
  final file = File('coverage/lcov.info');
  if (!await file.exists()) {
    stdout.writeln('coverage/lcov.info not found!');
    return;
  }

  final filter = args.isNotEmpty ? args[0] : null;

  final lines = await file.readAsLines();
  final stats = <String, List<int>>{};
  final totals = <String, List<int>>{}; // all lines
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
      stats[currentFile] = [];
      totals[currentFile] = [];
    } else if (line.startsWith('DA:')) {
      if (currentFile == null) continue;
      final parts = line.substring(3).split(',');
      final lineNum = int.parse(parts[0]);
      final hits = int.parse(parts[1]);
      totals[currentFile]!.add(lineNum);
      if (hits == 0) {
        stats[currentFile]!.add(lineNum);
      }
    }
  }

  // Exclusions
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

  final keys = stats.keys
      .where((k) => k.startsWith('lib/') && !isExcluded(k))
      .where((k) => stats[k]!.isNotEmpty)
      .toList();

  // Sort by number of uncovered lines descending
  keys.sort((a, b) => stats[b]!.length.compareTo(stats[a]!.length));

  if (filter != null) {
    final filtered = keys.where((k) => k.contains(filter)).toList();
    for (final key in filtered) {
      final uncovered = stats[key]!;
      final total = totals[key]!.length;
      final covered = total - uncovered.length;
      stdout.writeln(
          '=== $key ($covered/$total = ${(covered / total * 100).toStringAsFixed(1)}%) ===');
      // Group consecutive lines into ranges
      final ranges = _groupRanges(uncovered);
      for (final range in ranges) {
        if (range.length == 1) {
          stdout.writeln('  Line ${range.first}');
        } else {
          stdout.writeln(
              '  Lines ${range.first}-${range.last} (${range.length} lines)');
        }
      }
      stdout.writeln('');
    }
  } else {
    // Summary mode
    for (final key in keys) {
      final uncovered = stats[key]!;
      final total = totals[key]!.length;
      final covered = total - uncovered.length;
      stdout.writeln(
          '$key: ${uncovered.length} uncovered (${(covered / total * 100).toStringAsFixed(1)}%)');
    }
  }
}

List<List<int>> _groupRanges(List<int> nums) {
  if (nums.isEmpty) return [];
  nums.sort();
  final ranges = <List<int>>[];
  var current = [nums[0]];
  for (int i = 1; i < nums.length; i++) {
    if (nums[i] == current.last + 1) {
      current.add(nums[i]);
    } else {
      ranges.add(current);
      current = [nums[i]];
    }
  }
  ranges.add(current);
  return ranges;
}
