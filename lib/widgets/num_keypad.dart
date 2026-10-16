import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// 自定义数字键盘（4 行，第 4 行只有 2 键）。
///
/// ```
/// [1] [2] [3] [⌫]
/// [4] [5] [6] [ . ]
/// [7] [8] [9] [ 0]
/// [00] [    完成    ]
/// ```
/// 「完成」占约 2.02 倍宽并填充主色。
class NumKeypad extends StatelessWidget {
  /// 按下数字 / `.` / `00` 时回调（传入对应字符串）。
  final ValueChanged<String> onDigit;

  /// 退格回调。
  final VoidCallback onBackspace;

  /// 「完成」回调。
  final VoidCallback onDone;

  const NumKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onDone,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          _row(
            colors: c,
            keys: [
              _Key(label: '1', onTap: () => onDigit('1')),
              _Key(label: '2', onTap: () => onDigit('2')),
              _Key(label: '3', onTap: () => onDigit('3')),
              _Key(icon: Icons.backspace_outlined, onTap: onBackspace),
            ],
          ),
          const SizedBox(height: AppDimens.keyGap),
          _row(
            colors: c,
            keys: [
              _Key(label: '4', onTap: () => onDigit('4')),
              _Key(label: '5', onTap: () => onDigit('5')),
              _Key(label: '6', onTap: () => onDigit('6')),
              _Key(label: '.', onTap: () => onDigit('.')),
            ],
          ),
          const SizedBox(height: AppDimens.keyGap),
          _row(
            colors: c,
            keys: [
              _Key(label: '7', onTap: () => onDigit('7')),
              _Key(label: '8', onTap: () => onDigit('8')),
              _Key(label: '9', onTap: () => onDigit('9')),
              _Key(label: '0', onTap: () => onDigit('0')),
            ],
          ),
          const SizedBox(height: AppDimens.keyGap),
          // 第 4 行只有 2 键：00 + 完成（占 2.02 倍宽）
          _row(
            colors: c,
            keys: [
              _Key(label: '00', onTap: () => onDigit('00')),
              _Key(
                label: '完成',
                flex: AppDimens.keyDoneFlex.round(),
                primary: true,
                onTap: onDone,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row({required AppColors colors, required List<_Key> keys}) {
    // 注意：这里**不能**用 `CrossAxisAlignment.stretch`。
    // 键盘是页面 Column 的非 flex 子项，纵向约束为无界（h=Infinity），
    // stretch 会把无界高度直接传给按键，触发
    // 「BoxConstraints forces an infinite height」——debug 下报红屏，
    // release 下断言被剥离、布局静默崩坏，整个记一笔页白屏。
    // 按键自身已有固定高度 52，默认 center 对齐即可。
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimens.keyGap),
          Expanded(flex: keys[i].flex, child: keys[i]),
        ],
      ],
    );
  }
}

/// 单个按键。
class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  /// 宽度倍率（`Expanded.flex`，整数）。
  final int flex;
  final bool primary;

  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    this.flex = 1,
    this.primary = false,
  }) : assert(label != null || icon != null, 'label 与 icon 至少给一个');

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final bg = primary ? c.green : c.card;
    final fg = primary ? AppColors.onGreen : c.ink;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: AppDimens.keyHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDimens.keyRadius),
          boxShadow: primary
              ? null
              : [
                  BoxShadow(
                    color: c.cardShadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: icon != null
            ? Icon(icon, size: 22, color: fg)
            : Text(
                label!,
                style: primary
                    ? TextStyle(
                        fontSize: AppTypography.keyFn,
                        fontWeight: AppTypography.semiBold,
                        color: fg,
                      )
                    : AppTypography.numberStyle(
                        fontSize: AppTypography.keyNumber,
                        fontWeight: AppTypography.medium,
                        color: fg,
                      ),
              ),
      ),
    );
  }
}
