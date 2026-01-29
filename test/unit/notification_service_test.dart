import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/services/notification_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/loan.dart';

class MockStorageService extends Mock implements StorageService {}

class FakeLoan extends Fake implements Loan {}

void main() {
  late NotificationService notificationService;
  late MockStorageService mockStorageService;

  setUpAll(() {
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockStorageService = MockStorageService();
    notificationService = NotificationService(mockStorageService);

    // Default Stubs
    when(() => mockStorageService.setLastLogin(any())).thenAnswer((_) async {});
    when(() => mockStorageService.getInactivityThresholdDays()).thenReturn(7);
    when(() => mockStorageService.getMaturityWarningDays()).thenReturn(3);
    when(() => mockStorageService.getLoans()).thenReturn([]);
  });

  test('checkNudges returns empty list on first login', () async {
    when(() => mockStorageService.getLastLogin()).thenReturn(null);

    final nudges = await notificationService.checkNudges();

    expect(nudges, isEmpty);
    verify(() => mockStorageService.setLastLogin(any())).called(1);
  });

  test('checkNudges adds inactivity message if threshold exceeded', () async {
    final lastLogin = DateTime.now().subtract(const Duration(days: 10));
    when(() => mockStorageService.getLastLogin()).thenReturn(lastLogin);

    final nudges = await notificationService.checkNudges();

    expect(nudges, hasLength(1));
    expect(nudges.first, contains("haven't checked your budget in 10 days"));
  });

  test('checkNudges ignores inactivity if within threshold', () async {
    final lastLogin = DateTime.now().subtract(const Duration(days: 5));
    when(() => mockStorageService.getLastLogin()).thenReturn(lastLogin);

    final nudges = await notificationService.checkNudges();

    expect(nudges, isEmpty);
  });

  test('checkNudges adds warning for maturing loan', () async {
    when(() => mockStorageService.getLastLogin()).thenReturn(DateTime.now());

    // Maturing in 2 days (Warning Days = 3)
    // We expect 2 days, so we need diff = 2.
    // Maturity = Start + 300 days.
    // Start = Now + 2 - 300 = Now - 298.
    // Adding 1 hour to ensure difference is > 1.99 days (so truncated to 2 if positive, or closer to 2).
    // Actually DateTime difference inDays simply truncates.
    // If difference is 1 day 23 hours, inDays is 1.
    // We want 2 days. So difference must be >= 2 days.
    // So Maturity >= Now + 2 days.
    // Start + 300 >= Now + 2.
    // Start >= Now - 298.
    // Let's set Start = Now - 298 + 1 hour.
    // Maturity = Now + 2 days + 1 hour.
    // Diff = 2 days 1 hour = 2 days.

    final loan = Loan.create(
      name: 'Maturing Loan',
      principal: 10000,
      rate: 10,
      tenureMonths: 10,
      startDate: DateTime.now()
          .subtract(const Duration(days: 298))
          .add(const Duration(hours: 1)),
      emiAmount: 1000,
      emiDay: 1,
      firstEmiDate: DateTime.now(),
    );
    // Force remaining principal > 0
    loan.remainingPrincipal = 5000;

    when(() => mockStorageService.getLoans()).thenReturn([loan]);

    final nudges = await notificationService.checkNudges();

    expect(nudges, hasLength(1));
    expect(
        nudges.first, contains("Loan 'Maturing Loan' is maturing in 2 days"));
  });

  test('checkNudges adds overdue message for expired loan', () async {
    when(() => mockStorageService.getLastLogin()).thenReturn(DateTime.now());

    // Overdue by 5 days
    final loan = Loan.create(
      name: 'Overdue Loan',
      principal: 10000,
      rate: 10,
      tenureMonths: 10,
      startDate: DateTime.now().subtract(const Duration(days: 300 + 5)),
      emiAmount: 1000,
      emiDay: 1,
      firstEmiDate: DateTime.now(),
    );
    loan.remainingPrincipal = 5000;

    when(() => mockStorageService.getLoans()).thenReturn([loan]);

    final nudges = await notificationService.checkNudges();

    expect(nudges, hasLength(1));
    expect(nudges.first, contains("Loan 'Overdue Loan' is OVERDUE by 5 days"));
  });

  test('checkNudges ignores completed loans', () async {
    when(() => mockStorageService.getLastLogin()).thenReturn(DateTime.now());

    final loan = Loan.create(
      name: 'Paid Loan',
      principal: 10000,
      rate: 10,
      tenureMonths: 10,
      startDate: DateTime.now().subtract(const Duration(days: 290)),
      emiAmount: 1000,
      emiDay: 1,
      firstEmiDate: DateTime.now(),
    );
    loan.remainingPrincipal = 0; // Completed

    when(() => mockStorageService.getLoans()).thenReturn([loan]);

    final nudges = await notificationService.checkNudges();

    expect(nudges, isEmpty);
  });
}
