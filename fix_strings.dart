import 'dart:io';

Future<void> replaceString(String filePath, String duplicateString,
    String constName, String classContext) async {
  final file = File(filePath);
  if (!file.existsSync()) return;

  var content = await file.readAsString();
  if (content.contains("const $constName = '$duplicateString';")) {
    return; // already added
  }

  // replace all "'$duplicateString'"
  content = content.replaceAll("'$duplicateString'", constName);
  content = content.replaceAll('"$duplicateString"', constName);

  // prepend const declaration inside class context or at top level
  content = "const $constName = '$duplicateString';\n$content";

  await file.writeAsString(content);
}

void main() async {
  await replaceString('lib/screens/lending/lending_dashboard_screen.dart',
      'dd MMM yyyy', 'dateFormatDdMmmYyyy', '');
  await replaceString('lib/screens/taxes/tax_details_screen.dart',
      'Select Months', 'selectMonthsText', '');
  await replaceString('lib/services/cloud_sync_service.dart',
      'Firebase not initialized', 'errFirebaseNotInit', '');
  await replaceString('lib/screens/taxes/tax_details_screen.dart',
      'Employer Paid', 'employerPaidText', '');
  await replaceString(
      'lib/screens/dashboard_screen.dart', '••••••', 'hiddenTextChars', '');
  await replaceString('lib/screens/recurring_manager_screen.dart',
      ' (Adj. for Holidays)', 'adjForHolidaysText', '');
  await replaceString('lib/widgets/auth_wrapper.dart', 'Continue Offline',
      'continueOfflineText', '');
  await replaceString('lib/screens/add_loan_screen.dart', 'yyyy-MM-dd',
      'dateFormatYyyyMmDd', '');
  await replaceString('lib/screens/reminders_screen.dart', 'MMM dd, yyyy',
      'dateFormatMmmDdYyyy', '');
  await replaceString(
      'lib/screens/reminders_screen.dart', 'PAY NOW', 'payNowText', '');
  await replaceString(
      'lib/screens/reminders_screen.dart', 'MMM dd', 'dateFormatMmmDd', '');
  await replaceString(
      'lib/screens/reports_screen.dart', 'MMMM yyyy', 'dateFormatMmmmYyyy', '');
  await replaceString('lib/services/cloud_sync_service.dart',
      'User not logged in', 'errUserNotLoggedIn', '');
}
