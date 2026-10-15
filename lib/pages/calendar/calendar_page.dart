import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_ext.dart';
import '../../core/format.dart';
import '../../repository/stats_repository.dart';
import '../../router/app_routes.dart';
import '../../state/calendar_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/tx_tile.dart';

/// 深热度判定阈值：最终 alpha ≥ 该值时格内金额文字转纯白（架构文档 §5.3）。
///
/// base / span 来自主题 Token，故判定必须在 UI 侧完成。
const double kCalDeepHeatThreshold = 0.45;

/// 日历页：月历网格 + 热度底色 + 当日汇总双卡 + 当日明细。
///
/// 所有数字均来自 [CalendarController] → `StatsRepository.calendarMonth()`，
/// **页面内不写任何 SQL、不做任何金额运算**；颜色一律走 [AppColors] Token。
///
/// 格子状态优先级（严格对齐原型）：
/// `sel`（整格主色填充白字）> `today`（1.5px 主色内描边）>
/// `heat`（`green × (heatBase + heatSpan × 当日占比)` 底色）。
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  /// 页面级 Controller 引用（`initState` 取出，供 `dispose` 反注册用）。
  late final CalendarController _controller;

  @override
  void initState() {
    super.initState();
    // 注册 `dataVersion` / 账本监听：记一笔、编辑、删除、切账本之后
    // 日历页与今日页 / 图表页在同一帧一起重算。
    // （`MainShell` 的 5 个 Tab 由 `IndexedStack` 常驻，页面不会被反复
    // 创建，因此监听放在 initState / dispose 这一对里最稳。）
    _controller = context.read<CalendarController>();
    _controller.attach();
    // 首帧后加载；Controller 自身有 isStale 去重，重复调用无副作用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.load(force: true);
    });
  }

  @override
  void dispose() {
    _controller.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final controller = context.watch<CalendarController>();
    final data = controller.data;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.green,
          backgroundColor: c.card,
          onRefresh: () => controller.load(force: true),
          child: ListView(
            padding: const EdgeInsets.only(
              left: AppDimens.pageMargin,
              right: AppDimens.pageMargin,
              top: 6,
              // 给底部胶囊导航留出呼吸空间
              bottom: AppDimens.tabBarHeight + 24,
            ),
            children: [
              _Header(
                year: controller.year,
                month: controller.month,
                onPrev: controller.prevMonth,
                onNext: controller.nextMonth,
              ),
              const SizedBox(height: AppDimens.pageGap),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 卡内头部：年月（翻月按钮在页头右侧）
                    Text(
                      ymLabelCn(DateTime(controller.year, controller.month)),
                      style: TextStyle(
                        fontSize: AppTypography.cardTitle,
                        fontWeight: AppTypography.semiBold,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 星期行：周一为首列
                    const _DowRow(),
                    const SizedBox(height: 4),
                    if (data == null)
                      const _CalendarSkeleton()
                    else
                      _DayGrid(
                        cells: data.cells,
                        onPick: controller.selectDay,
                      ),
                    const SizedBox(height: 10),
                    // 脚注文案（架构文档 §T04：热度底色说明）
                    Text(
                      '颜色越深表示当天支出越多 · 点击日期查看明细',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTypography.chip,
                        color: c.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.pageGap),
              if (data == null)
                controller.error != null
                    ? AppCard(
                        child: EmptyView(
                          message: controller.error!,
                          subtitle: '点击重试',
                          icon: Icons.cloud_off_outlined,
                          actionLabel: '重试',
                          onAction: () => controller.load(force: true),
                        ),
                      )
                    : const _CalendarSkeleton()
              else ...[
                _DaySummary(detail: data.selectedDay),
                const SizedBox(height: AppDimens.pageGap),
                _DayDetailCard(detail: data.selectedDay),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 页头：「日历」+ 当前显示年月 + 左右翻月按钮。
class _Header extends StatelessWidget {
  const _Header({
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  /// 当前显示年。
  final int year;

  /// 当前显示月。
  final int month;

  /// 上一个月。
  final VoidCallback onPrev;

  /// 下一个月。
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '日历',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: AppTypography.semiBold,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ymLabelCn(DateTime(year, month)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTypography.txnNote,
                    color: c.ink2,
                  ),
                ),
              ],
            ),
          ),
          _NavButton(
            icon: Icons.chevron_left,
            tooltip: '上一个月',
            onTap: onPrev,
          ),
          const SizedBox(width: 8),
          _NavButton(
            icon: Icons.chevron_right,
            tooltip: '下一个月',
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

/// 翻月按钮（36px 圆角 12，卡片底）。
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  /// 图标。
  final IconData icon;

  /// 无障碍提示。
  final String tooltip;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: c.ink2),
        ),
      ),
    );
  }
}

/// 星期行（周一 ~ 周日，11px ink2 500）。
class _DowRow extends StatelessWidget {
  const _DowRow();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    const labels = ['一', '二', '三', '四', '五', '六', '日'];

    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.calDow,
                fontWeight: AppTypography.medium,
                color: c.ink2,
              ),
            ),
          ),
      ],
    );
  }
}

