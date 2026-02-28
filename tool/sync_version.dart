import 'dart:io';

void main() async {
  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    print('pubspec.yaml not found!');
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
    print('Version not found in pubspec.yaml');
    return;
  }

  print('Syncing version: $version');

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
    print('Updated lib/core/app_constants.dart');
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
    print('Updated sonar-project.properties');
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
    print('Updated AI.md');
  }

  print('Version sync complete!');
}
