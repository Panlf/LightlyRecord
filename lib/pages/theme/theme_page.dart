import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/theme_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_toast.dart';

/// 主题外观滑入页。
///
/// 2 列网格展示 6 套预设主题预览（`AppTheme.previewTriple`），
/// 点击即切；切换由 [ThemeController.setTheme] 落库并广播，
/// 整机（含日历热度底色）立即生效，重启保持。
class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final themeController = context.watch<ThemeController>();
    final current = themeController.themeId;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 头部：返回 / 标题 / 占位
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left, size: 20),
                      label: const Text('返回'),
                      style: TextButton.styleFrom(
                        foregroundColor: c.ink2,
                        textStyle: const TextStyle(
                          fontSize: AppTypography.segLabel,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '主题外观',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: AppTypography.semiBold,
                        color: c.ink,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 64),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(
                  left: AppDimens.pageMargin,
                  right: AppDimens.pageMargin,
                  bottom: 24,
                ),
                children: [
                  // 背景配色卡：2 列主题网格
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '背景配色',
                          style: TextStyle(
                            fontSize: AppTypography.cardTitle,
                            fontWeight: AppTypography.medium,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '选择一套配色，整机界面（背景、卡片、强调色）立即生效',
                          style: TextStyle(
                            fontSize: AppTypography.txnNote,
                            color: c.ink2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // 2 列网格（6 套主题）
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: AppDimens.cardGap,
                          crossAxisSpacing: AppDimens.cardGap,
                          childAspectRatio: 1.35,
                          children: [
                            for (final id in AppThemeId.values)
                              _ThemePreviewCard(
                                id: id,
                                isCurrent: id == current,
                                onTap: () => _onPick(context, id, current),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.pageGap),
                  // 当前主题卡
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '当前主题',
                              style: TextStyle(
                                fontSize: AppTypography.cardTitle,
                                fontWeight: AppTypography.medium,
                                color: c.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CurrentThemeChip(label: current.label),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '主题选择仅影响本地展示，可随时返回此处更换',
                          style: TextStyle(
                            fontSize: AppTypography.txnNote,
                            color: c.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 点主题：已是当前主题只提示；否则切换 + Toast。
  Future<void> _onPick(
    BuildContext context,
    AppThemeId id,
    AppThemeId current,
  ) async {
    if (id == current) {
      AppToast.show('正在使用：${id.label}');
      return;
    }
    await context.read<ThemeController>().setTheme(id);
    AppToast.show('已切换主题：${id.label}');
  }
}

/// 主题预览瓦片：迷你界面（背景 / 卡片 / 轨道 / 主色条）+ 名称 + 勾选。
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.id,
    required this.isCurrent,
    required this.onTap,
  });

  final AppThemeId id;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final (bg, card, green) = AppTheme.previewTriple(id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppDimens.cardRadiusSm),
          border: isCurrent
              ? Border.all(color: c.green, width: 2)
              : Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 迷你界面预览（三段色块 + 主色条）
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 6,
                      width: 36,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 6,
                      width: 52,
                      decoration: BoxDecoration(
                        color: green,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  id.label,
                  style: TextStyle(
                    fontSize: AppTypography.catName,
                    fontWeight: AppTypography.medium,
                    color: c.ink,
                  ),
                ),
                const Spacer(),
                if (isCurrent)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: c.green,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check,
                      size: 11,
                      color: AppColors.onGreen,
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

/// 「当前主题」chip。
class _CurrentThemeChip extends StatelessWidget {
  const _CurrentThemeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.greenLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTypography.chip,
          fontWeight: AppTypography.medium,
          color: c.greenDeep,
        ),
      ),
    );
  }
}
