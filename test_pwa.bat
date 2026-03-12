@echo off
echo Testing Web App
call dart tool\sync_version.dart
call dart tool\remove_coverage_ignores.dart
call dart format .
call flutter test --coverage
call dart tool\update_baseline.dart
call dart tool\add_coverage_ignores.dart
call dart format .
call flutter test --coverage
call dart tool\generate_coverage_table.dart
call dart tool\check_complexity.dart
pause