import 'dart:io';

/// Removes all coverage:ignore annotations from source files under lib/.
/// Handles:
///   - // coverage:ignore-line  (appended to code lines)
///   - // coverage:ignore-start (standalone comment lines)
///   - // coverage:ignore-end   (standalone comment lines)
void main(List<String> args) async {
  final libDir = Directory('lib');
  if (!await libDir.exists()) {
    stdout.writeln('lib/ directory not found! Run from the project root.');
    return;
  }

  int totalRemoved = 0;
  int filesModified = 0;

  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  dartFiles.sort((a, b) => a.path.compareTo(b.path));

  for (final file in dartFiles) {
    final lines = await file.readAsLines();
    final newLines = <String>[];
    int removedInFile = 0;

    for (final line in lines) {
      final trimmed = line.trim();

      // Case 1: Standalone "// coverage:ignore-start" line → remove entire line
      if (trimmed == '// coverage:ignore-start') {
        removedInFile++;
        continue;
      }

      // Case 2: Standalone "// coverage:ignore-end" line → remove entire line
      if (trimmed == '// coverage:ignore-end') {
        removedInFile++;
        continue;
      }

      // Case 3: "// coverage:ignore-line" appended to a code line → strip it
      if (line.contains('// coverage:ignore-line')) {
        final stripped =
            line.replaceAll('// coverage:ignore-line', '').trimRight();
        newLines.add(stripped);
        removedInFile++;
        continue;
      }

      // Case 4: Inline "// coverage:ignore-start" appended to code → strip it
      if (line.contains('// coverage:ignore-start')) {
        final stripped =
            line.replaceAll('// coverage:ignore-start', '').trimRight();
        newLines.add(stripped);
        removedInFile++;
        continue;
      }

      // Case 5: Inline "// coverage:ignore-end" appended to code → strip it
      if (line.contains('// coverage:ignore-end')) {
        final stripped =
            line.replaceAll('// coverage:ignore-end', '').trimRight();
        newLines.add(stripped);
        removedInFile++;
        continue;
      }

      newLines.add(line);
    }

    if (removedInFile > 0) {
      await file.writeAsString('${newLines.join('\n')}\n');
      totalRemoved += removedInFile;
      filesModified++;
      final relativePath = file.path.replaceAll('\\', '/');
      stdout.writeln('$relativePath: $removedInFile annotations removed');
    }
  }

  stdout.writeln(
      '\nDone! Modified $filesModified files, removed $totalRemoved annotations.');
}
