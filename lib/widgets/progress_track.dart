import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 进度条（6px / 8px 两档，超支转红）。
class ProgressTrack extends StatelessWidget {
  /// 进度 0~1（>1 会被裁剪到 1）。
  final double value;

  /// 高度：6（细）或 8（粗）。
  final double height;

  /// 进度色；缺省用主题主色，超支时用 `redDeep`。
  final Color? color;

  /// 是否超支（为 true 时进度条转红）。
  final bool over;

  const ProgressTrack({
    required this.value,
    super.key,
    this.height = AppDimens.trackThin,
    this.color,
    this.over = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final ratio = value.isNaN ? 0.0 : (value < 0 ? 0.0 : (value > 1 ? 1.0 : value));
    final barColor = over ? AppColors.redDeep : (color ?? c.green);
    final radius = height >= AppDimens.trackThick
        ? AppDimens.trackRadiusThick
        : AppDimens.trackRadiusThin;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(color: c.track),
          ),
          FractionallySizedBox(
            widthFactor: ratio,
            child: Container(
              height: height,
              decoration: BoxDecoration(color: barColor),
            ),
          ),
        ],
      ),
    );
  }
}
