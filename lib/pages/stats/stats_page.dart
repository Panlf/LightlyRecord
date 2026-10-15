import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/model/tx_type.dart';
import '../../painters/bars_painter.dart';
import '../../painters/donut_painter.dart';
import '../../painters/gauge_painter.dart';
import '../../repository/stats_repository.dart';
import '../../state/app_state.dart';
import '../../state/stats_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_segment.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/progress_track.dart';
import '../shell/main_shell.dart';

/// 图表页：环形图 + 柱状图 + 同期对比 + 结余。
///
/// 所有数字均来自 [StatsController] → `StatsRepository.chartBundle()`，
/// **页面内不写任何 SQL、不做任何金额运算**；颜色一律走 [AppColors] Token。
///
/// 布局（严格对齐原型「图表」Tab）：
/// 页头（图表 / 账本名 / 范围 chip 只读）→ 大分段（支出/收入）→
/// 小分段（周/月/年）→ 环形图卡 → 柱状图卡 → 同期对比卡 → 结余卡。
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  /// 页面级 Controller 引用（`initState` 取出，供 `dispose` 反注册用）。
  late final StatsController _controller;

  @override
  void initState() {
    super.initState();
    // 注册 `dataVersion` / 账本监听：记一笔、编辑、删除、切账本之后
    // 图表页与今日页 / 日历页在同一帧一起重算。
    // （`MainShell` 的 5 个 Tab 由 `IndexedStack` 常驻，页面不会被反复
    // 创建，因此监听放在 initState / dispose 这一对里最稳。）
    _controller = context.read<StatsController>();
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
    final controller = context.watch<StatsController>();
    final bundle = controller.stats;

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
              _Header(rangeLabel: bundle?.rangeLabel),
              const SizedBox(height: AppDimens.pageGap),
              const _ModeSegment(),
              const SizedBox(height: 10),
              const _PeriodSegment(),
              const SizedBox(height: AppDimens.pageGap),
              if (bundle == null)
                controller.error != null
                    ? EmptyView(
                        message: controller.error!,
                        subtitle: '点击重试，或下拉刷新',
                        icon: Icons.cloud_off_outlined,
                        actionLabel: '重试',
                        onAction: () => controller.load(force: true),
                      )
                    : const _StatsSkeleton()
              else if (!_hasAnyData(bundle)) ...[
                const AppCard(
                  child: EmptyView(
                    icon: Icons.insert_chart_outlined,
                    iconSize: 32,
                    message: '本期暂无记账数据',
                  ),
                ),
              ] else ...[
                _DonutCard(bundle: bundle),
                const SizedBox(height: AppDimens.pageGap),
                _BarsCard(bundle: bundle),
                const SizedBox(height: AppDimens.pageGap),
                _CompareCard(bundle: bundle),
                const SizedBox(height: AppDimens.pageGap),
                _BalanceCard(balance: bundle.balance),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 本期是否完全无数据（环形图无分段且柱状图全 0 → 走空态）。
  bool _hasAnyData(ChartBundle bundle) =>
      bundle.slices.isNotEmpty || bundle.bars.any((b) => b.amountMinor > 0);
}

/// 页头：「图表」+ 当前账本名（点击跳账本 Tab）+ 右上角只读范围 chip。
class _Header extends StatelessWidget {
  const _Header({required this.rangeLabel});

  /// 右上角范围文案；数据未就绪时传 `null`（不渲染 chip）。
  final String? rangeLabel;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final appState = context.watch<AppState>();

    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => MainShell.switchTabOf(context, 3),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '图表',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: AppTypography.semiBold,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    appState.bookName,
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
          ),
          if (rangeLabel != null)
            AppChip(label: rangeLabel!, background: c.track, color: c.ink2),
        ],
      ),
    );
  }
}

/// 收支视角大分段（44px，主色填充）。
class _ModeSegment extends StatelessWidget {
  const _ModeSegment();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StatsController>();
    return AppSegment<TxType>(
      values: const [TxType.expense, TxType.income],
      value: controller.mode,
      onChanged: controller.setMode,
      labels: const ['支出', '收入'],
    );
  }
}

/// 统计周期小分段（36px，卡片色填充）。
class _PeriodSegment extends StatelessWidget {
  const _PeriodSegment();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StatsController>();
    return AppSegment<Period>(
      values: const [Period.week, Period.month, Period.year],
      value: controller.period,
      onChanged: controller.setPeriod,
      labels: const ['本周', '本月', '本年'],
      small: true,
    );
  }
}

