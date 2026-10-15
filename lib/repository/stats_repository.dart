import '../core/constants.dart';
import '../core/date_ext.dart';
import '../core/format.dart';
import '../data/dao/book_dao.dart';
import '../data/dao/budget_dao.dart';
import '../data/dao/txn_dao.dart';
import '../data/model/txn.dart';
import '../data/model/tx_type.dart';

/// 图表周期。
enum Period {
  /// 周（周一 ~ 周日）。
  week('week', '本周'),

  /// 月（本月 1 号 ~ 月末）。
  month('month', '本月'),

  /// 年（今年 1/1 ~ 12/31）。
  year('year', '本年');

  /// 入库 / 序列化用的短码。
  final String code;

  /// 中文标签。
  final String label;

  const Period(this.code, this.label);

  /// 短码 → 枚举；未知值退化为 [Period.month]。
  static Period fromCode(String code) =>
      values.firstWhere((e) => e.code == code, orElse: () => Period.month);
}

/// 连续打卡信息。
class StreakInfo {
  /// 连续记账天数。
  final int streakDays;

  /// 首次记账日期 `'YYYY-MM-DD'`（无记录为 `null`）。
  final String? firstDate;

  /// 有交易的日期集合（升序）。
  final List<String> dates;

  const StreakInfo({
    required this.streakDays,
    this.firstDate,
    this.dates = const [],
  });
}

/// 环形图一个分段。
class CategorySlice {
  /// 分类 id。
  final int categoryId;

  /// 分类名。
  final String name;

  /// 分段色 `'#RRGGBB'`。
  final String colorHex;

  /// 金额（分）。
  final int amountMinor;

  /// 占比 0~1（同组之和为 1）。
  final double ratio;

  const CategorySlice({
    required this.categoryId,
    required this.name,
    required this.colorHex,
    required this.amountMinor,
    required this.ratio,
  });
}

/// 柱状图一根柱子。
class BarItem {
  /// 底部标签，如 `'10月'` / `'周一'` / `'2026'`。
  final String label;

  /// 金额（分）。
  final int amountMinor;

  /// 是否高亮（当前所在周期）。
  final bool hot;

  const BarItem({
    required this.label,
    required this.amountMinor,
    required this.hot,
  });
}

/// 同期对比一项。
class CompareItem {
  /// 涨跌幅，-1 ~ +∞（0.05 = 涨 5%）。
  final double ratio;

  /// 基期说明，如 `'vs 上月 ¥3,735.00'`。
  final String baseLabel;

  /// 是否为「好消息」（支出降 = 好，收入涨 = 好）。
  final bool good;

  const CompareItem({
    required this.ratio,
    required this.baseLabel,
    required this.good,
  });
}

/// 结余卡数据。
class BalanceCard {
  /// 标题，如 `'本月结余'`。
  final String title;

  /// 收入合计（分）。
  final int income;

  /// 支出合计（分）。
  final int expense;

  /// 结余（分，可负）。
  final int balance;

  /// 结余率 = 结余 / 收入；收入为 0 时为 `null`（UI 显示「—」）。
  final double? rate;

  const BalanceCard({
    required this.title,
    required this.income,
    required this.expense,
    required this.balance,
    required this.rate,
  });
}

/// 预算状态卡。
class BudgetStatus {
  /// 每月预算（分）。
  final int monthlyMinor;

  /// 已用（分，跨全部账本本月支出合计）。
  final int usedMinor;

  /// 剩余（分，可为负）。
  final int remainMinor;

  /// 已用百分比，可 > 1。
  final double usedPct;

  /// 是否超支。
  final bool over;

  const BudgetStatus({
    required this.monthlyMinor,
    required this.usedMinor,
    required this.remainMinor,
    required this.usedPct,
    required this.over,
  });
}

/// 今日页全部指标（本账本口径）。
class HomeStats {
  /// 本月支出（分）。
  final int monthExpense;

  /// 本月收入（分）。
  final int monthIncome;

  /// 本月结余（分，可负）。
  final int monthBalance;

  /// 结余率；收入为 0 时为 `null`。
  final double? balanceRate;

