import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/model/book.dart';
import '../../icons/app_icons.dart';
import '../../repository/stats_repository.dart';
import '../../state/app_state.dart';
import '../../state/book_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_view.dart';

/// 账本页：账本列表 + 新建 + 长按管理 + 本账本统计卡。
///
/// 所有数字来自 [BookController] → Repository / StatsRepository，
/// 页面内不写 SQL、不做金额运算。
class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  /// 页面级 Controller 引用（initState 取出，供 dispose 反注册用）。
  late final BookController _controller;

  @override
  void initState() {
    super.initState();
    // 注册 dataVersion / 账本监听：记一笔、切换账本、载入示例数据后
    // 账本页选中态与统计卡在同一帧重算。
    // （MainShell 的 5 个 Tab 由 IndexedStack 常驻，页面不会被反复
    // 创建，因此监听放在 initState / dispose 这一对里最稳。）
    _controller = context.read<BookController>();
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
    final controller = context.watch<BookController>();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(
            left: AppDimens.pageMargin,
            right: AppDimens.pageMargin,
            top: 6,
            bottom: AppDimens.tabBarHeight + 24,
          ),
          children: [
            // 页头：标题 + 总数
            SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '我的账本',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: AppTypography.semiBold,
                      color: c.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '共 ${controller.books.length} 个',
                    style: TextStyle(
                      fontSize: AppTypography.txnNote,
                      color: c.ink3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.pageGap),

            // 加载失败：错误提示 + 重试（避免无数据的静默空白）
            if (controller.stats == null && controller.error != null) ...[
              AppCard(
                child: EmptyView(
                  message: controller.error!,
                  subtitle: '点击重试',
                  icon: Icons.cloud_off_outlined,
                  actionLabel: '重试',
                  onAction: () => controller.load(force: true),
                ),
              ),
              const SizedBox(height: AppDimens.pageGap),
            ],

            // 账本列表
            for (final book in controller.books) ...[
              _BookRow(
                book: book,
                isCurrent: book.id == appState.bookId,
                txnCount: controller.txnCounts[book.id] ?? 0,
                totalExpenseMinor: controller.totalExpense[book.id] ?? 0,
                lastUpdatedAt: controller.lastUpdatedAt[book.id],
                onTap: () => _onBookTap(controller, book.id, book.name),
                onLongPress: book.isDefault
                    ? null
                    : () => _onBookManage(controller, book),
              ),
              const SizedBox(height: AppDimens.cardGap),
            ],

            // 虚线「新建账本」
            _NewBookButton(onTap: () => _onCreateBook(controller)),
            const SizedBox(height: AppDimens.pageGap),

            // 本账本统计卡
            _BookStatsCard(stats: controller.stats),
          ],
        ),
      ),
    );
  }

  /// 点账本行：当前本Toast提示；其他本切换。
  Future<void> _onBookTap(BookController controller, int id, String name) async {
    if (id == context.read<AppState>().bookId) {
      AppToast.show('当前正在使用：$name');
      return;
    }
    await controller.switchBook(id);
    if (!mounted) return;
    AppToast.show('已切换至：$name');
  }

  /// 长按非默认账本 → 管理弹窗（重命名 / 删除）。
  Future<void> _onBookManage(BookController controller, Book book) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final c = Theme.of(sheetContext).extension<AppColors>()!;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppDimens.pageMargin),
            padding: const EdgeInsets.all(AppDimens.cardPadding),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.track2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppDimens.pageGap),
                Text(
                  book.name,
                  style: TextStyle(
                    fontSize: AppTypography.cardTitle,
                    fontWeight: AppTypography.semiBold,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: AppDimens.pageGap),
                _SheetAction(
                  icon: Icons.edit_outlined,
                  label: '重命名',
                  color: c.ink,
                  onTap: () => Navigator.pop(sheetContext, 'rename'),
                ),
                _SheetAction(
                  icon: Icons.delete_outline,
                  label: '删除账本',
                  color: c.red,
                  onTap: () => Navigator.pop(sheetContext, 'delete'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) return;

    if (action == 'rename') {
      await _showNameDialog(
        title: '重命名账本',
        initial: book.name,
        onConfirm: (value) => controller.renameBook(book.id, value),
      );
    } else if (action == 'delete') {
      final count = controller.txnCounts[book.id] ?? 0;
      final ok = await ConfirmDialog.show(
        context,
        title: '删除账本「${book.name}」？',
        message: count > 0 ? '账本内 $count 笔交易将一并删除，不可恢复' : '删除后不可恢复',
        confirmLabel: '删除',
      );
      if (!ok || !mounted) return;
      final error = await controller.deleteBook(book.id);
      if (!mounted) return;
      AppToast.show(error ?? '已删除账本「${book.name}」', error: error != null);
    }
  }

  /// 新建账本：名称对话框 → 创建并切换。
  Future<void> _onCreateBook(BookController controller) async {
    await _showNameDialog(
      title: '新建账本',
      initial: '',
      onConfirm: (value) => controller.createBook(value),
      successMessage: (value) => '已创建并切换至：$value',
    );
  }

  /// 通用名称输入对话框。
  ///
  /// [onConfirm] 返回 `null` 表示成功，否则为错误文案（Toast 且不关闭）。
  Future<void> _showNameDialog({
    required String title,
    required String initial,
    required Future<String?> Function(String) onConfirm,
    String Function(String)? successMessage,
  }) async {
    final textController = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {        final c = Theme.of(dialogContext).extension<AppColors>()!;
        return AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.dialogRadius),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: AppTypography.cardTitle,
              fontWeight: AppTypography.semiBold,
              color: c.ink,
            ),
          ),
          content: TextField(
            controller: textController,
            autofocus: true,
            maxLength: 20,
            style: TextStyle(fontSize: AppTypography.segLabel, color: c.ink),
            cursorColor: c.green,
            decoration: InputDecoration(
              hintText: '请输入账本名称',
              hintStyle: TextStyle(color: c.ink3),
              counterText: '',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: c.green),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消', style: TextStyle(color: c.ink2)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, textController.text),
              child: Text(
                '确定',
                style: TextStyle(
                  color: c.green,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
            ),
          ],
        );
      },
    );
    // 对话框已关闭，及时释放控制器
    textController.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    final error = await onConfirm(name.trim());
    if (!mounted) return;
    if (error != null) {
      AppToast.show(error, error: true);
      return;
    }
    AppToast.show(successMessage?.call(name.trim()) ?? '已保存');
  }
}

