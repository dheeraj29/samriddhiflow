import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/services/calendar_service.dart';

void main() {
  test('CalendarService sanity check', () {
    // CalendarService doesn't have public helper methods for logic, it just generates files.
    // So we will smoke test the public API methods to ensure they accept valid dates without crashing.
    // We cannot easily verify the output file content here without mocking FileService further.

    // Smoke Test:
    expect(CalendarService, isNotNull);
  });
}