  /// 较上月同期涨跌幅；无基期为 `null`。
  final double? momRatio;

  /// 本月日均支出（分）。
  final int dailyAvgExpense;

  /// 今日支出（分）。
  final int todayExpense;

  /// 今日笔数。
  final int todayCount;

  /// 今日明细（按时间升序）。
  final List<Txn> todayTxns;

  /// 预算状态；未启用为 `null`。
  final BudgetStatus? budget;

  /// 当前账本名。
  final String bookName;

  /// 本账本**历史是否记过账**（全时段口径，供首页区分
  /// 「全新用户」与「本月恰好没记」；不是本月口径）。
  final bool hasAnyTxn;

  const HomeStats({
    required this.monthExpense,
    required this.monthIncome,
    required this.monthBalance,
    required this.balanceRate,
    required this.momRatio,
    required this.dailyAvgExpense,
    required this.todayExpense,
    required this.todayCount,
    required this.todayTxns,
    required this.budget,
    required this.bookName,
    required this.hasAnyTxn,
  });
}

/// 图表页四维数据（本账本口径）。
class ChartBundle {
  /// 环形图分段（降序，已合并「其他」）。
  final List<CategorySlice> slices;

  /// 中心总额（分）。
  final int totalMinor;

  /// 中心标签，如 `'本月支出'`。
  final String centerLabel;

  /// 柱状图（含 label / 值 / 是否高亮）。
  final List<BarItem> bars;

  /// 柱状图标题，如 `'近6个月支出'`。
  final String barTitle;

  /// 同比；无基期为 `null`。
  final CompareItem? yoy;

  /// 环比 / 半年环比；无基期为 `null`。
  final CompareItem? mom;

  /// 环比标签：`'环比'` 或 `'半年环比'`。
  final String momLabel;

  /// 结余卡。
  final BalanceCard balance;

  /// 右上角只读范围 chip 文案。
  final String rangeLabel;

  const ChartBundle({
    required this.slices,
    required this.totalMinor,
    required this.centerLabel,
    required this.bars,
    required this.barTitle,
    required this.yoy,
    required this.mom,
    required this.momLabel,
    required this.balance,
    required this.rangeLabel,
  });
}

/// 日历一个格子。
class DayCell {
  /// 日期（本地，时间归零）。
  final DateTime date;

  /// 是否属于当前月份（false = 首尾补位的空白格）。
  final bool inMonth;

  /// 当日支出（分）。
  final int expense;

  /// 当日收入（分）。
  final int income;

  /// 当日支出占当月最大单日支出的比例（0~1），纯收入日 / 无记录日为 0。
  ///
  /// **这是原始占比，不是最终底色透明度**：最终底色由 UI 结合主题 Token
  /// `AppColors.heatBase / heatSpan` 计算（`heatBase + heatSpan × ratio`，
  /// 浅色 `.10/.50`、深色 `.16/.45`），金额文字是否转纯白同样在 UI 侧判定
  /// （最终 alpha ≥ `.45` 时转白）—— base / span 属主题层概念，仓库层算不出来。
  final double heatAlpha;

  /// 是否今天。
  final bool isToday;

  /// 是否选中。
  final bool isSelected;

  const DayCell({
    required this.date,
    required this.inMonth,
    required this.expense,
    required this.income,
    required this.heatAlpha,
    required this.isToday,
    required this.isSelected,
  });
}

/// 日历选中日明细。
class DayDetail {
  /// 日期 `'YYYY-MM-DD'`。
  final String date;

  /// 当日支出（分）。
  final int expense;

  /// 当日收入（分）。
  final int income;

  /// 当日明细（按时间升序）。
  final List<Txn> txns;

  const DayDetail({
    required this.date,
    required this.expense,
    required this.income,
    required this.txns,
  });
}

/// 日历某月数据（本账本口径）。
class CalendarMonth {
  /// 年。
  final int year;

  /// 月。
  final int month;

  /// 格子（含首尾空白格，共 42 个）。
  final List<DayCell> cells;

  /// 当月最大单日支出（热度基准，分）。
  final int maxDayExpense;

  /// 选中日汇总与明细。
  final DayDetail selectedDay;

