import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('sonar_issues_final.json');
  final jsonStr = await file.readAsString();
  final data = jsonDecode(jsonStr);
  final issues = data['issues'] as List;

  final Map<String, List<Map<String, dynamic>>> grouped = {};
  for (var issue in issues) {
    final rule = issue['rule'];
    final component = issue['component'];
    final line = issue['line'];
    final msg = issue['message'];

    grouped.putIfAbsent(rule, () => []).add({
      'file': component.toString().split(':').last,
      'line': line,
      'msg': msg
    });
  }

  final output = StringBuffer();
  for (var entry in grouped.entries) {
    output.writeln("=== Rule: ${entry.key} (${entry.value.length} issues) ===");
    for (var item in entry.value) {
      output.writeln("  ${item['file']}:${item['line']} -> ${item['msg']}");
    }
    output.writeln();
  }

  File('sonar_summary_final.txt').writeAsStringSync(output.toString());
}
