import 'package:flutter_test/flutter_test.dart';

import 'package:lightly_record/core/date_ext.dart';

/// T01 日期工具验收用例（架构文档 §7.2）。
void main() {
  group('ymd / parseYmd', () {
    test('互转', () {
      expect(ymd(DateTime(2026, 10, 14)), '2026-10-14');
      expect(ymd(DateTime(2026, 1, 2)), '2026-01-02');
      expect(parseYmd('2026-10-14'), DateTime(2026, 10, 14));
      expect(ymd(parseYmd('2026-10-14')), '2026-10-14');
    });

    test('非法输入退化为今天，不抛异常', () {
      expect(ymd(parseYmd('')), ymd(DateTime.now()));
      expect(ymd(parseYmd('abc')), ymd(DateTime.now()));
      expect(ymd(parseYmd('2026-13-40')), ymd(DateTime.now()));
    });
  });

  group('monthStart / monthEnd / daysInMonth', () {
    test('月首月末', () {
      expect(monthStart(DateTime(2026, 10, 14)), DateTime(2026, 10, 1));
      expect(monthEnd(DateTime(2026, 10, 14)), DateTime(2026, 10, 31));
      expect(monthEnd(DateTime(2026, 2, 10)), DateTime(2026, 2, 28));
      expect(monthEnd(DateTime(2024, 2, 10)), DateTime(2024, 2, 29));
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2026, 4), 30);
    });
  });

  group('weekStart / weekEnd', () {
    test('周一 ~ 周日', () {
      // 2026-10-14 是周三
      final wed = DateTime(2026, 10, 14);
      expect(weekStart(wed), DateTime(2026, 10, 12));
      expect(weekEnd(wed), DateTime(2026, 10, 18));

      final mon = DateTime(2026, 10, 12);
      expect(weekStart(mon), DateTime(2026, 10, 12));
      expect(weekEnd(mon), DateTime(2026, 10, 18));

      final sun = DateTime(2026, 10, 18);
      expect(weekStart(sun), DateTime(2026, 10, 12));
    });
  });

  group('addMonths / addYears', () {
    test('日溢出取当月最后一天', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 3, 31), -1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 10, 14), 2), DateTime(2026, 12, 14));
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
      expect(addMonths(DateTime(2026, 1, 15), -1), DateTime(2025, 12, 15));
    });

    test('闰年 2/29 退化', () {
      expect(addYears(DateTime(2024, 2, 29), 1), DateTime(2025, 2, 28));
      expect(addYears(DateTime(2024, 2, 29), 4), DateTime(2028, 2, 29));
      expect(isLeapYear(2024), true);
      expect(isLeapYear(2026), false);
      expect(isLeapYear(2000), true);
      expect(isLeapYear(1900), false);
    });
  });

  group('weekdayCn / 区间', () {
    test('中文星期', () {
      expect(weekdayCn(DateTime(2026, 10, 12)), '周一');
      expect(weekdayCn(DateTime(2026, 10, 18)), '周日');
    });

    test('月 / 周 / 日区间字符串对', () {
      expect(monthRange(DateTime(2026, 10, 14)), ('2026-10-01', '2026-10-31'));
      expect(weekRange(DateTime(2026, 10, 14)), ('2026-10-12', '2026-10-18'));
      expect(dayRange(DateTime(2026, 10, 14)), ('2026-10-14', '2026-10-14'));
    });
  });

  group('labels / daysBetween', () {
    test('标签与跨度', () {
      expect(ymLabel(DateTime(2026, 10, 14)), '2026-10');
      expect(ymLabelCn(DateTime(2026, 10, 14)), '2026年10月');
      expect(mdLabelCn(DateTime(2026, 10, 14)), '10月14日');
      expect(daysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 15)), 14);
      expect(isSameDay(DateTime(2026, 10, 14, 8), DateTime(2026, 10, 14, 23)),
          true);
    });
  });
}
