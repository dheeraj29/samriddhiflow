import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/lending_record.dart';

void main() {
  group('LendingRecord Model Tests', () {
    final testDate = DateTime(2024, 1, 1);
    final testClosedDate = DateTime(2024, 1, 10);

    test('LendingRecord.create initializes correctly', () {
      final record = LendingRecord.create(
        personName: 'Alice',
        amount: 1000.0,
        reason: 'Lunch',
        date: testDate,
        type: LendingType.lent,
        profileId: 'p1',
      );

      expect(record.id, isNotEmpty);
      expect(record.personName, 'Alice');
      expect(record.amount, 1000.0);
      expect(record.reason, 'Lunch');
      expect(record.date, testDate);
      expect(record.type, LendingType.lent);
      expect(record.isClosed, false);
      expect(record.closedDate, isNull);
      expect(record.profileId, 'p1');
    });

    test('LendingRecord.copyWith updates specified fields', () {
      final record = LendingRecord(
        id: '123',
        personName: 'Bob',
        amount: 500.0,
        reason: 'Dinner',
        date: testDate,
        type: LendingType.borrowed,
      );

      final updated = record.copyWith(
        personName: 'Charlie',
        isClosed: true,
        closedDate: testClosedDate,
      );

      expect(updated.id, '123');
      expect(updated.personName, 'Charlie'); // Changed
      expect(updated.amount, 500.0);
      expect(updated.reason, 'Dinner');
      expect(updated.date, testDate);
      expect(updated.type, LendingType.borrowed);
      expect(updated.isClosed, true); // Changed
      expect(updated.closedDate, testClosedDate); // Changed
    });

    test('LendingRecord serialization (toMap / fromMap)', () {
      final record = LendingRecord(
        id: '456',
        personName: 'Dan',
        amount: 250.0,
        reason: 'Gift',
        date: testDate,
        type: LendingType.lent,
        isClosed: true,
        closedDate: testClosedDate,
        profileId: 'p2',
      );

      final map = record.toMap();
      expect(map['id'], '456');
      expect(map['personName'], 'Dan');
      expect(map['amount'], 250.0);
      expect(map['reason'], 'Gift');
      expect(map['date'], testDate.toIso8601String());
      expect(map['type'], LendingType.lent.index);
      expect(map['isClosed'], true);
      expect(map['closedDate'], testClosedDate.toIso8601String());
      expect(map['profileId'], 'p2');

      final fromMap = LendingRecord.fromMap(map);
      expect(fromMap.id, record.id);
      expect(fromMap.personName, record.personName);
      expect(fromMap.amount, record.amount);
      expect(fromMap.reason, record.reason);
      expect(fromMap.date, record.date);
      expect(fromMap.type, record.type);
      expect(fromMap.isClosed, record.isClosed);
      expect(fromMap.closedDate, record.closedDate);
      expect(fromMap.profileId, record.profileId);
    });

    test('LendingRecord.fromMap handles null closedDate', () {
      final map = {
        'id': '789',
        'personName': 'Eve',
        'amount': 100.0,
        'reason': 'Ticket',
        'date': testDate.toIso8601String(),
        'type': LendingType.borrowed.index,
        'isClosed': false,
        'closedDate': null,
        'profileId': 'p3',
      };

      final record = LendingRecord.fromMap(map);
      expect(record.closedDate, isNull);
    });
  });
}