/// 账本行：图标 + 名称（使用中标签）+ 副标题 + 金额；当前本 2px 主色描边。
class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.book,
    required this.isCurrent,
    required this.txnCount,
    required this.totalExpenseMinor,
    required this.lastUpdatedAt,
    required this.onTap,
    this.onLongPress,
  });

  final Book book;
  final bool isCurrent;
  final int txnCount;
  final int totalExpenseMinor;
  final int? lastUpdatedAt;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    // 账本图标色属于数据色（DB 值），经 format.hexToColor 解析
    final iconColor = hexToColor(book.iconColor);

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          // 当前账本 2px 主色描边（选中态）
          border: isCurrent ? Border.all(color: c.green, width: 2) : null,
        ),
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            // 44×44 圆角 14 图标（数据色淡化底 + 数据色图标）
            Container(
              width: AppDimens.bookIconSize,
              height: AppDimens.bookIconSize,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimens.bookIconRadius),
              ),
              alignment: Alignment.center,
              child: Icon(
                AppIcons.of(book.iconKey),
                size: 22,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          book.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTypography.txnName,
                            fontWeight: AppTypography.medium,
                            color: c.ink,
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        const _CurrentTag(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(),
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
            const SizedBox(width: 8),
            Text(
              fmtMoney(totalExpenseMinor),
              style: TextStyle(
                fontSize: AppTypography.txnAmount,
                fontWeight: AppTypography.semiBold,
                color: isCurrent ? c.ink : c.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 副标题：「N 笔 · 更新于 M月d日」，无交易时只显示「N 笔」。
  String _subtitle() {
    final at = lastUpdatedAt;
    if (at == null || at <= 0) return '$txnCount 笔';
    final d = DateTime.fromMillisecondsSinceEpoch(at);
    return '$txnCount 笔 · 更新于 ${d.month}月${d.day}日';
  }
}

/// 「使用中」标签（10px，主色淡化底 + 主色字）。
class _CurrentTag extends StatelessWidget {
  const _CurrentTag();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.greenLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '使用中',
        style: TextStyle(
          fontSize: AppTypography.tagCur,
          fontWeight: AppTypography.medium,
          color: c.greenDeep,
        ),
      ),
    );
  }
}

/// 虚线「新建账本」按钮。
class _NewBookButton extends StatelessWidget {
  const _NewBookButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          border: Border.all(color: c.dashed, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: c.green),
            const SizedBox(width: 6),
            Text(
              '新建账本',
              style: TextStyle(
                fontSize: AppTypography.segLabel,
                fontWeight: AppTypography.medium,
                color: c.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 账本统计卡（带「本账本」标签）：总笔数 / 累计支出 / 连续打卡。
class _BookStatsCard extends StatelessWidget {
  const _BookStatsCard({required this.stats});

  final BookStats? stats;

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
                '账本统计',
                style: TextStyle(
                  fontSize: AppTypography.cardTitle,
                  fontWeight: AppTypography.medium,
                  color: c.ink,
                ),
              ),
              const SizedBox(width: 8),
              const _ScopeTag(label: '本账本'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatCell(value: '${stats?.count ?? 0}', label: '总笔数'),
              _StatCell(
                value: fmtMoney(stats?.totalExpense ?? 0),
                label: '累计支出',
              ),
              _StatCell(
                value: '${stats?.streakDays ?? 0}',
                label: '连续打卡(天)',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 「本账本 / 全部」口径标签（避免两处统计数字混淆）。
class _ScopeTag extends StatelessWidget {
  const _ScopeTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.track,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.tagCur,
          color: c.ink2,
        ),
      ),
    );
  }
}

/// 三宫格统计单元。
class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: AppTypography.gaugeValue,
              fontWeight: AppTypography.semiBold,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.txnNote,
              color: c.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 管理弹窗操作行。
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.segItemRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.segLabel,
                fontWeight: AppTypography.medium,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
