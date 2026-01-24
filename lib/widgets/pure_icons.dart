import 'package:flutter/material.dart';

/// A wrapper around standard Material Icons.
/// This allows for centralized management of the app's iconography.
class PureIcons {
  // --- Core Navigation ---
  static Widget home({double size = 24, Color? color}) =>
      Icon(Icons.home, size: size, color: color);
  static Widget reports({double size = 24, Color? color}) =>
      Icon(Icons.analytics, size: size, color: color);
  static Widget accounts({double size = 24, Color? color}) =>
      Icon(Icons.account_balance_wallet, size: size, color: color);
  static Widget settings({double size = 24, Color? color}) =>
      Icon(Icons.settings, size: size, color: color);
  static Widget wallet({double size = 24, Color? color}) =>
      Icon(Icons.account_balance_wallet_outlined, size: size, color: color);
  static Widget bank({double size = 24, Color? color}) =>
      Icon(Icons.account_balance, size: size, color: color);
  static Widget logout({double size = 24, Color? color}) =>
      Icon(Icons.logout, size: size, color: color);
  static Widget profiles({double size = 24, Color? color}) =>
      Icon(Icons.person_pin, size: size, color: color);
  static Widget person({double size = 24, Color? color}) =>
      Icon(Icons.person, size: size, color: color);
  static Widget category({double size = 24, Color? color}) =>
      Icon(Icons.category, size: size, color: color);
  static Widget recycleBin({double size = 24, Color? color}) =>
      Icon(Icons.delete_sweep, size: size, color: color);

  static Widget personAdd({double size = 24, Color? color}) =>
      Icon(Icons.person_add, size: size, color: color);

  // --- Icon Map for Tree Shaking ---
  // BEGIN GENERATED CODE - DO NOT EDIT MANUALLY
  // Edit tool/category_icons.txt and run "dart run tool/generate_icons.dart"
  static const Map<int, IconData> _categoryIcons = {
    0xe332: IconData(0xe332, fontFamily: 'MaterialSymbolsOutlined'), // toys
    0xea68: IconData(0xea68,
        fontFamily: 'MaterialSymbolsOutlined'), // festival/entertainment
    0xea14: IconData(0xea14, fontFamily: 'MaterialSymbolsOutlined'), // others
    0xef92: IconData(0xef92,
        fontFamily: 'MaterialSymbolsOutlined'), // stock market/investment
    0xef97: IconData(0xef97,
        fontFamily: 'MaterialSymbolsOutlined'), // groceries/vegetables
    0xef63: IconData(0xef63, fontFamily: 'MaterialSymbolsOutlined'), // rent
    0xe6ca: IconData(0xe6ca, fontFamily: 'MaterialSymbolsOutlined'), // travel
    0xe1d5: IconData(0xe1d5, fontFamily: 'MaterialSymbolsOutlined'), // health
    0xe546: IconData(0xe546, fontFamily: 'MaterialSymbolsOutlined'), // gas
    0xe8b0:
        IconData(0xe8b0, fontFamily: 'MaterialSymbolsOutlined'), // utility bill
    0xe550: IconData(0xe550, fontFamily: 'MaterialSymbolsOutlined'), // pharmacy
    0xf0ff: IconData(0xf0ff, fontFamily: 'MaterialSymbolsOutlined'), // maid
    0xeb41:
        IconData(0xeb41, fontFamily: 'MaterialSymbolsOutlined'), // care taker
    0xe869: IconData(0xe869, fontFamily: 'MaterialSymbolsOutlined'), // repairs
    0xe2a8: IconData(0xe2a8, fontFamily: 'MaterialSymbolsOutlined'), // laundry
    0xe110: IconData(0xe110, fontFamily: 'MaterialSymbolsOutlined'), // fruits
    0xe842: IconData(0xe842, fontFamily: 'MaterialSymbolsOutlined'), // meat
    0xe02c: IconData(0xe02c, fontFamily: 'MaterialSymbolsOutlined'), // movies
    0xe8b1: IconData(0xe8b1,
        fontFamily: 'MaterialSymbolsOutlined'), // Gift/Family Gift
    0xe5c7: IconData(0xe5c7, fontFamily: 'MaterialSymbolsOutlined'), // add
    0xe548: IconData(0xe548, fontFamily: 'MaterialSymbolsOutlined'), // Hospital
    0xeb6f: IconData(0xeb6f,
        fontFamily: 'MaterialSymbolsOutlined'), // Salary/Bank loan
    0xf8eb: IconData(0xf8eb,
        fontFamily: 'MaterialSymbolsOutlined'), // Property Rental
    0xf3ee: IconData(0xf3ee,
        fontFamily: 'MaterialSymbolsOutlined'), // Divestment/Dividend
    0xe2eb: IconData(0xe2eb,
        fontFamily: 'MaterialSymbolsOutlined'), // Saving Interest
    0xef9d: IconData(0xef9d, fontFamily: 'MaterialSymbolsOutlined'), // salon
    0xe80c: IconData(0xe80c, fontFamily: 'MaterialSymbolsOutlined'), // school
    0xe064: IconData(0xe064,
        fontFamily: 'MaterialSymbolsOutlined'), // subscriptions
    0xe86a: IconData(0xe86a, fontFamily: 'MaterialSymbolsOutlined'), // services
    // Updated codepoints with verified Material Symbols:
    0xe1b1: IconData(0xe1b1,
        fontFamily: 'MaterialSymbolsOutlined'), // Gadgets/Devices
    0xf19e: IconData(0xf19e,
        fontFamily: 'MaterialSymbolsOutlined'), // Clothes/Checkroom
    0xf19d: IconData(0xf19d,
        fontFamily: 'MaterialSymbolsOutlined'), // Insurance/Policy
    0xea61: IconData(0xea61,
        fontFamily: 'MaterialSymbolsOutlined'), // Cashback/Paid
    0xe57a: IconData(0xe57a,
        fontFamily: 'MaterialSymbolsOutlined'), // Snacks/Fastfood
    0xeb4c:
        IconData(0xeb4c, fontFamily: 'MaterialSymbolsOutlined'), // Beauty/Spa
    0xe56c: IconData(0xe56c,
        fontFamily: 'MaterialSymbolsOutlined'), // Food/Restaurant
    0xf1cc: IconData(0xf1cc, fontFamily: 'MaterialSymbolsOutlined'), // Shopping
  };
  // END GENERATED CODE

