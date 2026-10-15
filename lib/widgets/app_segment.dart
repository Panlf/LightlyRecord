import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// 两种分段控件：`seg`（44px 大）/ `seg-sm`（36px 小）。
///
/// 大分段：卡片底、选中填主色白字、字号 14；
/// 小分段：`track2` 底、选中填卡片色 + 投影、字号 12 500。
/// **两种样式不可混用**（原型约定）。
class AppSegment<T> extends StatelessWidget {
  /// 候选值（顺序即展示顺序）。
  final List<T> values;

  /// 当前选中值。
  final T value;

  /// 变更回调。
  final ValueChanged<T> onChanged;

  /// 每个值对应的展示文案（与 [values] 等长）。
  final List<String> labels;

  /// 是否使用小分段样式。
  final bool small;

  const AppSegment({
    required this.values,
    required this.value,
    required this.onChanged,
    required this.labels,
    super.key,
    this.small = false,
  }) : assert(values.length == labels.length, 'values 与 labels 长度必须一致');

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final height = small ? AppDimens.segSmHeight : AppDimens.segHeight;
    final radius = small ? AppDimens.segSmRadius : AppDimens.segRadius;
    final padding = small ? AppDimens.segSmPadding : AppDimens.segPadding;
    final itemRadius = small ? AppDimens.segSmItemRadius : AppDimens.segItemRadius;

    return Container(
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: small ? c.track2 : c.card,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: _SegmentItem<T>(
                label: labels[i],
                selected: values[i] == value,
                small: small,
                radius: itemRadius,
                colors: c,
                onTap: () => onChanged(values[i]),
              ),
            ),
        ],
      ),
    );
  }
}

/// 单个分段项。
class _SegmentItem<T> extends StatelessWidget {
  final String label;
  final bool selected;
  final bool small;
  final double radius;
  final AppColors colors;
  final VoidCallback onTap;

  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.small,
    required this.radius,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final bg = selected ? (small ? c.card : c.green) : c.card.withValues(alpha: 0);
    final fg = selected ? (small ? c.ink : AppColors.onGreen) : c.ink2;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: selected && small
              ? [
                  BoxShadow(
                    color: c.softShadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: small ? AppTypography.segSmLabel : AppTypography.segLabel,
            fontWeight: small ? AppTypography.medium : AppTypography.medium,
            color: fg,
          ),
        ),
      ),
    );
  }
}