/// 6×7 = 42 格月历网格（每格高 50）。
class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.cells, required this.onPick});

  /// 仓库返回的 42 个格子（含首尾补位空白格）。
  final List<DayCell> cells;

  /// 选中某天（仅 inMonth 格可点）。
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        return GridView.count(
          crossAxisCount: 7,
          // 固定格高 50，宽度由父容器均分
          childAspectRatio: cellWidth / 50,
          mainAxisSpacing: 2,
          crossAxisSpacing: 0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final cell in cells)
              _DayCellView(
                cell: cell,
                onTap: cell.inMonth ? () => onPick(cell.date) : null,
                heatColor: cell.expense > 0 || cell.income > 0
                    ? c.heatColor(cell.heatAlpha)
                    : null,
                // 最终 alpha ≥ .45 → 金额文字转纯白（base/span 在 UI 侧合成）
                deepAmount: c.heatBase + c.heatSpan * cell.heatAlpha >=
                    kCalDeepHeatThreshold,
              ),
          ],
        );
      },
    );
  }
}

/// 单个日期格。
class _DayCellView extends StatelessWidget {
  const _DayCellView({
    required this.cell,
    required this.onTap,
    required this.heatColor,
    required this.deepAmount,
  });

  /// 格子数据。
  final DayCell cell;

  /// 点击回调；`null` 表示空白格不可点。
  final VoidCallback? onTap;

  /// 热度底色；`null` 表示当日无记录（不套色）。
  final Color? heatColor;

  /// 金额文字是否转纯白。
  final bool deepAmount;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    // 空白补位格：无内容、不可点击。
    if (!cell.inMonth) {
      return const SizedBox.shrink();
    }

    final hasRecord = cell.expense > 0 || cell.income > 0;
    final pureIncome = hasRecord && cell.expense <= 0;

    // ---- 状态优先级：sel > today > heat ----
    late Color background;
    late Color dateColor;
    Color amountColor;
    FontWeight dateWeight = AppTypography.regular;
    Border? border;

    if (cell.isSelected) {
      background = c.green;
      dateColor = AppColors.white;
      // 选中态支出金额 82% 白，收入金额纯白
      amountColor = pureIncome
          ? AppColors.white
          : AppColors.white.withValues(alpha: 0.82);
      dateWeight = AppTypography.semiBold;
    } else {
      background = heatColor ?? AppColors.transparent;
      dateColor = c.ink;
      amountColor = pureIncome ? c.greenDeep : c.ink.withValues(alpha: 0.85);
      if (cell.isToday) {
        // 今日（非选中）：1.5px 主色内描边 + 主色日期
        border = Border.all(color: c.green, width: 1.5);
        dateColor = c.greenDeep;
        dateWeight = AppTypography.semiBold;
      }
      if (deepAmount && hasRecord && heatColor != null) {
        amountColor = AppColors.white;
      }
    }

    final amountText = hasRecord
        ? (pureIncome
            ? '+${fmtCompact(cell.income)}'
            : fmtCompact(cell.expense))
        : null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: border,
        ),
        padding: const EdgeInsets.only(top: 7),
        child: Column(
          children: [
            Text(
              '${cell.date.day}',
              style: TextStyle(
                fontSize: AppTypography.body,
                fontWeight: dateWeight,
                color: dateColor,
              ),
            ),
            const SizedBox(height: 8),
            if (amountText != null)
              Text(
                amountText,
                maxLines: 1,
                style: AppTypography.numberStyle(
                  fontSize: AppTypography.calAmount,
                  fontWeight: AppTypography.medium,
                  color: amountColor,
                  letterSpacing: -0.2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 当日汇总双卡：支出 / 收入。
class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.detail});

  /// 选中日汇总与明细。
  final DayDetail detail;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Row(
      children: [
        Expanded(
          child: AppCard(
            radius: AppDimens.cardRadiusXs,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当日支出',
                  style: TextStyle(
                    fontSize: AppTypography.chip,
                    color: c.ink2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${fmtMoney(detail.expense)}',
                  style: AppTypography.numberStyle(
                    fontSize: 17,
                    fontWeight: AppTypography.semiBold,
                    color: c.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            radius: AppDimens.cardRadiusXs,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当日收入',
                  style: TextStyle(
                    fontSize: AppTypography.chip,
                    color: c.ink2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${fmtMoney(detail.income)}',
                  style: AppTypography.numberStyle(
                    fontSize: 17,
                    fontWeight: AppTypography.semiBold,
                    color: c.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 当日明细列表（与今日页同一交易行组件、同一切跳方式）。
class _DayDetailCard extends StatelessWidget {
  const _DayDetailCard({required this.detail});

  /// 选中日汇总与明细。
  final DayDetail detail;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final date = parseYmd(detail.date);

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              '${mdLabelCn(date)} ${weekdayCn(date)}',
              style: TextStyle(
                fontSize: AppTypography.txnNote,
                color: c.ink2,
              ),
            ),
          ),
          if (detail.txns.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: EmptyView(
                icon: Icons.calendar_today_outlined,
                iconSize: 32,
                message: '当日暂无交易记录',
              ),
            )
          else
            for (final txn in detail.txns)
              TxTile.fromTxn(
                txn,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.txDetail,
                  arguments: txn.id,
                ),
              ),
        ],
      ),
    );
  }
}

/// 加载中的骨架占位。
class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        AppCard(
          child: Column(
            children: [
              _SkeletonBar(width: double.infinity, height: 12, color: c.track),
              const SizedBox(height: 14),
              _SkeletonBar(width: double.infinity, height: 210, color: c.track),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.pageGap),
        Row(
          children: [
            Expanded(
              child: AppCard(
                radius: AppDimens.cardRadiusXs,
                child: _SkeletonBar(
                  width: double.infinity,
                  height: 40,
                  color: c.track,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppCard(
                radius: AppDimens.cardRadiusXs,
                child: _SkeletonBar(
                  width: double.infinity,
                  height: 40,
                  color: c.track,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
