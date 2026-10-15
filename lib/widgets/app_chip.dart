import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// 胶囊标签（默认 `greenLight` 底 / `greenDeep` 字，11px 500）。
class AppChip extends StatelessWidget {
  /// 文案。
  final String label;

  /// 文字色；缺省用主题 `greenDeep`。
  final Color? color;

  /// 底色；缺省用主题 `greenLight`。
  final Color? background;

  /// 前置图标（可选）。
  final IconData? icon;

  /// 图标尺寸，默认 12。
  final double iconSize;

  const AppChip({
    required this.label,
    super.key,
    this.color,
    this.background,
    this.icon,
    this.iconSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final fg = color ?? c.greenDeep;
    final bg = background ?? c.greenLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.numberStyle(
              fontSize: AppTypography.chip,
              fontWeight: AppTypography.medium,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
