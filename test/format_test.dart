import 'package:flutter_test/flutter_test.dart';

import 'package:lightly_record/core/format.dart';
import 'package:lightly_record/data/model/tx_type.dart';

/// T01 金额格式化 / 解析验收用例（架构文档 §7.1）。
void main() {
  group('parseYuanToMinor', () {
    test('验收用例', () {
      expect(parseYuanToMinor('26.50'), 2650);
      expect(parseYuanToMinor('26.5'), 2650);
      expect(parseYuanToMinor('26'), 2600);
      expect(parseYuanToMinor('0'), 0);
      expect(parseYuanToMinor('0.00'), 0);
      expect(parseYuanToMinor('1286.00'), 128600);
      expect(parseYuanToMinor('12000.00'), 1200000);
      expect(parseYuanToMinor('1,286.00'), 128600);
      expect(parseYuanToMinor(''), 0);
      expect(parseYuanToMinor('  '), 0);
    });

    test('小数位补零与截断', () {
      expect(parseYuanToMinor('26.5'), 2650);
      expect(parseYuanToMinor('26.05'), 2605);
      expect(parseYuanToMinor('26.509'), 2650); // 超过 2 位截断
      expect(parseYuanToMinor('.5'), 50);
      expect(parseYuanToMinor('0.5'), 50);
    });

    test('容错：脏数据一律返回 0，不抛异常', () {
      // 只接受 `-?(\d*)(\.\d*)?` 形态；任何脏数据 → 0
      expect(parseYuanToMinor('abc'), 0);
      expect(parseYuanToMinor('12a'), 0);
      expect(parseYuanToMinor('12a.3b'), 0);
      expect(parseYuanToMinor('--1'), 0);
      expect(parseYuanToMinor('1.2.3'), 0);
      expect(parseYuanToMinor('-'), 0);
      expect(parseYuanToMinor('.'), 0);
      expect(parseYuanToMinor('..'), 0);
      expect(parseYuanToMinor('  '), 0);
    });

    test('负号与超大值', () {
      expect(parseYuanToMinor('-26.50'), -2650);
      expect(parseYuanToMinor('+26.50'), 2650);
      // 超出 9,999,999.99 元上限时整数部分钳到 9,999,999 元
      expect(parseYuanToMinor('9999999999999'), 999999900);
      expect(parseYuanToMinor('9999999.99'), 999999999);
      expect(parseYuanToMinor('-9999999.99'), -999999999);
    });
  });

  group('fmtMoney', () {
    test('验收用例', () {
      expect(fmtMoney(328650), '3,286.50');
      expect(fmtMoney(2650), '26.50');
      expect(fmtMoney(0), '0.00');
      expect(fmtMoney(5), '0.05');
      expect(fmtMoney(100), '1.00');
      expect(fmtMoney(-2650), '-26.50');
      expect(fmtMoney(999999999), '9,999,999.99');
    });
  });

  group('fmtCompact', () {
    test('验收用例（严格对齐原型 compactAmt）', () {
      expect(fmtCompact(2650), '26.5');
      expect(fmtCompact(128600), '1,286');
      expect(fmtCompact(2600), '26');
      expect(fmtCompact(0), '0');
      expect(fmtCompact(50), '0.5');
      expect(fmtCompact(100), '1');
      expect(fmtCompact(999900), '9,999');
      expect(fmtCompact(1000000), '10,000');
    });
  });

  group('fmtSigned / fmtMoneyWithSign', () {
    test('带符号', () {
      expect(fmtSigned(2650, TxType.expense), '-¥26.50');
      expect(fmtSigned(68000, TxType.income), '+¥680.00');
      expect(fmtSigned(2650, TxType.transfer), '¥26.50');
      expect(fmtMoneyWithSign(328650), '¥3,286.50');
    });
  });

  group('fmtPercent / fmtSignedPercent', () {
    test('百分比', () {
      expect(fmtPercent(0.123), '12.3%');
      expect(fmtSignedPercent(0.065), '+6.5%');
      expect(fmtSignedPercent(-0.08), '-8.0%');
      expect(fmtSignedPercent(0), '0.0%');
    });
  });
}
