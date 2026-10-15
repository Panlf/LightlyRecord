import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 自定义开关（关闭态用 `switchOff` Token，尺寸 48×28 / 滑块 22）。
class AppSwitch extends StatelessWidget {
  /// 当前值。
  final bool value;

  /// 变更回调。
  final ValueChanged<bool> onChanged;

  const AppSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final track = value ? c.green : c.switchOff;

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: AppDimens.switchWidth,
        height: AppDimens.switchHeight,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: AppDimens.switchKnob,
                height: AppDimens.switchKnob,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.ink.withValues(alpha: 0.14),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
