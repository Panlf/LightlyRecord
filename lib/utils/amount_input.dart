import 'package:intl/intl.dart';

import '../core/format.dart';

/// 金额键盘字符串状态机（R03，逐位对齐架构文档 §7.6 与原型 `keyIn()`）。
///
/// 内部状态 `_raw` 是**字符串**而非 `double`，从根上避免浮点误差
/// （`0.1 + 0.2 != 0.3` 一类问题在记账场景是事故级的）。
///
/// 规则：
/// 1. 初始 `'0.00'`；
/// 2. `.` 只在无小数点时追加；
/// 3. 数字键在 `'0.00'` / `'0'` 开头时**直接替换**（不拼成 `'01'`）；
/// 4. 小数满 2 位忽略继续输入；
/// 5. 整数上限 7 位（`9,999,999.99` 元）；
/// 6. 退格后若为空或 `'0'` 则回 `'0.00'`；无小数点则补 `.00`；
/// 7. `'00'` 键按字符逐个处理，与连按两次 `'0'` **完全等价**。
///
/// 第 7 条是对规格的刻意加固：原型 `amt += '00'` 在已有 1 位小数时
/// 会拼出 3 位小数（如 `'12.5'` → `'12.500'`），显示层会出现
/// 「12.500」这种脏值。逐字符处理后 `'12.5'` + `'00'` → `'12.50'`，
/// 单字符按键的行为与原型逐位一致。
class AmountInput {
  /// 初始 / 复位值。
  static const String initial = '0.00';

  /// 整数部分最多几位。
  static const int maxIntegerDigits = 7;

  /// 小数部分最多几位。
  static const int maxFractionDigits = 2;

  final NumberFormat _thousands = NumberFormat('#,###');

  String _raw = initial;

  /// 当前原始串（调试 / 单测断言用）。
  String get raw => _raw;

  /// 展示串：整数部分千分位，保留已输入的小数位。
  ///
  /// `'1286.5'` → `'1,286.5'`；`'0.00'` → `'0.00'`；`'12'` → `'12'`。
  String get display {
    final dot = _raw.indexOf('.');
    if (dot < 0) {
      return _thousands.format(int.parse(_raw.isEmpty ? '0' : _raw));
    }
    final intPart = _raw.substring(0, dot);
    final frac = _raw.substring(dot + 1);
    final head = _thousands.format(int.parse(intPart.isEmpty ? '0' : intPart));
    return frac.isEmpty ? '$head.' : '$head.$frac';
  }

  /// 当前金额（分）。`'0.00'` → `0`；`'12.5'` → `1250`。
  ///
  /// 走 [parseYuanToMinor] 字符串切分，绝不 `double * 100`。
  int get minor => parseYuanToMinor(_raw);

  /// 是否为 0（未输入有效金额）。
  bool get isZero => minor <= 0;

  /// 输入一个键：`'0'`~`'9'` / `'00'` / `'.'`。
  ///
  /// 其他字符串按「逐字符数字」处理；达到上限时静默停止（不抛异常）。
  void input(String key) {
    if (key == '.') {
      if (!_raw.contains('.')) {
        _raw = '$_raw.';
      }
      return;
    }
    // 逐字符处理，使 '00' 与两次 '0' 等价，也天然阻止 3 位小数。
    for (final ch in key.split('')) {
      if (!_appendDigit(ch)) return;
    }
  }

  /// 退格一位。
  void backspace() {
    if (_raw.length <= 1) {
      _raw = initial;
      return;
    }
    _raw = _raw.substring(0, _raw.length - 1);
    if (_raw.isEmpty || _raw == '0') {
      _raw = initial;
    }
    if (!_raw.contains('.')) {
      _raw = '$_raw.00';
    }
  }

  /// 清空回初始值。
  void clear() => _raw = initial;

  /// 直接设置为某个「分」值（编辑已有交易时回显用）。
  ///
  /// 用字符串构造而非 `value / 100`，避免浮点。
  void setMinor(int value) {
    final negative = value < 0;
    final abs = negative ? -value : value;
    final yuan = abs ~/ 100;
    final cents = abs % 100;
    final body = '$yuan.${cents.toString().padLeft(2, '0')}';
    _raw = negative ? '-$body' : body;
  }

  /// 追加一个数字字符；返回 `false` 表示已达上限、该字符被丢弃。
  bool _appendDigit(String ch) {
    if (ch.isEmpty || !RegExp('[0-9]').hasMatch(ch)) {
      return false;
    }
    // 规则 3：领头 0 直接替换
    if (_raw == initial || _raw == '0') {
      _raw = ch;
      return true;
    }
    final dot = _raw.indexOf('.');
    if (dot >= 0) {
      // 规则 4：小数满 2 位
      if (_raw.length - dot - 1 >= maxFractionDigits) {
        return false;
      }
      _raw = '$_raw$ch';
      return true;
    }
    // 规则 5：整数上限 7 位
    if (_raw.length >= maxIntegerDigits) {
      return false;
    }
    _raw = '$_raw$ch';
    return true;
  }

  @override
  String toString() => 'AmountInput($_raw → $minor 分)';
}