/// 环形图卡：左 140×140 环形 + 中心总额，右侧图例（金额降序）。
class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.bundle});

  /// 图表页数据。
  final ChartBundle bundle;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final slices = bundle.slices;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 左：140×140 环形图
              SizedBox(
                width: AppDimens.donutSize,
                height: AppDimens.donutSize,
                child: CustomPaint(
                  painter: DonutPainter(
                    slices: [
                      for (final s in slices)
                        DonutSlice(hexToColor(s.colorHex), s.ratio),
                    ],
                    trackColor: c.track,
                    strokeWidth: AppDimens.donutStroke,
                  ),
                  // 中心：小字标签 + 大数字额
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bundle.centerLabel,
                          style: TextStyle(
                            fontSize: AppTypography.chip,
                            color: c.ink2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmtMoney(bundle.totalMinor),
                          style: AppTypography.numberStyle(
                            fontSize: AppTypography.donutValue,
                            fontWeight: AppTypography.semiBold,
                            color: c.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.donutGap),
              // 右：图例（降序）
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in slices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _LegendRow(slice: s),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 图例一行：8px 色点 + 名称 + 金额 + 占比。
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice});

  /// 分段数据。
  final CategorySlice slice;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hexToColor(slice.colorHex),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTypography.legend,
                color: c.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmtMoney(slice.amountMinor),
            style: AppTypography.numberStyle(
              fontSize: AppTypography.legendValue,
              fontWeight: AppTypography.medium,
              color: c.ink2,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              fmtPercent(slice.ratio, decimals: 0),
              textAlign: TextAlign.right,
              style: AppTypography.numberStyle(
                fontSize: AppTypography.legendValue,
                fontWeight: AppTypography.medium,
                color: c.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 柱状图卡：标题 + 「单位：元」+ 96px 柱组 + 底部标签（高亮同步）。
class _BarsCard extends StatelessWidget {
  const _BarsCard({required this.bundle});

  /// 图表页数据。
  final ChartBundle bundle;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bundle.barTitle,
                  style: TextStyle(
                    fontSize: AppTypography.segLabel,
                    fontWeight: AppTypography.semiBold,
                    color: c.ink,
                  ),
                ),
              ),
              Text(
                '单位：元',
                style: TextStyle(
                  fontSize: AppTypography.chip,
                  color: c.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.cardGap),
          SizedBox(
            height: AppDimens.barsHeight,
            child: CustomPaint(
              painter: BarsPainter(
                bars: [
                  for (final b in bundle.bars)
                    BarValue(b.amountMinor, hot: b.hot),
                ],
                idleColor: c.barIdle,
                hotColor: c.green,
                gap: AppDimens.barsGap,
                radiusTop: AppDimens.barRadiusTop,
                radiusBottom: AppDimens.barRadiusBottom,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.barLabelGap),
          // 底部标签行：与柱子一一对应，高亮项用主色 + 500
          Row(
            children: [
              for (final b in bundle.bars)
                Expanded(
                  child: Text(
                    b.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTypography.barLabel,
                      fontWeight:
                          b.hot ? AppTypography.medium : AppTypography.regular,
                      color: b.hot ? c.green : c.ink3,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 同期对比卡：两个 104×104 仪表（同比 / 环比），任一端无数据显「暂无对比数据」。
class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.bundle});

  /// 图表页数据。
  final ChartBundle bundle;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '同期对比',
                style: TextStyle(
                  fontSize: AppTypography.segLabel,
                  fontWeight: AppTypography.semiBold,
                  color: c.ink,
                ),
              ),
              const Spacer(),
              Text(
                bundle.centerLabel,
                style: TextStyle(
                  fontSize: AppTypography.chip,
                  color: c.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.cardGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GaugeBlock(
                  tag: '同比',
                  item: bundle.yoy,
                  trackColor: c.track,
                  goodColor: c.green,
                  badColor: c.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GaugeBlock(
                  tag: bundle.momLabel,
                  item: bundle.mom,
                  trackColor: c.track,
                  goodColor: c.green,
                  badColor: c.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 单个仪表区：`item` 为 `null` 时显示「暂无对比数据」（绝不显示 0%）。
class _GaugeBlock extends StatelessWidget {
  const _GaugeBlock({
    required this.tag,
    required this.item,
    required this.trackColor,
    required this.goodColor,
    required this.badColor,
  });

  /// 标题（「同比」/「环比」/「半年环比」）。
  final String tag;

  /// 对比数据；`null` = 无基期。
  final CompareItem? item;

  /// 仪表底环色。
  final Color trackColor;

  /// 好消息弧色。
  final Color goodColor;

  /// 坏消息弧色。
  final Color badColor;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final data = item;

    return Column(
      children: [
        SizedBox(
          width: AppDimens.gaugeSize,
          height: AppDimens.gaugeSize,
          child: data == null
              // 无基期：只画底环，中心留空
              ? CustomPaint(
                  painter: GaugePainter(
                    ratio: 0,
                    trackColor: trackColor,
                    arcColor: AppColors.transparent,
                    radius: AppDimens.gaugeRadius,
                    strokeWidth: AppDimens.gaugeStroke,
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      painter: GaugePainter(
                        ratio: data.ratio,
                        trackColor: trackColor,
                        arcColor: data.good ? goodColor : badColor,
                        radius: AppDimens.gaugeRadius,
                        strokeWidth: AppDimens.gaugeStroke,
                      ),
                    ),
                    Text(
                      fmtSignedPercent(data.ratio),
                      style: AppTypography.numberStyle(
                        fontSize: AppTypography.gaugeValue,
                        fontWeight: AppTypography.semiBold,
                        color: data.good ? goodColor : badColor,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Text(
          tag,
          style: TextStyle(
            fontSize: AppTypography.legend,
            fontWeight: AppTypography.medium,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          data == null ? '暂无对比数据' : data.baseLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: AppTypography.chip,
            color: c.ink2,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// 结余卡：三行（收入 / 支出 / 结余）+ 双进度条（8px）。
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  /// 结余卡数据。
  final BalanceCard balance;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final over = balance.expense > balance.income;

    // 进度比例：收入为 0 时两条都为 0（禁止除零）；支出超收入封顶 100%。
    final outRatio =
        balance.income > 0 ? balance.expense / balance.income : 0.0;
    final outProgress = outRatio.isNaN
        ? 0.0
        : (outRatio < 0 ? 0.0 : (outRatio > 1 ? 1.0 : outRatio));

    // 超支百分比：支出相对收入多出的部分（收入为 0 时无意义）。
    final overPct = over && balance.income > 0
        ? ((balance.expense - balance.income) / balance.income * 100).round()
        : 0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                balance.title,
                style: TextStyle(
                  fontSize: AppTypography.segLabel,
                  fontWeight: AppTypography.medium,
                  color: c.ink,
                ),
              ),
              const Spacer(),
              AppChip(
                label: over
                    ? '已超支 $overPct%'
                    : (balance.rate == null
                        ? '结余率 —'
                        : '结余率 ${fmtPercent(balance.rate!, decimals: 0)}'),
                background: over ? AppColors.redLight : c.greenLight,
                color: over ? AppColors.redDeep : c.greenDeep,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontSize: 16,
                  color: c.ink2,
                  fontFamily: AppTypography.numberFontFamily,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                fmtMoney(balance.balance),
                style: AppTypography.numberStyle(
                  fontSize: 30,
                  fontWeight: AppTypography.bold,
                  color: c.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 收入行：满轨 + 金额
          _BalanceRow(
            label: '收入',
            value: balance.income,
            progress: 1.0,
            color: c.green,
          ),
          const SizedBox(height: 8),
          // 支出行：支出/收入 比例，超支封顶并转红
          _BalanceRow(
            label: '支出',
            value: balance.expense,
            progress: outProgress,
            color: over ? AppColors.redDeep : c.green,
            over: over,
            overPct: overPct,
          ),
        ],
      ),
    );
  }
}

/// 结余卡的一行（标签 + 8px 进度条 + 右对齐金额）。
class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    this.over = false,
    this.overPct = 0,
  });

  /// 行标签（「收入」/「支出」）。
  final String label;

  /// 金额（分）。
  final int value;

  /// 进度 0~1（已封顶）。
  final double progress;

  /// 进度条颜色。
  final Color color;

  /// 是否超支行（超支时在金额后追加「超支 N%」提示）。
  final bool over;

  /// 超支百分比。
  final int overPct;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.txnNote,
              color: c.ink2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ProgressTrack(
            value: progress,
            height: AppDimens.trackThick,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 66,
          child: Text(
            '¥${fmtMoney(value)}',
            textAlign: TextAlign.right,
            style: AppTypography.numberStyle(
              fontSize: AppTypography.txnNote,
              fontWeight: AppTypography.medium,
              color: over ? c.red : c.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// 加载中的骨架占位（避免数字从 0 跳到真实值）。
class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        AppCard(
          child: Column(
            children: [
              _SkeletonBar(width: double.infinity, height: 140, color: c.track),
              const SizedBox(height: 14),
              _SkeletonBar(width: 240, height: 12, color: c.track),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.pageGap),
        AppCard(
          child:
              _SkeletonBar(width: double.infinity, height: 96, color: c.track),
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
