/// 日期处理扩展（铁律：`tx_date` 一律本地 `'YYYY-MM-DD'` 字符串，无时区）。
///
/// 所有本地日期与 `DateTime` 的互转**必须**走本文件，禁止在业务代码里手写
/// `'$y-$m-$d'` 拼接或 `DateTime.parse`。
library;

import 'package:flutter/material.dart' show TimeOfDay;

const List<String> _weekdayCn = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// `DateTime` → `'YYYY-MM-DD'`（本地日期，补零）。
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `'YYYY-MM-DD'` → 本地 `DateTime(y, m, d)`（时间归零）。
///
/// 非法输入退化为当天，绝不抛异常。
/// 注意：日号会按**当月实际天数**校验（`2026-02-30` 判非法），
/// 否则 `DateTime(2026, 2, 30)` 会静默溢出成 3 月 2 日。
DateTime parseYmd(String s) {
  final parts = s.split('-');
  if (parts.length != 3) return startOfDay(DateTime.now());
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null || m < 1 || m > 12 || d < 1) {
    return startOfDay(DateTime.now());
  }
  if (d > daysInMonth(y, m)) {
    return startOfDay(DateTime.now());
  }
  return DateTime(y, m, d);
}

/// `TimeOfDay` → `'HH:mm'`（24h，补零）。
String hm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 当前本地时间 → `'HH:mm'`。
String hmNow() {
  final n = DateTime.now();
  return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
}

/// 今天（本地，时间归零）。
DateTime today() => startOfDay(DateTime.now());

/// 时间归零到当天 00:00。
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// 当月第一天。
DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

/// 当月最后一天。
DateTime monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);

/// 本周一。
DateTime weekStart(DateTime d) {
  final s = startOfDay(d);
  return s.subtract(Duration(days: s.weekday - 1));
}

/// 本周日。
DateTime weekEnd(DateTime d) {
  final s = weekStart(d);
  return DateTime(s.year, s.month, s.day + 6);
}

/// ±N 个月；日号溢出时取目标月最后一天（如 1/31 + 1 月 → 2/28）。
DateTime addMonths(DateTime d, int n) {
  final total = d.year * 12 + (d.month - 1) + n;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final last = daysInMonth(y, m);
  return DateTime(y, m, d.day > last ? last : d.day);
}

/// ±N 年；2/29 在非闰年退化为 2/28。
DateTime addYears(DateTime d, int n) {
  final y = d.year + n;
  if (d.month == 2 && d.day == 29 && !isLeapYear(y)) {
    return DateTime(y, 2, 28);
  }
  return DateTime(y, d.month, d.day);
}

/// ±N 天。
DateTime addDays(DateTime d, int n) {
  final s = startOfDay(d);
  return DateTime(s.year, s.month, s.day + n);
}

/// `'周一'` ~ `'周日'`。
String weekdayCn(DateTime d) => _weekdayCn[d.weekday - 1];

/// 该月天数（28 / 29 / 30 / 31）。
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// 是否闰年。
bool isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// 两个本地日期的自然日跨度（`b - a`，含符号）。
int daysBetween(DateTime a, DateTime b) =>
    startOfDay(b).difference(startOfDay(a)).inDays;

/// 月初第一天 → 月末最后一天的闭区间字符串对，供 SQL `BETWEEN` 使用。
(String, String) monthRange(DateTime d) {
  final s = monthStart(d);
  final e = monthEnd(d);
  return (ymd(s), ymd(e));
}

/// 本周一 → 本周日的闭区间字符串对。
(String, String) weekRange(DateTime d) {
  final s = weekStart(d);
  final e = weekEnd(d);
  return (ymd(s), ymd(e));
}

/// 当天 00:00 → 当天 23:59 的闭区间字符串对（实为同一天）。
(String, String) dayRange(DateTime d) {
  final s = ymd(d);
  return (s, s);
}

/// `'2026-10'` 形式的年月标签。
String ymLabel(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// `'2026年10月'` 形式的中文年月标签。
String ymLabelCn(DateTime d) => '${d.year}年${d.month}月';

/// `'10月14日'` 形式的中文月日标签。
String mdLabelCn(DateTime d) => '${d.month}月${d.day}日';

/// 是否同一天（本地日期口径）。
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 日期选择器可选的上下界（避免用户选到 1970 / 2100 年）。
final DateTime kDatePickerFirst = DateTime(2000, 1, 1);
final DateTime kDatePickerLast = DateTime(2100, 12, 31);

/// `DateTime` 的便捷扩展（内部实现复用上面的顶层函数）。
extension AppDateExt on DateTime {
  /// → `'YYYY-MM-DD'`。
  String get ymdStr => ymd(this);

  /// 时间归零。
  DateTime get dayStart => startOfDay(this);

  /// 当月第一天。
  DateTime get monthStartDate => monthStart(this);

  /// 当月最后一天。
  DateTime get monthEndDate => monthEnd(this);

  /// 本周一。
  DateTime get weekStartDate => weekStart(this);

  /// 本周日。
  DateTime get weekEndDate => weekEnd(this);

  /// `'周一'` ~ `'周日'`。
  String get weekdayCnStr => weekdayCn(this);
}