  static IconData categoryIconData(int code) =>
      _categoryIcons[code] ??
      const IconData(0xe5c7, fontFamily: 'MaterialSymbolsOutlined');

  static Widget categoryIcon(int code, {double size = 24, Color? color}) =>
      Icon(
        categoryIconData(code),
        size: size,
        color: color,
      );

  // --- Financial & Transactions ---
  static Widget expense({double size = 24, Color? color}) =>
      Icon(Icons.trending_down, size: size, color: color ?? Colors.red);
  static Widget income({double size = 24, Color? color}) =>
      Icon(Icons.trending_up, size: size, color: color ?? Colors.green);
  static Widget transfer({double size = 24, Color? color}) =>
      Icon(Icons.swap_horiz, size: size, color: color ?? Colors.blue);
  static Widget card({double size = 24, Color? color}) =>
      Icon(Icons.credit_card, size: size, color: color);
  static Widget contactless({double size = 24, Color? color}) =>
      Icon(Icons.contactless, size: size, color: color);
  static Widget payment({double size = 24, Color? color}) =>
      Icon(Icons.payment, size: size, color: color);
  static Widget money({double size = 24, Color? color}) =>
      Icon(Icons.attach_money, size: size, color: color);
  static Widget percent({double size = 24, Color? color}) =>
      Icon(Icons.percent, size: size, color: color);
  static Widget bill({double size = 24, Color? color}) =>
      Icon(Icons.receipt_long, size: size, color: color);
  static Widget loan({double size = 24, Color? color}) =>
      Icon(Icons.account_balance, size: size, color: color);

