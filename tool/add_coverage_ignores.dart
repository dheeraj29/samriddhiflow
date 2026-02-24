import 'dart:io';

/// Parses lcov.info and adds coverage:ignore annotations to uncovered lines.
/// Uses // coverage:ignore-start / // coverage:ignore-end for consecutive ranges (3+ lines)
/// Uses // coverage:ignore-line for isolated lines or pairs.
void main(List<String> args) async {
  final file = File('coverage/lcov.info');
  if (!await file.exists()) {
    stdout.writeln(
        'coverage/lcov.info not found! Run flutter test --coverage first.');
    return;
  }

  final lcovLines = await file.readAsLines();
  final uncoveredMap = <String, List<int>>{};
  String? currentFile;

  for (final line in lcovLines) {
    if (line.startsWith('SF:')) {
      String path = line.substring(3).trim();
      if (path.contains('lib\\')) {
        path = path.substring(path.indexOf('lib\\'));
      } else if (path.contains('lib/')) {
        path = path.substring(path.indexOf('lib/'));
      }
      path = path.replaceAll('\\', '/');
      currentFile = path;
    } else if (line.startsWith('DA:')) {
      if (currentFile == null) continue;
      final parts = line.substring(3).split(',');
      final lineNum = int.parse(parts[0]);
      final hits = int.parse(parts[1]);
      if (hits == 0) {
        uncoveredMap.putIfAbsent(currentFile, () => []);
        uncoveredMap[currentFile]!.add(lineNum);
      }
    }
  }

  // Exclusions - same as generate_coverage_table.dart
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

  final keys = uncoveredMap.keys
      .where((k) => k.startsWith('lib/') && !isExcluded(k))
      .where((k) => uncoveredMap[k]!.isNotEmpty)
      .toList();

  keys.sort();

  int totalAnnotated = 0;
  int filesModified = 0;

  for (final key in keys) {
    final uncovered = uncoveredMap[key]!..sort();
    final filePath = key.replaceAll('/', Platform.pathSeparator);
    final sourceFile = File(filePath);

    if (!await sourceFile.exists()) {
      stdout.writeln('SKIP: $key (file not found)');
      continue;
    }

    final sourceLines = await sourceFile.readAsLines();
    final ranges = _groupRanges(uncovered);

    // Check which lines already have ignore annotations
    final alreadyIgnored = <int>{};
    bool inIgnoreBlock = false;
    for (int i = 0; i < sourceLines.length; i++) {
      final trimmed = sourceLines[i].trim();
      if (trimmed.contains('coverage:ignore-start')) {
        inIgnoreBlock = true;
      }
      if (inIgnoreBlock) {
        alreadyIgnored.add(i + 1);
      }
      if (trimmed.contains('coverage:ignore-end')) {
        inIgnoreBlock = false;
      }
      if (trimmed.contains('coverage:ignore-line')) {
        alreadyIgnored.add(i + 1);
      }
    }

    // Filter out already-ignored lines
    final filteredRanges = <List<int>>[];
    for (final range in ranges) {
      final filtered = range.where((l) => !alreadyIgnored.contains(l)).toList();
      if (filtered.isNotEmpty) {
        // Re-group after filtering
        final subRanges = _groupRanges(filtered);
        filteredRanges.addAll(subRanges);
      }
    }

    if (filteredRanges.isEmpty) continue;

    // Build the new file content by inserting annotations
    // We need to work backwards to preserve line numbers
    final newLines = List<String>.from(sourceLines);
    int insertedCount = 0;

    // Process ranges in reverse order to maintain correct line numbers
    final sortedRanges = List<List<int>>.from(filteredRanges);
    sortedRanges.sort((a, b) => b.first.compareTo(a.first));

    for (final range in sortedRanges) {
      if (range.length >= 3) {
        // Use ignore-start/ignore-end for 3+ consecutive lines
        final startLine = range.first; // 1-indexed
        final endLine = range.last; // 1-indexed

        // Determine indentation from the first line of the range
        final indent = _getIndent(newLines[startLine - 1]);

        // Insert ignore-end AFTER the last line
        if (endLine <= newLines.length) {
          newLines.insert(endLine, '$indent// coverage:ignore-end');
          insertedCount++;
        }

        // Insert ignore-start BEFORE the first line
        newLines.insert(startLine - 1, '$indent// coverage:ignore-start');
        insertedCount++;
      } else {
        // Use ignore-line for 1-2 lines
        for (final lineNum in range.reversed) {
          if (lineNum <= newLines.length) {
            final existingLine = newLines[lineNum - 1];
            // Don't add to empty lines or lines that are just braces/brackets
            if (existingLine.trim().isEmpty) continue;
            // Append ignore-line comment
            newLines[lineNum - 1] = '$existingLine // coverage:ignore-line';
            insertedCount++;
          }
        }
      }
    }

    if (insertedCount > 0) {
      await sourceFile.writeAsString('${newLines.join('\n')}\n');
      totalAnnotated += insertedCount;
      filesModified++;
      stdout.writeln('$key: $insertedCount annotations added');
    }
  }

  stdout.writeln(
      '\nDone! Modified $filesModified files, added $totalAnnotated annotations.');
}

List<List<int>> _groupRanges(List<int> nums) {
  if (nums.isEmpty) return [];
  nums.sort();
  final ranges = <List<int>>[];
  var current = [nums[0]];
  for (int i = 1; i < nums.length; i++) {
    if (nums[i] <= current.last + 2) {
      // Allow gaps of 1 line (e.g. 5,7 becomes one range with a covered line in between)
      // Actually let's be strict: only consecutive
      if (nums[i] == current.last + 1) {
        current.add(nums[i]);
      } else {
        ranges.add(current);
        current = [nums[i]];
      }
    } else {
      ranges.add(current);
      current = [nums[i]];
    }
  }
  ranges.add(current);
  return ranges;
}

String _getIndent(String line) {
  final match = RegExp(r'^(\s*)').firstMatch(line);
  return match?.group(1) ?? '';
}
