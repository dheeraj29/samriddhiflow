import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    print('coverage/lcov.info not found');
    return;
  }

  final lines = file.readAsLinesSync();
  String? currentFile;
  Map<String, List<int>> coverage = {}; // file -> [hits, total]

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      coverage[currentFile] = [0, 0];
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final hits = int.parse(parts[1]);
      coverage[currentFile]![1]++;
      if (hits > 0) {
        coverage[currentFile]![0]++;
      }
    }
  }

  print('| File | Coverage | Hits | Total |');
  print('| --- | --- | --- | --- |');

  final sortedFiles = coverage.keys.toList()..sort();
  int totalHits = 0;
  int totalLines = 0;

  for (final f in sortedFiles) {
    final stats = coverage[f]!;
    final percent = (stats[0] / stats[1] * 100).toStringAsFixed(1);
    print('| $f | $percent% | ${stats[0]} | ${stats[1]} |');
    totalHits += stats[0];
    totalLines += stats[1];
  }

  final totalPercent = (totalHits / totalLines * 100).toStringAsFixed(1);
  print(
      '| **TOTAL** | **$totalPercent%** | **$totalHits** | **$totalLines** |');
}