  const CalendarMonth({
    required this.year,
    required this.month,
    required this.cells,
    required this.maxDayExpense,
    required this.selectedDay,
  });
}

/// 账本统计卡（本账本口径）。
class BookStats {
  /// 笔数。
  final int count;

  /// 累计支出（分）。
  final int totalExpense;

  /// 连续打卡天数。
  final int streakDays;

  const BookStats({
    required this.count,
    required this.totalExpense,
    required this.streakDays,
  });
}

/// 我的页统计（全局口径，跨全部账本）。
class GlobalStats {
  /// 全库交易总笔数。
  final int totalCount;

  /// 账本数。
  final int bookCount;

  /// 连续打卡天数（全局）。
  final int streakDays;

  /// 坚持天数（首次记账日 → 今天，含首日）。
  final int persistDays;

  const GlobalStats({
    required this.totalCount,
    required this.bookCount,
    required this.streakDays,
    required this.persistDays,
  });
}

/// ★ 全部派生指标唯一定义处（口径见架构文档 §5.3）。
///
/// **本文件是 UI 层唯一允许获取统计数字的入口**：页面 / Controller 不得自行
/// 写 SQL 或对 `amount_minor` 做加减，必须调用这里的方法，以保证 6 个页面
/// 口径完全一致。
abstract class StatsRepository {
  /// 今日页全部指标（本账本口径）。
  Future<HomeStats> homeStats(int bookId, DateTime today);

  /// 图表页四维数据（本账本口径）。
  Future<ChartBundle> chartBundle(
    int bookId,
    TxType mode,
    Period period,
    DateTime today,
  );

  /// 日历某月数据（本账本口径）。
  ///
  /// [selected] 为调用方指定的选中日；传 `null` 或不在本年本月时退化为
  /// 「今天在本月则今天，否则本月 1 号」。
  Future<CalendarMonth> calendarMonth(
    int bookId,
    int year,
    int month,
    DateTime today, {
    DateTime? selected,
  });

  /// 账本统计卡（本账本口径）。
  Future<BookStats> bookStats(int bookId, DateTime today);

  /// 我的页统计（全局口径）。
  Future<GlobalStats> globalStats(DateTime today);
}

/// 基于 DAO 的实现。
///
/// 依赖在构造函数里一次性注入；除统计口径外不承载任何业务规则
/// （写操作一律走 `TxnRepository` / `BookRepository` 等）。
class StatsRepositoryImpl implements StatsRepository {
  /// 注入依赖。
  const StatsRepositoryImpl({
    required TxnDao txnDao,
    required BudgetDao budgetDao,
    required BookDao bookDao,
  })  : _txnDao = txnDao,
        _budgetDao = budgetDao,
        _bookDao = bookDao;

  final TxnDao _txnDao;
  final BudgetDao _budgetDao;
  final BookDao _bookDao;

  // ================================================================ 今日页

