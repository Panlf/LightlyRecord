import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_ext.dart';
import '../../core/format.dart';
import '../../repository/pref_repository.dart';
import '../../repository/stats_repository.dart';
import '../../router/app_routes.dart';
import '../../state/app_state.dart';
import '../../state/home_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../utils/greetings.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/progress_track.dart';
import '../../widgets/tx_tile.dart';
import '../shell/main_shell.dart';

/// 今日页：页头 + 概览卡 + 今日支出卡 + 预算卡（默认隐藏）+ 当日明细。
///
/// 所有数字均来自 [HomeController] → `StatsRepository.homeStats()`，
/// **页面内不写任何 SQL、不做任何金额运算**。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 页面级 Controller 引用（`initState` 取出，供 `dispose` 反注册用）。
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    // 注册 `dataVersion` / 账本监听：记一笔、编辑、删除、切账本之后
    // 首页与图表页 / 日历页在同一帧一起重算。
    // （`MainShell` 的 5 个 Tab 由 `IndexedStack` 常驻，页面不会被反复
    // 创建，因此监听放在 initState / dispose 这一对里最稳。）
    _controller = context.read<HomeController>();
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
    final appState = context.watch<AppState>();
    final controller = context.watch<HomeController>();
    final stats = controller.stats;

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
              _Header(bookName: appState.bookName, nickname: appState.nickname),
              const SizedBox(height: AppDimens.pageGap),
              if (stats == null)
                controller.error != null
                    ? EmptyView(
                        message: controller.error!,
                        subtitle: '点击重试，或下拉刷新',
                        icon: Icons.cloud_off_outlined,
                        actionLabel: '重试',
                        onAction: () => controller.load(force: true),
                      )
                    : const _HomeSkeleton()
              else ...[
                _OverviewCard(stats: stats),
                const SizedBox(height: AppDimens.pageGap),
                _TodayCard(stats: stats),
                if (stats.budget != null) ...[
                  const SizedBox(height: AppDimens.pageGap),
                  _BudgetCard(status: stats.budget!),
                ],
                const SizedBox(height: AppDimens.pageGap),
                _DayListHeader(onTapAll: () => MainShell.switchTabOf(context, 2)),
                const SizedBox(height: AppDimens.cardGap),
                _DayList(stats: stats),
                // 全库无数据时附一段引导（含「载入示例数据」入口）
                if (_isEmptyBook(stats)) ...[
                  const SizedBox(height: AppDimens.pageGap),
                  _EmptyGuide(hasAnyTxn: stats.hasAnyTxn),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 本月无任何收支 → 视为空账本。
  bool _isEmptyBook(HomeStats stats) =>
      stats.monthExpense == 0 && stats.monthIncome == 0 && stats.todayTxns.isEmpty;
}

/// 页头：问候语 + 当前账本名 + 36px 头像。
class _Header extends StatelessWidget {
  const _Header({required this.bookName, required this.nickname});

  /// 当前账本名（跟随 AppState 切换联动）。
  final String bookName;

  /// 用户昵称（问候语「下午好，XX」用）。
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Greetings.now(nickname),
                  style: TextStyle(
                    fontSize: AppTypography.body,
                    color: c.ink2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bookName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: AppTypography.semiBold,
                    color: c.ink,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: AppDimens.avatarSm,
            height: AppDimens.avatarSm,
            decoration: BoxDecoration(
              color: c.greenLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.person_outline, size: 20, color: c.greenDeep),
          ),
        ],
      ),
    );
  }
}

