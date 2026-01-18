import 'dart:convert';
import 'package:intl/intl.dart';
import 'file_service.dart';

class CalendarService {
  final FileService _fileService;
  CalendarService(this._fileService);

  /// Generates and downloads an ICS file for a specific event
  Future<void> downloadExvent(
      {required String title,
      required String description,
      required DateTime startTime,
      required DateTime endTime,
      bool allDay = true}) async {
    final icsContent = _generateIcsContent(
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      allDay: allDay,
    );

    await _fileService.saveFile(
        'event_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.ics',
        utf8.encode(icsContent));
  }

  /// Generates and downloads an ICS file for a recurring monthly event
  /// [uids] should be unique for the series if updating, but for new simple export we use random.
  Future<void> downloadRecurringEvent({
    required String title,
    required String description,
    required DateTime startDate,
    required int occurrences, // e.g. 12 for 1 year
    int dayOfMonth = 1,
  }) async {
    // Adjust start date to the correct day of month if needed, or assume startDate is correct first instance
    final icsContent = _generateRecurringIcsContent(
        title: title,
        description: description,
        startDate: startDate,
        occurrences: occurrences);
    await _fileService.saveFile(
        'recurring_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.ics',
        utf8.encode(icsContent));
  }

  String _generateIcsContent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    bool allDay = true,
  }) {
    final dateFormat = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final now = dateFormat.format(DateTime.now().toUtc());
    final start = dateFormat.format(startTime.toUtc());
    final end = dateFormat.format(endTime.toUtc());

    return "BEGIN:VCALENDAR\n"
        "VERSION:2.0\n"
        "PRODID:-//BudgetPWA//NONSGML Event//EN\n"
        "BEGIN:VEVENT\n"
        "UID:${DateTime.now().millisecondsSinceEpoch}@budgetpwa.com\n"
        "DTSTAMP:$now\n"
        "DTSTART:$start\n"
        "DTEND:$end\n"
        "SUMMARY:$title\n"
        "DESCRIPTION:$description\n"
        "END:VEVENT\n"
        "END:VCALENDAR";
  }

  String _generateRecurringIcsContent(
      {required String title,
      required String description,
      required DateTime startDate,
      required int occurrences}) {
    final dateFormat = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final now = dateFormat.format(DateTime.now().toUtc());
    final start = dateFormat.format(startDate.toUtc());
    // End is start + 1 hour usually for reminders
    final end =
        dateFormat.format(startDate.add(const Duration(hours: 1)).toUtc());

    return "BEGIN:VCALENDAR\n"
        "VERSION:2.0\n"
        "PRODID:-//BudgetPWA//NONSGML Event//EN\n"
        "BEGIN:VEVENT\n"
        "UID:${DateTime.now().millisecondsSinceEpoch}@budgetpwa.com\n"
        "DTSTAMP:$now\n"
        "DTSTART:$start\n"
        "DTEND:$end\n"
        "RRULE:FREQ=MONTHLY;COUNT=$occurrences\n"
        "SUMMARY:$title\n"
        "DESCRIPTION:$description\n"
        "END:VEVENT\n"
        "END:VCALENDAR";
  }
}