  @override
  Future<HomeStats> homeStats(int bookId, DateTime today) async {
    final t = startOfDay(today);
    final (mFrom, mTo) = monthRange(t);

    final monthExpense =
        await _txnDao.sumByRange(bookId, mFrom, mTo, TxType.expense);
    final monthIncome =
        await _txnDao.sumByRange(bookId, mFrom, mTo, TxType.income);
    final monthBalance = monthIncome - monthExpense;

    // 结余率：收入为 0 → null（UI 显示「—」），禁止除零。
    final balanceRate =
        monthIncome > 0 ? monthBalance / monthIncome : null;

    // 较上月同期：本月 1 号~今天 vs 上月 1 号~上月同日。
    // 上月天数不足时钳到上月末（如今天 3/31 → 上月 2/28）。
    final lastMonth = addMonths(t, -1);
    final lastMonthSameDay = DateTime(
      lastMonth.year,
      lastMonth.month,
      t.day > daysInMonth(lastMonth.year, lastMonth.month)
          ? daysInMonth(lastMonth.year, lastMonth.month)
          : t.day,
    );
    final lastMonthExpense = await _txnDao.sumByRange(
      bookId,
      ymd(monthStart(lastMonth)),
      ymd(lastMonthSameDay),
      TxType.expense,
    );
    // 上月同期 <= 0 → null（显示「较上月同期 暂无」），禁止显示 0% 或 NaN。
    final momRatio = lastMonthExpense > 0
        ? (monthExpense - lastMonthExpense) / lastMonthExpense
        : null;

    // 日均支出 = 本月支出 / 本月已过天数（含今天）。
    // 用整数除法，避免 float 参与金额运算；截断误差 < 1 分。
    final elapsedDays = t.day;
    final dailyAvgExpense =
        elapsedDays >= 1 ? monthExpense ~/ elapsedDays : 0;

    final todayStr = ymd(t);
    final todayExpense =
        await _txnDao.sumByDate(bookId, todayStr, TxType.expense);
    final todayCount = await _txnDao.countByDate(bookId, todayStr);
    final todayTxns = await _txnDao.listByDate(bookId, todayStr);

    return HomeStats(
      monthExpense: monthExpense,
      monthIncome: monthIncome,
      monthBalance: monthBalance,
      balanceRate: balanceRate,
      momRatio: momRatio,
      dailyAvgExpense: dailyAvgExpense,
      todayExpense: todayExpense,
      todayCount: todayCount,
      todayTxns: todayTxns,
      budget: await _budgetStatus(t),
      bookName: (await _bookDao.findById(bookId))?.name ?? '未知账本',
      // 全时段口径：历史上记过账 ≠ 本月有记录
      hasAnyTxn: (await _txnDao.firstTxDate(bookId: bookId)) != null,
    );
  }

  /// 预算状态卡；未启用返回 `null`（首页整卡隐藏）。
  ///
  /// 「已用」**跨全部账本**汇总（架构文档 D8：预算为全局单份）。
  Future<BudgetStatus?> _budgetStatus(DateTime today) async {
    final budget = await _budgetDao.get();
    if (!budget.enabled) return null;

    final (mFrom, mTo) = monthRange(today);
    final used =
        await _txnDao.sumByRangeAllBooks(mFrom, mTo, TxType.expense);
    final monthly = budget.monthlyAmountMinor;
    final usedPct = monthly > 0 ? used / monthly : 0.0;

    return BudgetStatus(
      monthlyMinor: monthly,
      usedMinor: used,
      remainMinor: monthly - used,
      usedPct: usedPct,
      over: usedPct > 1,
    );
  }

  // ================================================================ 图表页

  @override
  Future<ChartBundle> chartBundle(
    int bookId,
    TxType mode,
    Period period,
    DateTime today,
  ) async {
    final t = startOfDay(today);
    final (from, to) = _periodRange(period, t);
    final fromStr = ymd(from);
    final toStr = ymd(to);

    final total = await _txnDao.sumByRange(bookId, fromStr, toStr, mode);
    final slices = await _slices(bookId, fromStr, toStr, mode);
    final bars = await _bars(bookId, period, mode, t);

    final income = await _txnDao.sumByRange(bookId, fromStr, toStr, TxType.income);
    final expense =
        await _txnDao.sumByRange(bookId, fromStr, toStr, TxType.expense);

    return ChartBundle(
      slices: slices,
      totalMinor: total,
      centerLabel: '${period.label}${mode.label}',
      bars: bars,
      barTitle: _barTitle(period, mode),
      yoy: await _yoy(bookId, mode, period, from, to, total),
      mom: await _mom(bookId, mode, period, t, total),
      momLabel: period == Period.year ? '半年环比' : '环比',
      balance: BalanceCard(
        title: '${period.label}结余',
        income: income,
        expense: expense,
        balance: income - expense,
        rate: income > 0 ? (income - expense) / income : null,
      ),
      rangeLabel: _rangeLabel(period, t),
    );
  }

  /// 本期区间 `[from, to]`（架构文档 §5.1）。
  (DateTime, DateTime) _periodRange(Period period, DateTime today) {
    switch (period) {
      case Period.week:
        return (weekStart(today), weekEnd(today));
      case Period.month:
        return (monthStart(today), monthEnd(today));
      case Period.year:
        return (DateTime(today.year, 1, 1), DateTime(today.year, 12, 31));
    }
  }

