import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    // ignore: avoid_print
    print('lcov.info not found');
    return;
  }

  final lines = file.readAsLinesSync();
  bool inProviders = false;

  for (final line in lines) {
    if (line.startsWith('SF:') && line.endsWith('lib\\providers.dart') ||
        line.endsWith('lib/providers.dart')) {
      inProviders = true;
    } else if (line == 'end_of_record') {
      inProviders = false;
    }

    if (inProviders && line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length == 2 && parts[1] == '0') {
        // ignore: avoid_print
        print(parts[0]);
      }
    }
  }
}
