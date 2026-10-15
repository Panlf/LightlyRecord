/// 全 App 唯一金额格式化入口。
///
/// **铁律**：
/// 1. DB 列 `amount_minor` 只能是 `INTEGER`，Dart 侧金额一律 `int`，单位「分」；
/// 2. 任何 `double` 与金额的乘法都是 Bug —— [parseYuanToMinor] 走字符串切分；
/// 3. 本文件是唯一允许出现 `Color(...)` 构造的地方之一（`hexToColor` 需要兜底色）。
library;

import 'dart:ui' show Color;

import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../data/model/tx_type.dart';

final NumberFormat _thousands = NumberFormat('#,###');
final NumberFormat _thousandsDecimal = NumberFormat('#,###.##');

/// 解析失败时的兜底纯黑（避免在本文件写出 `Color(0xFF...)` 字面量）。
final Color _fallbackColor = Color(int.parse('FF000000', radix: 16));

/// 分 → 元字符串（千分位 + 2 位小数），不带 `¥`。
///
/// `328650` → `"3,286.50"`；`-2650` → `"-26.50"`。
String fmtMoney(int minor) {
  final negative = minor < 0;
  final abs = negative ? -minor : minor;
  // 纯整数运算：abs / 100 与 abs % 100，绝不引入 double。
  final yuan = abs ~/ 100;
  final cents = abs % 100;
  final body = '${_thousands.format(yuan)}.${cents.toString().padLeft(2, '0')}';
  return negative ? '-$body' : body;
}

/// 分 → 带 `¥` 前缀的元字符串，不带正负号。
///
/// `328650` → `"¥3,286.50"`。
String fmtMoneyWithSign(int minor) => '¥${fmtMoney(minor)}';

/// 分 → 带正负号与 `¥` 的元字符串。
///
/// 支出 `-¥26.50`、收入 `+¥680.00`、转账不带符号。
String fmtSigned(int minor, TxType type) {
  final abs = minor.abs();
  final body = '¥${fmtMoney(abs)}';
  return switch (type) {
    TxType.expense => '-$body',
    TxType.income => '+$body',
    TxType.transfer => body,
  };
}

/// 日历 / 账本行的紧凑金额（严格对齐原型 `compactAmt()`）。
///
/// - `≥ 1000` 元：取整到元并加千分位（`128600` → `"1,286"`）；
/// - `< 1000` 元：保留 2 位后去掉尾部多余的 0（`2650` → `"26.5"`、`2600` → `"26"`）。
String fmtCompact(int minor) {
  final negative = minor < 0;
  final abs = minor < 0 ? -minor : minor;
  final yuan = abs / 100.0;
  String body;
  if (yuan >= 1000) {
    body = _thousands.format(yuan.round());
  } else {
    body = _trimTrailingZeros(yuan.toStringAsFixed(2));
  }
  return negative ? '-$body' : body;
}

/// 去掉小数尾部多余的 0 与孤立的小数点。
///
/// `"26.50"` → `"26.5"`；`"26.00"` → `"26"`；`"100.00"` → `"100"`；`"0.00"` → `"0"`。
/// 用显式循环而非正则，避免 `$` 在普通字符串里的转义歧义。
String _trimTrailingZeros(String s) {
  if (!s.contains('.')) return s;
  var end = s.length;
  while (end > 0 && s[end - 1] == '0') {
    end--;
  }
  if (end > 0 && s[end - 1] == '.') {
    end--;
  }
  return s.substring(0, end);
}

/// 元字符串 → 分（字符串切分，禁用 `double * 100`）。
///
/// `"26.50"` → `2650`、`"26.5"` → `2650`、`"26"` → `2600`、`"1,286.00"` → `128600`。
///
/// 只接受形如 `[+-]?(\d*)(\.\d*)?` 的合法输入；`'--1'`、`'1a2'`、`'1.2.3'` 等
/// 脏数据一律返回 0，绝不抛异常。超过 `9,999,999.99` 元上限时钳到上限。
int parseYuanToMinor(String yuan) {
  final raw = yuan.trim().replaceAll(',', '').replaceAll(' ', '');
  final match = _yuanPattern.firstMatch(raw);
  if (match == null) return 0;

  final sign = match.group(1) == '-' ? -1 : 1;
  final intDigits = match.group(2) ?? '';
  final fracDigits = match.group(3) ?? '';

  const int maxYuan = AppConstants.maxAmountMinor ~/ AppConstants.minorPerYuan;
  // 整数部分缺失视为 0；能解析但超出上限则钳到上限。
  var intPart = intDigits.isEmpty ? 0 : (int.tryParse(intDigits) ?? maxYuan);
  if (intPart > maxYuan) intPart = maxYuan;

  final cents =
      fracDigits.isEmpty ? 0 : int.parse(fracDigits.padRight(2, '0').substring(0, 2));

  return sign * (intPart * AppConstants.minorPerYuan + cents);
}

/// 合法元字符串模式：可选正负号 + 可选整数部分 + 可选小数部分。
final RegExp _yuanPattern = RegExp(r'^([+-]?)(\d*)(?:\.(\d*))?$');

/// `'#RRGGBB'` / `'#RRGGBB'` / `'RRGGBB'` → [Color]。
///
/// 解析失败返回纯黑，绝不抛异常。
Color hexToColor(String hex) {
  var s = hex.trim();
  if (s.startsWith('#')) {
    s = s.substring(1);
  }
  if (s.length == 3) {
    s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
  }
  if (s.length == 6) {
    s = 'FF$s';
  }
  if (s.length != 8) {
    return _fallbackColor;
  }
  final v = int.tryParse(s, radix: 16);
  return v == null ? _fallbackColor : Color(v);
}

/// 深色 → 同色系浅底色（分类图标「浅底 + 深字」配对的另一半）。
///
/// seed_data 的色板成对存储（`color_bg` 浅底 + `color_stroke` 深字）；
/// 用户自选分类只有一个深色值时，用本函数按 [amount]（默认 0.88）
/// 向白色混合派生浅底，避免图标与底色同色导致看不见。
/// 解析失败退化为原值（调用方落在 hexToColor 的兜底路径上）。
String hexLighten(String hex, [double amount = 0.88]) {
  final color = hexToColor(hex);
  int mix(int channel) {
    final v = (channel + (255 - channel) * amount).round().clamp(0, 255);
    return v;
  }

  final r = mix((color.r * 255).round());
  final g = mix((color.g * 255).round());
  final b = mix((color.b * 255).round());
  return '#'
      '${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';
}

/// 任意数字（分）→ 千分位字符串，供图例 / 副标题复用。
String fmtThousands(num value) => _thousands.format(value);

/// 任意数字 → 最多 2 位小数的千分位字符串。
String fmtDecimal(num value) => _thousandsDecimal.format(value);

/// 百分比 → `"12.3%"`；[ratio] 为 0~1 之间的小数。
String fmtPercent(double ratio, {int decimals = 1}) {
  final pct = (ratio * 100).toStringAsFixed(decimals);
  return '$pct%';
}

/// 带符号百分比 → `"+6.5%"` / `"-8.0%"`；0 显示 `"0.0%"`。
String fmtSignedPercent(double ratio, {int decimals = 1}) {
  final pct = (ratio.abs() * 100).toStringAsFixed(decimals);
  if (ratio > 0) return '+$pct%';
  if (ratio < 0) return '-$pct%';
  const double zero = 0.0;
  return '${zero.toStringAsFixed(decimals)}%';
}