  /// 环形图分段：过滤金额 ≤ 0 → 降序 → 超过 8 项取前 7 + 「其他」合并。
  Future<List<CategorySlice>> _slices(
    int bookId,
    String from,
    String to,
    TxType mode,
  ) async {
    final rows = await _txnDao.groupByCategory(bookId, from, to, mode);
    final positive = rows
        .where((r) => _asInt(r['amount_minor']) > 0)
        .toList()
      ..sort((a, b) => _asInt(b['amount_minor']).compareTo(_asInt(a['amount_minor'])));

    final total = positive.fold<int>(
      0,
      (sum, r) => sum + _asInt(r['amount_minor']),
    );
    if (total <= 0) return const [];

    const maxSlices = 8;
    const keepCount = maxSlices - 1;
    final head = positive.take(keepCount).toList();
    final tail = positive.skip(keepCount).toList();

    final result = <CategorySlice>[
      for (final r in head)
        CategorySlice(
          categoryId: _asInt(r['category_id']),
          name: r['name'] as String? ?? '其他',
          colorHex: r['color_stroke'] as String? ??
              AppConstants.defaultCategoryColorStroke,
          amountMinor: _asInt(r['amount_minor']),
          ratio: _asInt(r['amount_minor']) / total,
        ),
    ];

    if (tail.isNotEmpty) {
      final restAmount =
          tail.fold<int>(0, (sum, r) => sum + _asInt(r['amount_minor']));
      result.add(CategorySlice(
        categoryId: 0,
        name: '其他',
        colorHex: AppConstants.defaultCategoryColorStroke,
        amountMinor: restAmount,
        ratio: restAmount / total,
      ));
    }
    return result;
  }

  /// 柱状图序列（架构文档 §5.1）。
  ///
  /// - 周：固定 7 根（周一~周日），未来日期值为 0，高亮今天；
  /// - 月：近 6 个月（含本月），高亮最后一根；
  /// - 年：近 6 年（含今年），高亮最后一根。
  Future<List<BarItem>> _bars(
    int bookId,
    Period period,
    TxType mode,
    DateTime today,
  ) async {
    switch (period) {
      case Period.week:
        final start = weekStart(today);
        final items = <BarItem>[];
        for (var i = 0; i < 7; i++) {
          final d = addDays(start, i);
          final amount = d.isAfter(today)
              ? 0
              : await _txnDao.sumByDate(bookId, ymd(d), mode);
          items.add(BarItem(
            label: weekdayCn(d),
            amountMinor: amount,
            hot: isSameDay(d, today),
          ));
        }
        return items;

      case Period.month:
        final items = <BarItem>[];
        for (var i = 5; i >= 0; i--) {
          final m = addMonths(monthStart(today), -i);
          final (f, t) = monthRange(m);
          items.add(BarItem(
            label: '${m.month}月',
            amountMinor: await _txnDao.sumByRange(bookId, f, t, mode),
            hot: i == 0,
          ));
        }
        return items;

      case Period.year:
        final items = <BarItem>[];
        for (var i = 5; i >= 0; i--) {
          final y = today.year - i;
          items.add(BarItem(
            label: '$y',
            amountMinor: await _txnDao.sumByRange(
              bookId,
              ymd(DateTime(y, 1, 1)),
              ymd(DateTime(y, 12, 31)),
              mode,
            ),
            hot: i == 0,
          ));
        }
        return items;
    }
  }

  String _barTitle(Period period, TxType mode) => switch (period) {
        Period.week => '近7天${mode.label}',
        Period.month => '近6个月${mode.label}',
        Period.year => '近6年${mode.label}',
      };

  /// 右上角只读范围 chip。
  String _rangeLabel(Period period, DateTime today) => switch (period) {
        Period.week => '${today.month}月第${((today.day - 1) ~/ 7) + 1}周',
        Period.month => '${today.month}月',
        Period.year => '${today.year}年',
      };