/// 概览卡：本月支出 / 本月收入 / 本月结余 / 较上月同期 / 日均支出。
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final now = DateTime.now();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本月支出',
                style: TextStyle(
                  fontSize: AppTypography.body,
                  color: c.ink2,
                ),
              ),
              const Spacer(),
              Text(
                '收入 ¥${fmtMoney(stats.monthIncome)}',
                style: TextStyle(
                  fontSize: AppTypography.body,
                  fontWeight: AppTypography.medium,
                  color: c.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
              const SizedBox(width: 4),
              Text(
                fmtMoney(stats.monthExpense),
                style: AppTypography.numberStyle(
                  fontSize: 34,
                  fontWeight: AppTypography.bold,
                  color: c.ink,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '本月结余',
                    style: TextStyle(
                      fontSize: AppTypography.chip,
                      color: c.ink3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '¥${fmtMoney(stats.monthBalance)}',
                    style: AppTypography.numberStyle(
                      fontSize: AppTypography.cardTitle,
                      fontWeight: AppTypography.semiBold,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MomChip(ratio: stats.momRatio),
              const Spacer(),
              Text(
                '日均支出 ¥${fmtMoney(stats.dailyAvgExpense)}',
                style: TextStyle(
                  fontSize: AppTypography.txnNote,
                  color: c.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stats.balanceRate == null
                ? '本月暂无收入'
                : '结余率 ${fmtPercent(stats.balanceRate!, decimals: 0)}',
            style: TextStyle(
              fontSize: AppTypography.chip,
              color: c.ink3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '统计至 ${now.month}月${now.day}日',
            style: TextStyle(
              fontSize: AppTypography.chip,
              color: c.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

/// 「较上月同期」chip；无基期数据时显示「暂无」。
class _MomChip extends StatelessWidget {
  const _MomChip({required this.ratio});

  /// 涨跌幅；`null` = 无基期数据。
  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    if (ratio == null) {
      return AppChip(
        label: '较上月同期 暂无',
        background: c.track,
        color: c.ink2,
      );
    }

    // 支出下降是好事 → 绿；上升 → 红。
    final good = ratio! < 0;
    return AppChip(
      label: '较上月同期 ${fmtSignedPercent(ratio!, decimals: 0)}',
      background: good ? c.greenLight : AppColors.redLight,
      color: good ? c.greenDeep : AppColors.redDeep,
    );
  }
}

/// 今日支出卡。
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '今日支出',
                style: TextStyle(
                  fontSize: AppTypography.txnNote,
                  color: c.ink2,
                ),
              ),
              const Spacer(),
              Text(
                '今日 ${stats.todayCount} 笔',
                style: TextStyle(
                  fontSize: AppTypography.chip,
                  color: c.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AmountLine(
            amountMinor: stats.todayExpense,
            fontSize: 18,
            color: c.ink,
          ),
        ],
      ),
    );
  }
}

/// 预算卡（仅 `budget.enabled = 1` 时展示）。
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.status});

  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final pct = (status.usedPct * 100).round();
    final progress = status.usedPct.isNaN
        ? 0.0
        : (status.usedPct < 0
            ? 0.0
            : (status.usedPct > 1 ? 1.0 : status.usedPct));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本月预算',
                style: TextStyle(
                  fontSize: AppTypography.segLabel,
                  fontWeight: AppTypography.medium,
                  color: c.ink,
                ),
              ),
              const Spacer(),
              Text(
                status.over
                    ? '已超支 ¥${fmtMoney(-status.remainMinor)}'
                    : '剩余 ¥${fmtMoney(status.remainMinor)}',
                style: TextStyle(
                  fontSize: AppTypography.txnNote,
                  fontWeight: AppTypography.medium,
                  color: status.over ? AppColors.redDeep : c.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AmountLine(
                amountMinor: status.usedMinor,
                fontSize: 22,
                color: c.ink,
                bold: true,
              ),
              const SizedBox(width: 6),
              Text(
                '/ ¥${fmtMoney(status.monthlyMinor)}',
                style: TextStyle(
                  fontSize: AppTypography.chip,
                  color: c.ink3,
                  fontFamily: AppTypography.numberFontFamily,
                ),
              ),
              const Spacer(),
              AppChip(
                label: status.over ? '已超支 $pct%' : '已用 $pct%',
                background: status.over ? AppColors.redLight : c.greenLight,
                color: status.over ? AppColors.redDeep : c.greenDeep,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProgressTrack(
            value: progress,
            height: AppDimens.trackThick,
            over: status.over,
          ),
          const SizedBox(height: 6),
          Text(
            '全部账本汇总',
            style: TextStyle(
              fontSize: AppTypography.chip,
              color: c.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

/// 「当日明细」标题行 + 「全部 >」。
class _DayListHeader extends StatelessWidget {
  const _DayListHeader({required this.onTapAll});

  final VoidCallback onTapAll;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Text(
            '当日明细',
            style: TextStyle(
              fontSize: 16,
              fontWeight: AppTypography.semiBold,
              color: c.ink,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onTapAll,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(
                  '全部',
                  style: TextStyle(
                    fontSize: AppTypography.txnNote,
                    color: c.ink2,
                  ),
                ),
                Icon(Icons.chevron_right, size: 14, color: c.ink2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 当日明细列表。
class _DayList extends StatelessWidget {
  const _DayList({required this.stats});

  final HomeStats stats;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    if (stats.todayTxns.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: EmptyView(
          icon: Icons.receipt_long_outlined,
          iconSize: 32,
          message: '当日暂无交易记录',
        ),
      );
    }

    final now = DateTime.now();

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              '今天 · ${now.month}月${now.day}日 ${weekdayCn(now)}',
              style: TextStyle(
                fontSize: AppTypography.txnNote,
                color: c.ink2,
              ),
            ),
          ),
          for (final txn in stats.todayTxns)
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

/// 空态引导卡（本月无任何收支时展示）。
class _EmptyGuide extends StatefulWidget {
  const _EmptyGuide({required this.hasAnyTxn});

  /// 本账本历史是否记过账（区分「全新用户」与「本月恰好没记账」）。
  final bool hasAnyTxn;

  @override
  State<_EmptyGuide> createState() => _EmptyGuideState();
}

class _EmptyGuideState extends State<_EmptyGuide> {
  /// 示例数据载入中（防连点重复写入）。
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return AppCard(
      child: EmptyView(
        message: widget.hasAnyTxn ? '本月还没有记录' : '还没有任何记录',
        subtitle: '记下第一笔，或先载入示例数据看看效果',
        actionLabel: '记一笔',
        onAction: () => Navigator.of(context).pushNamed(AppRoutes.addTx),
        secondaryLabel: '载入示例数据',
        onSecondary: _loading ? null : () => _loadSample(appState),
      ),
    );
  }

  /// 载入示例数据：防重入 + 已载入过则提示 + 异常兜底。
  Future<void> _loadSample(AppState appState) async {
    if (_loading) return;
    // 已载入过 → 不重复写入（避免示例数据翻倍）
    final loaded = await appState.prefRepo.sampleLoaded();
    if (!mounted) return;
    if (loaded) {
      AppToast.show('示例数据已载入，可在「我的 → 账本与分类」清空后重载');
      return;
    }
    setState(() => _loading = true);
    try {
      final inserted = await appState.txnRepo.loadSampleData(appState.bookId);
      if (inserted > 0) {
        await appState.prefRepo.setSampleLoaded(true);
        appState.bumpData();
      }
      if (!mounted) return;
      AppToast.show(inserted > 0 ? '已载入 $inserted 笔示例数据' : '示例数据载入失败');
    } catch (e) {
      debugPrint('loadSampleData failed: $e');
      if (!mounted) return;
      AppToast.show('载入失败，请稍后重试', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

/// 加载中的骨架占位（避免数字从 0 跳到真实值）。
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBar(width: 80, height: 12, color: c.track),
              const SizedBox(height: 14),
              _SkeletonBar(width: 180, height: 30, color: c.track),
              const SizedBox(height: 14),
              _SkeletonBar(width: 240, height: 12, color: c.track),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.pageGap),
        AppCard(
          child:
              _SkeletonBar(width: double.infinity, height: 40, color: c.track),
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

/// `¥` + 金额（不带正负号），供概览 / 今日 / 预算卡复用。
class AmountLine extends StatelessWidget {
  /// 金额（分）。
  final int amountMinor;

  /// 字号。
  final double fontSize;

  /// 文字色。
  final Color color;

  /// 是否加粗。
  final bool bold;

  const AmountLine({
    required this.amountMinor,
    required this.fontSize,
    required this.color,
    super.key,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '¥',
          style: TextStyle(
            fontSize: fontSize * 0.5,
            color: color.withValues(alpha: 0.6),
            fontFamily: AppTypography.numberFontFamily,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          fmtMoney(amountMinor),
          style: AppTypography.numberStyle(
            fontSize: fontSize,
            fontWeight: bold ? AppTypography.bold : AppTypography.semiBold,
            color: color,
          ),
        ),
      ],
    );
  }
}
