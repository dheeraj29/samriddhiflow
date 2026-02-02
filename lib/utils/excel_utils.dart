import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/loan.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/profile.dart';

class ExcelUtils {
  static String getCellValue(Data? cell) {
    if (cell == null || cell.value == null) return "";
    return cell.value.toString().trim();
  }

  static double getDoubleValue(Data? cell) {
    final val = getCellValue(cell);
    return double.tryParse(val.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }

  static DateTime? getDateTimeValue(Data? cell) {
    final val = getCellValue(cell);
    if (val.isEmpty) return null;
    try {
      return DateTime.parse(val);
    } catch (_) {
      try {
        return DateFormat("yyyy-MM-dd HH:mm:ss").parse(val);
      } catch (_) {
        return null;
      }
    }
  }

  static int findColumn(List<Data?> headerRow, List<String> possibleNames) {
    // Pass 1: Exact Match (High Priority)
    for (var name in possibleNames) {
      final target = _normalize(name);
      for (int i = 0; i < headerRow.length; i++) {
        final cell = headerRow[i];
        if (cell == null) continue;
        final header = _normalize(getCellValue(cell));
        if (header == target) return i;
      }
    }

    // Pass 2: Partial Match (Fallback)
    for (var name in possibleNames) {
      final target = _normalize(name);
      for (int i = 0; i < headerRow.length; i++) {
        final cell = headerRow[i];
        if (cell == null) continue;
        final header = _normalize(getCellValue(cell));
        if (header.contains(target) || target.contains(header)) {
          // Avoid creating false positives with very short strings like "id" matching "valid"
          if (header.length > 2 || target == header) return i;
        }
      }
    }
    return -1;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
  }

  static List<String> profileToRow(Profile p) => [p.id, p.name];

  static List<String> accountToRow(Account a) =>
      [a.id, a.name, a.type.name, a.balance.toString(), a.profileId ?? ""];

  static List<String> loanToRow(Loan l) => [
        l.id,
        l.name,
        l.type.name,
        l.totalPrincipal.toString(),
        l.remainingPrincipal.toString(),
        l.tenureMonths.toString(),
        l.tenureMonths.toString(),
        l.interestRate.toString(),
        l.startDate.toIso8601String(),
        l.profileId ?? ""
      ];

  static List<String> categoryToRow(Category c) => [
        c.id,
        c.name,
        c.usage.name,
        c.tag.name,
        c.iconCode.toString(),
        c.profileId ?? ""
      ];

  static List<String> transactionToRow(Transaction t) => [
        t.id,
        t.title,
        t.amount.toString(),
        t.date.toIso8601String(),
        t.type.name,
        t.category,
        t.accountId ?? "",
        t.toAccountId ?? "",
        t.profileId ?? ""
      ];
}