  /// 同比：本期各日期 -1 年的同区间。
  Future<CompareItem?> _yoy(
    int bookId,
    TxType mode,
    Period period,
    DateTime from,
    DateTime to,
    int current,
  ) async {
    final baseFrom = addYears(from, -1);
    final baseTo = addYears(to, -1);
    final base = await _txnDao.sumByRange(
      bookId,
      ymd(baseFrom),
      ymd(baseTo),
      mode,
    );
    return _compare(current, base, mode, 'vs 去年');
  }

  /// 环比 / 半年环比（架构文档 §5.2）。
  ///
  /// - 周：本期各日期 -7 天；
  /// - 月：上月 1 号 ~ 上月 `min(今天日, 上月天数)`；
  /// - 年：今年 1/1 ~ 6/30；**今天 ≤ 6/30 时返回 `null`**（基期包含本期，
  ///   数学上退化，UI 显示「暂无对比数据」）。
  Future<CompareItem?> _mom(
    int bookId,
    TxType mode,
    Period period,
    DateTime today,
    int current,
  ) async {
    switch (period) {
      case Period.week:
        final base = await _txnDao.sumByRange(
          bookId,
          ymd(addDays(weekStart(today), -7)),
          ymd(addDays(weekEnd(today), -7)),
          mode,
        );
        return _compare(current, base, mode, 'vs 上周');

      case Period.month:
        final lastMonth = addMonths(today, -1);
        final sameDay = DateTime(
          lastMonth.year,
          lastMonth.month,
          today.day > daysInMonth(lastMonth.year, lastMonth.month)
              ? daysInMonth(lastMonth.year, lastMonth.month)
              : today.day,
        );
        final base = await _txnDao.sumByRange(
          bookId,
          ymd(monthStart(lastMonth)),
          ymd(sameDay),
          mode,
        );
        return _compare(current, base, mode, 'vs 上月');

      case Period.year:
        if (today.month <= 6 && today.day <= 30) {
          return null;
        }
        final base = await _txnDao.sumByRange(
          bookId,
          ymd(DateTime(today.year, 1, 1)),
          ymd(DateTime(today.year, 6, 30)),
          mode,
        );
        return _compare(current, base, mode, 'vs 上半年');
    }
  }

  /// 构造对比项。
  ///
  /// `base <= 0` → 返回 `null`（禁止显示 0% 或 NaN）。
  /// `good = (支出) ? ratio < 0 : ratio > 0`。
  CompareItem? _compare(int current, int base, TxType mode, String baseLabel) {
    if (base <= 0) return null;
    final ratio = (current - base) / base;
    final good = mode == TxType.expense ? ratio < 0 : ratio > 0;
    return CompareItem(
      ratio: ratio,
      baseLabel: '$baseLabel ¥${fmtMoney(base)}',
      good: good,
    );
  }

  // ================================================================ 日历页

  @override
  Future<CalendarMonth> calendarMonth(
    int bookId,
    int year,
    int month,
    DateTime today, {
    DateTime? selected,
  }) async {
    final t = startOfDay(today);
    final expenseByDay =
        await _txnDao.dailyExpenseInMonth(bookId, year, month);
    final incomeByDay = await _txnDao.dailyIncomeInMonth(bookId, year, month);

    final maxDayExpense = expenseByDay.values.fold<int>(0, mathMax);

    // 42 格：从本月 1 号所在周的周一开始，含首尾补位空白格。
    final first = DateTime(year, month, 1);
    final gridStart = addDays(first, -(first.weekday - 1));

    // 选中日优先级：调用方显式指定且落在本年本月 → 用它；
    // 否则退化为「今天在本月 ? 今天 : 本月 1 号」。
    final picked = selected == null
        ? null
        : (selected.year == year && selected.month == month
            ? startOfDay(selected)
            : null);
    final selectedDay = picked ??
        ((t.year == year && t.month == month) ? t : DateTime(year, month, 1));

    final cells = <DayCell>[
      for (var i = 0; i < 42; i++)
        _dayCell(
          date: addDays(gridStart, i),
          year: year,
          month: month,
          today: t,
          selected: selectedDay,
          expenseByDay: expenseByDay,
          incomeByDay: incomeByDay,
          maxDayExpense: maxDayExpense,
        ),
    ];

    return CalendarMonth(
      year: year,
      month: month,
      cells: cells,
      maxDayExpense: maxDayExpense,
      selectedDay: await _dayDetail(bookId, selectedDay),
    );
  }

