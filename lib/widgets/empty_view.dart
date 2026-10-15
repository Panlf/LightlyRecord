import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// 空态组件（图标 + 文案 + 可选行动按钮）。
class EmptyView extends StatelessWidget {
  /// 主文案。
  final String message;

  /// 副文案（可选）。
  final String? subtitle;

  /// 图标；缺省用收据轮廓图标。
  final IconData icon;

  /// 图标尺寸，默认 40。
  final double iconSize;

  /// 主动作按钮文案（可选）。
  final String? actionLabel;

  /// 主动作回调。
  final VoidCallback? onAction;

  /// 次要动作按钮文案（可选，如「载入示例数据」）。
  final String? secondaryLabel;

  /// 次要动作回调。
  final VoidCallback? onSecondary;

  const EmptyView({
    required this.message,
    super.key,
    this.subtitle,
    this.icon = Icons.receipt_long_outlined,
    this.iconSize = 40,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: c.ink3),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.txnNote,
              color: c.ink3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.chip,
                color: c.ink3,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: c.green,
                foregroundColor: AppColors.onGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: AppTypography.segLabel,
                  fontWeight: AppTypography.medium,
                ),
              ),
            ),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(
                foregroundColor: c.greenDeep,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                secondaryLabel!,
                style: const TextStyle(
                  fontSize: AppTypography.body,
                  fontWeight: AppTypography.medium,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
