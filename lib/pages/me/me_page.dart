import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/format.dart';
import '../../icons/app_icons.dart';
import '../../repository/pref_repository.dart';
import '../../router/app_routes.dart';
import '../../state/app_state.dart';
import '../../state/me_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';
import '../../utils/export_service.dart';
import '../../widgets/about_dialog.dart' as about;
import '../../widgets/app_card.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_view.dart';

/// 我的页：用户卡（全局口径统计）+ 菜单六项 + 版本行。
///
/// 口径约定：本页三宫格带「全部」标签（跨全部账本），与账本页
/// 统计卡的「本账本」标签区分，两处数字不再矛盾。
class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  /// 版本行（`package_info_plus` 真实版本，异步加载）。
  String _versionLine = '…';

  /// 页面级 Controller 引用（initState 取出，供 dispose 反注册用）。
  late final MeController _controller;

  @override
  void initState() {
    super.initState();
    // 注册 dataVersion 监听：记一笔 / 编辑 / 删除 / 切账本后我的页
    // 全局统计在同一帧重算。
    // （MainShell 的 5 个 Tab 由 IndexedStack 常驻，页面不会被反复
    // 创建，因此监听放在 initState / dispose 这一对里最稳。）
    _controller = context.read<MeController>();
    _controller.attach();
    // 首帧后加载；Controller 自身有 isStale 去重，重复调用无副作用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.load(force: true);
      _loadVersion();
    });
  }

  @override
  void dispose() {
    _controller.detach();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final line = await AppConfig.versionLine();
    if (!mounted) return;
    setState(() => _versionLine = line);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final appState = context.watch<AppState>();
    final controller = context.watch<MeController>();
    final stats = controller.stats;

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
            // 用户卡：头像 + 昵称 + 坚持天数 + 全局三宫格
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 56px 头像（主色淡化底 + 主色图标）
                      Container(
                        width: AppDimens.avatarSize,
                        height: AppDimens.avatarSize,
                        decoration: BoxDecoration(
                          color: c.greenLight,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.person_outline,
                            size: 28, color: c.greenDeep),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              appState.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: AppTypography.semiBold,
                                color: c.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '已坚持记账 ${stats?.persistDays ?? 0} 天',
                              style: TextStyle(
                                fontSize: AppTypography.txnNote,
                                color: c.ink2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 编辑昵称入口
                      InkWell(
                        onTap: _onEditNickname,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.chevron_right, size: 20, color: c.ink3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 全局三宫格（带「全部」口径标签）
                  Row(
                    children: [
                      _StatCell(
                        value: '${stats?.totalCount ?? 0}',
                        label: '总笔数',
                      ),
                      _StatCell(
                        value: '${stats?.bookCount ?? 0}',
                        label: '账本',
                      ),
                      _StatCell(
                        value: '${stats?.streakDays ?? 0}',
                        label: '连续打卡(天)',
                        valueColor: c.green,
                      ),
                      const _ScopeTag(label: '全部'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.pageGap),

            // 加载失败：错误提示 + 重试
            if (controller.stats == null && controller.error != null)
              AppCard(
                child: EmptyView(
                  message: controller.error!,
                  subtitle: '点击重试',
                  icon: Icons.cloud_off_outlined,
                  actionLabel: '重试',
                  onAction: () => controller.load(force: true),
                ),
              ),

            // 菜单六项（顺序严格对齐架构文档 §T05）
            _MenuRow(
              iconKey: 'wallet',
              colorHex: AppIcons.colorPalette[0].hex,
              label: '预算管理',
              onTap: () => Navigator.pushNamed(context, AppRoutes.budget),
            ),
            _MenuRow(
              iconKey: 'book',
              colorHex: AppIcons.colorPalette[1].hex,
              label: '账本与分类',
              onTap: () => Navigator.pushNamed(context, AppRoutes.category),
            ),
            _MenuRow(
              iconKey: 'download',
              colorHex: AppIcons.colorPalette[2].hex,
              label: '数据导出',
              onTap: _onExport,
            ),
            _MenuRow(
              iconKey: 'bell',
              colorHex: AppIcons.colorPalette[3].hex,
              label: '记账提醒',
              onTap: () => AppToast.show('记账提醒将在后续版本开放'),
            ),
            _MenuRow(
              iconKey: 'palette',
              colorHex: AppIcons.colorPalette[4].hex,
              label: '主题外观',
              onTap: () => Navigator.pushNamed(context, AppRoutes.theme),
            ),
            _MenuRow(
              iconKey: 'info',
              colorHex: AppIcons.colorPalette[5].hex,
              label: '关于轻记',
              onTap: () => about.AboutDialog.show(context),
            ),

            // 版本行（真实版本号，禁写死）
            const SizedBox(height: AppDimens.pageGap),
            Center(
              child: Text(
                '轻记 v$_versionLine · 让记账更简单',
                style: TextStyle(
                  fontSize: AppTypography.txnNote,
                  color: c.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 编辑昵称：落盘 pref + 广播 AppState（首页问候语联动）。
  Future<void> _onEditNickname() async {
    final appState = context.read<AppState>();
    final controller = TextEditingController(text: appState.nickname);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {        final c = Theme.of(dialogContext).extension<AppColors>()!;
        return AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.dialogRadius),
          ),
          title: Text(
            '修改昵称',
            style: TextStyle(
              fontSize: AppTypography.cardTitle,
              fontWeight: AppTypography.semiBold,
              color: c.ink,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 12,
            style: TextStyle(fontSize: AppTypography.segLabel, color: c.ink),
            cursorColor: c.green,
            decoration: InputDecoration(
              hintText: '请输入昵称',
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
              onPressed: () => Navigator.pop(dialogContext, controller.text),
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
    controller.dispose();
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty || !mounted) return;
    await appState.prefRepo.setNickname(trimmed);
    appState.refreshNickname(trimmed);
    AppToast.show('昵称已更新');
  }

  /// 数据导出：选格式 → Repository 取数 → 生成 → 落盘 → 分享（失败降级）。
  Future<void> _onExport() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final c = Theme.of(sheetContext).extension<AppColors>()!;
        return SafeArea(
          child: Container(
            margin:
                const EdgeInsets.symmetric(horizontal: AppDimens.pageMargin),
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
                  '导出数据',
                  style: TextStyle(
                    fontSize: AppTypography.cardTitle,
                    fontWeight: AppTypography.semiBold,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: AppDimens.pageGap),
                _ExportOption(
                  label: 'CSV 表格',
                  desc: '可用 Excel 直接打开',
                  onTap: () => Navigator.pop(sheetContext, 'csv'),
                ),
                _ExportOption(
                  label: 'JSON 文件',
                  desc: '含全部账本 / 分类 / 交易字段',
                  onTap: () => Navigator.pop(sheetContext, 'json'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (format == null || !mounted) return;

    final appState = context.read<AppState>();
    AppToast.show('正在导出…', duration: const Duration(seconds: 5));

    // 取数统一走 Repository（页面禁止接触 DAO）
    final txns = await appState.txnRepo.listAll();
    final books = await appState.bookRepo.list();
    final categories = await appState.categoryRepo.list();

    // 序列化放 isolate，1000 笔以上不卡 UI
    final content = await ExportService.buildContent(
      format: format,
      books: books,
      categories: categories,
      txns: txns,
    );
    if (!mounted) return;

    final result = await ExportService.saveToFile(
      ExportService.defaultFileName(format),
      content,
    );
    if (!mounted) return;
    if (result.isFailure) {
      AppToast.show(result.messageOrNull ?? '导出失败', error: true);
      return;
    }
    final path = result.valueOrNull!;
    final shared = await ExportService.shareFile(path);
    if (!mounted) return;
    // 分享取消 / 失败都不算错误：降级提示保存路径
    AppToast.show(shared ? '已导出 ${txns.length} 笔交易' : '已保存到：$path');
  }
}

/// 菜单行：彩色图标瓦片 + 名称 + 右箭头。
///
/// 图标配色取自 [AppIcons.colorPalette]（数据色板，与分类 /
/// 账本数据色同源，非主题 Token），按菜单项固定分配。
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.iconKey,
    required this.colorHex,
    required this.label,
    required this.onTap,
  });

  final String iconKey;
  final String colorHex;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final color = hexToColor(colorHex);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(AppIcons.of(iconKey), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.segLabel,
              fontWeight: FontWeight.w500,
              color: c.ink,
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right, size: 18, color: c.ink3),
        ],
      ),
    );
  }
}

/// 导出格式选项行。
class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.label,
    required this.desc,
    required this.onTap,
  });

  final String label;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.segItemRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(AppIcons.of('download'), size: 19, color: c.green),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTypography.segLabel,
                    fontWeight: AppTypography.medium,
                    color: c.ink,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: AppTypography.txnNote,
                    color: c.ink2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 三宫格统计单元（我的页版，支持值色覆盖）。
class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

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
              color: valueColor ?? c.ink,
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

/// 「全部」口径标签（与账本页「本账本」对应）。
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
