import 'dart:io';

void main() async {
  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    stdout.writeln('pubspec.yaml not found!');
    return;
  }

  final pubspecLines = await pubspecFile.readAsLines();
  String? version;
  for (final line in pubspecLines) {
    if (line.startsWith('version:')) {
      version = line.split(':')[1].trim();
      break;
    }
  }

  if (version == null) {
    stdout.writeln('Version not found in pubspec.yaml');
    return;
  }

  stdout.writeln('Syncing version: $version');

  // 1. Update lib/core/app_constants.dart
  final constantsFile = File('lib/core/app_constants.dart');
  if (await constantsFile.exists()) {
    final lines = await constantsFile.readAsLines();
    final newLines = lines.map((line) {
      if (line.contains('static const String appVersion =')) {
        return "  static const String appVersion = 'v$version';";
      }
      return line;
    }).toList();
    await constantsFile.writeAsString('${newLines.join('\n')}\n');
    stdout.writeln('Updated lib/core/app_constants.dart');
  }

  // 2. Update sonar-project.properties
  final sonarFile = File('sonar-project.properties');
  if (await sonarFile.exists()) {
    final lines = await sonarFile.readAsLines();
    final newLines = lines.map((line) {
      if (line.startsWith('sonar.projectVersion=')) {
        return 'sonar.projectVersion=$version';
      }
      return line;
    }).toList();
    await sonarFile.writeAsString('${newLines.join('\n')}\n');
    stdout.writeln('Updated sonar-project.properties');
  }

  // 3. Update AI.md
  final aiFile = File('AI.md');
  if (await aiFile.exists()) {
    final lines = await aiFile.readAsLines();
    final newLines = lines.map((line) {
      if (line.startsWith('**Current Version:**')) {
        return '**Current Version:** v$version';
      }
      return line;
    }).toList();
    await aiFile.writeAsString('${newLines.join('\n')}\n');
    stdout.writeln('Updated AI.md');
  }

  stdout.writeln('Version sync complete!');
}
