import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_typography.dart';

/// 底部胶囊导航（高 62 / 圆角 36 / 文字 10px）。
class PillTabBar extends StatelessWidget {
  /// 当前选中索引。
  final int currentIndex;

  /// 切换回调。
  final ValueChanged<int> onTap;

  const PillTabBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Container(
      width: double.infinity,
      height: AppDimens.pillHeight,
      padding: const EdgeInsets.all(AppDimens.pillPadding),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppDimens.pillRadius),
        border: Border.all(color: c.line2, width: 1),
        boxShadow: [
          BoxShadow(
            color: c.cardShadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: _PillTab(
                spec: _tabs[i],
                selected: i == currentIndex,
                colors: c,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一个 Tab 的规格。
class _TabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _TabSpec(this.label, this.icon, this.activeIcon);
}

/// 5 个 Tab（图标语义与原型 SVG 一一对应）。
const List<_TabSpec> _tabs = [
  _TabSpec('今日', Icons.format_list_bulleted, Icons.format_list_bulleted),
  _TabSpec('图表', Icons.pie_chart_outline, Icons.pie_chart),
  _TabSpec('日历', Icons.calendar_today_outlined, Icons.calendar_today),
  _TabSpec('账本', Icons.menu_book_outlined, Icons.menu_book),
  _TabSpec('我的', Icons.person_outline, Icons.person),
];

/// 单个胶囊 Tab。
class _PillTab extends StatelessWidget {
  final _TabSpec spec;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _PillTab({
    required this.spec,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDimens.animFast,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? c.green : c.card.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(AppDimens.tabRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? spec.activeIcon : spec.icon,
              size: 18,
              color: selected ? AppColors.onGreen : c.ink3,
            ),
            const SizedBox(height: 3),
            Text(
              spec.label,
              style: TextStyle(
                fontSize: AppTypography.tabLabel,
                fontWeight: AppTypography.semiBold,
                color: selected ? AppColors.onGreen : c.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
