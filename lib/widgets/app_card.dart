import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 统一卡片（圆角 24 / padding 20 / 卡片色 Token）。
class AppCard extends StatelessWidget {
  /// 卡片内容。
  final Widget child;

  /// 内边距，默认 [AppDimens.cardPadding]。
  final EdgeInsetsGeometry? padding;

  /// 点击回调（为 null 时无水波纹）。
  final VoidCallback? onTap;

  /// 长按回调（为 null 时无长按手势）。
  final VoidCallback? onLongPress;

  /// 圆角，默认 [AppDimens.cardRadius]。
  final double radius;

  /// 是否显示柔和投影。
  final bool elevated;

  const AppCard({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.radius = AppDimens.cardRadius,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final content = Padding(
      padding: padding ??
          const EdgeInsets.all(AppDimens.cardPadding),
      child: child,
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: c.cardShadow,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: content,
    );

    if (onTap == null && onLongPress == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: decorated,
      );
    }
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppDimens.cardPadding),
          child: child,
        ),
      ),
    );
  }
}