  // --- Actions ---
  static Widget add({double size = 24, Color? color}) =>
      Icon(Icons.add, size: size, color: color);
  static Widget addCircle({double size = 24, Color? color}) =>
      Icon(Icons.add_circle_outline, size: size, color: color);
  static Widget edit({double size = 24, Color? color}) =>
      Icon(Icons.edit, size: size, color: color);
  static Widget editOutlined({double size = 24, Color? color}) =>
      Icon(Icons.edit_outlined, size: size, color: color);
  static Widget delete({double size = 24, Color? color}) =>
      Icon(Icons.delete, size: size, color: color);
  static Widget restore({double? size, Color? color}) =>
      Icon(Icons.restore, size: size, color: color);
  static Widget deleteForever({double? size, Color? color}) =>
      Icon(Icons.delete_forever, size: size, color: color);
  static Widget deleteOutlined({double? size, Color? color}) =>
      Icon(Icons.delete_outline, size: size, color: color);
  static Widget save({double size = 24, Color? color}) =>
      Icon(Icons.save, size: size, color: color);
  static Widget close({double size = 24, Color? color}) =>
      Icon(Icons.close, size: size, color: color);
  static Widget check({double size = 24, Color? color}) =>
      Icon(Icons.check, size: size, color: color);
  static Widget checkCircle({double size = 24, Color? color}) =>
      Icon(Icons.check_circle_outline, size: size, color: color);
  static Widget sync({double size = 24, Color? color}) =>
      Icon(Icons.sync, size: size, color: color);
  static Widget download({double size = 24, Color? color}) =>
      Icon(Icons.download, size: size, color: color);
  static Widget upload({double size = 24, Color? color}) =>
      Icon(Icons.upload, size: size, color: color);
  static Widget search({double size = 24, Color? color}) =>
      Icon(Icons.search, size: size, color: color);
  static Widget filter({double size = 24, Color? color}) =>
      Icon(Icons.filter_list, size: size, color: color);
  static Widget refresh({double size = 24, Color? color}) =>
      Icon(Icons.refresh, size: size, color: color);
  static Widget selectAll({double size = 24, Color? color}) =>
      Icon(Icons.select_all, size: size, color: color);
  static Widget checklist({double? size, Color? color}) =>
      Icon(Icons.checklist, size: size, color: color);
  static Widget calculate({double? size, Color? color}) =>
      Icon(Icons.calculate, size: size, color: color);
  static Widget switchAccount({double? size, Color? color}) =>
      Icon(Icons.switch_account, size: size, color: color);
  static Widget listExtended({double? size, Color? color}) =>
      Icon(Icons.format_align_justify, size: size, color: color);
  static Widget listCompact({double size = 24, Color? color}) =>
      Icon(Icons.format_align_center, size: size, color: color);

  // --- Security & Utility ---
  static Widget lock({double size = 24, Color? color}) =>
      Icon(Icons.lock, size: size, color: color);
  static Widget lockOutline({double size = 24, Color? color}) =>
      Icon(Icons.lock_outline, size: size, color: color);
  static Widget lockPerson({double size = 24, Color? color}) =>
      Icon(Icons.lock_person, size: size, color: color);
  static Widget security({double size = 24, Color? color}) =>
      Icon(Icons.security, size: size, color: color);
  static Widget key({double size = 24, Color? color}) =>
      Icon(Icons.key, size: size, color: color);
  static Widget pin({double size = 24, Color? color}) =>
      Icon(Icons.pin, size: size, color: color);
  static Widget email({double size = 24, Color? color}) =>
      Icon(Icons.email, size: size, color: color);
  static Widget timer({double size = 24, Color? color}) =>
      Icon(Icons.timer, size: size, color: color);
  static Widget calendar({double size = 24, Color? color}) =>
      Icon(Icons.calendar_today, size: size, color: color);
  static Widget calendarMonth({double size = 24, Color? color}) =>
      Icon(Icons.calendar_month, size: size, color: color);
  static Widget cloudOff({double size = 24, Color? color}) =>
      Icon(Icons.cloud_off, size: size, color: color);
  static Widget warning({double size = 24, Color? color}) =>
      Icon(Icons.warning, size: size, color: color);
  static Widget info({double size = 24, Color? color}) =>
      Icon(Icons.info_outline, size: size, color: color);
  static Widget backspace({double size = 24, Color? color}) =>
      Icon(Icons.backspace, size: size, color: color);
  static Widget chart({double size = 24, Color? color}) =>
      Icon(Icons.show_chart, size: size, color: color);
  static Widget repeat({double size = 24, Color? color}) =>
      Icon(Icons.repeat, size: size, color: color);
  static Widget copy({double size = 24, Color? color}) =>
      Icon(Icons.copy_all, size: size, color: color);
  static Widget pieChart({double size = 24, Color? color}) =>
      Icon(Icons.pie_chart, size: size, color: color);

  static Widget notifications({double size = 24, Color? color}) =>
      Icon(Icons.notifications_none, size: size, color: color);

  static Widget ledger({double size = 24, Color? color}) =>
      Icon(Icons.list_alt, size: size, color: color);

  static Widget icon(IconData data, {double? size, Color? color}) =>
      Icon(data, size: size, color: color);

  // --- Logo ---
  static Widget logo({double size = 120}) => Icon(
        Icons.account_balance_wallet,
        size: size,
        color: const Color(0xFF6C63FF),
      );
}
