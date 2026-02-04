import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/services/calendar_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';

class MockFileService extends Mock implements FileService {}

void main() {
  late MockFileService mockFileService;
  late CalendarService calendarService;

  setUp(() {
    mockFileService = MockFileService();
    calendarService = CalendarService(mockFileService);

    when(() => mockFileService.saveFile(any(), any()))
        .thenAnswer((_) async => 'mock_path');
  });

  group('CalendarService', () {
    test('downloadExvent generates correct ICS content', () async {
      final startTime = DateTime(2024, 1, 1, 10);
      final endTime = DateTime(2024, 1, 1, 11);
      final title = 'Test Event';
      final description = 'Test Description';

      await calendarService.downloadExvent(
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        allDay: false,
      );

      final result = verify(() => mockFileService.saveFile(
            any(that: contains('event_')),
            captureAny(that: isA<List<int>>()),
          ));
      result.called(1);
      final captured = result.captured.first as List<int>;
      final icsContent = utf8.decode(captured).replaceAll('\r\n', '\n');

      expect(icsContent, contains('BEGIN:VCALENDAR'));
      expect(icsContent, contains('SUMMARY:$title'));
      expect(icsContent, contains('DESCRIPTION:$description'));
      expect(icsContent, contains('DTSTART:20240101T'));
      expect(icsContent, contains('END:VEVENT'));
    });

    test('downloadRecurringEvent generates RRULE', () async {
      final startDate = DateTime(2024, 1, 1);
      final title = 'Monthly Bill';

      await calendarService.downloadRecurringEvent(
        title: title,
        description: 'Monthly reminder',
        startDate: startDate,
        occurrences: 12,
      );

      final result =
          verify(() => mockFileService.saveFile(any(), captureAny()));
      result.called(1);
      final captured = result.captured.first as List<int>;
      final icsContent = utf8.decode(captured).replaceAll('\r\n', '\n');

      expect(icsContent, contains('RRULE:FREQ=MONTHLY;COUNT=12'));
      expect(icsContent, contains('SUMMARY:$title'));
    });
  });
}