  DayCell _dayCell({
    required DateTime date,
    required int year,
    required int month,
    required DateTime today,
    required DateTime selected,
    required Map<String, int> expenseByDay,
    required Map<String, int> incomeByDay,
    required int maxDayExpense,
  }) {
    final key = ymd(date);
    final expense = expenseByDay[key] ?? 0;
    final income = incomeByDay[key] ?? 0;
    final hasRecord = expense > 0 || income > 0;

    // 热度占比（架构文档 §5.3），优先级从高到低：
    // 1. 无记录 → 0（无色，UI 侧不套底色）；
    // 2. 当月无任何支出记录（maxDayExpense = 0）→ 1，
    //    避免 0/0 出现 NaN，同时让纯收入月不至于全灰；
    // 3. 纯收入日 → 0（对应 `heatColor(0)` = green × base，最浅一档）；
    // 4. 常规 → min(1, 当日支出 / 当月最大单日支出)。
    double alpha = 0;
    if (hasRecord) {
      if (maxDayExpense <= 0) {
        alpha = 1;
      } else if (expense <= 0) {
        alpha = 0;
      } else {
        final ratio = expense / maxDayExpense;
        alpha = ratio > 1 ? 1 : ratio;
      }
    }

    return DayCell(
      date: date,
      inMonth: date.year == year && date.month == month,
      expense: expense,
      income: income,
      heatAlpha: alpha,
      isToday: isSameDay(date, today),
      isSelected: isSameDay(date, selected),
    );
  }

  /// 选中日汇总 + 明细。
  Future<DayDetail> _dayDetail(int bookId, DateTime date) async {
    final key = ymd(date);
    final expense = await _txnDao.sumByDate(bookId, key, TxType.expense);
    final income = await _txnDao.sumByDate(bookId, key, TxType.income);
    return DayDetail(
      date: key,
      expense: expense,
      income: income,
      txns: await _txnDao.listByDate(bookId, key),
    );
  }

  // ================================================================ 账本 / 我的

  @override
  Future<BookStats> bookStats(int bookId, DateTime today) async {
    return BookStats(
      count: await _txnDao.countAll(bookId: bookId),
      totalExpense: await _bookDao.totalExpenseMinor(bookId),
      streakDays: await _streakDays(bookId: bookId, today: today),
    );
  }

  @override
  Future<GlobalStats> globalStats(DateTime today) async {
    final first = await _txnDao.firstTxDate();
    return GlobalStats(
      totalCount: await _txnDao.countAll(),
      bookCount: await _bookDao.count(),
      streakDays: await _streakDays(today: today),
      // 坚持天数 = 首次记账日 → 今天的自然日跨度（含首日）。
      persistDays: first == null
          ? 0
          : daysBetween(parseYmd(first), startOfDay(today)) + 1,
    );
  }

  /// 连续打卡（架构文档 §5.3）。
  ///
  /// 从今天起（今天无记录则从昨天起）向前回溯连续有交易的自然日数；
  /// 今天和昨天都无记录 → 0。
  Future<int> _streakDays({int? bookId, required DateTime today}) async {
    final dates = await _txnDao.distinctDates(bookId: bookId);
    if (dates.isEmpty) return 0;

    final set = dates.toSet();
    final todayStr = ymd(startOfDay(today));
    final yesterdayStr = ymd(addDays(startOfDay(today), -1));

    String? cursor;
    if (set.contains(todayStr)) {
      cursor = todayStr;
    } else if (set.contains(yesterdayStr)) {
      cursor = yesterdayStr;
    } else {
      return 0;
    }

    var streak = 0;
    while (cursor != null && set.contains(cursor)) {
      streak++;
      cursor = ymd(addDays(parseYmd(cursor), -1));
    }
    return streak;
  }

  // ---------------------------------------------------------------- 工具

  /// 宽松转 int（兼容 sqflite 在不同平台返回 int / num / String）。
  int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

/// 两个 int 取较大者（避免在仓储里 import `dart:math` 只为一次 max）。
int mathMax(int a, int b) => a > b ? a : b;
