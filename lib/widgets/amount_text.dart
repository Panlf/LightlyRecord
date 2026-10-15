import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/model/tx_type.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// 金额文本（自动千分位 + 分转元 + 收支配色）。
class AmountText extends StatelessWidget {
  /// 金额（分）。
  final int amountMinor;

  /// 交易类型；`null` 表示中性色（用主文字色）。
  final TxType? type;

  /// 是否带 ± 前缀（按 [type] 推导）。
  final bool signed;

  /// 字号。
  final double fontSize;

  /// 字重。
  final FontWeight fontWeight;

  /// 是否使用数字字体族。
  final bool useNumberFont;

  const AmountText({
    required this.amountMinor,
    super.key,
    this.type,
    this.signed = false,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.useNumberFont = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final color = switch (type) {
      TxType.expense => c.red,
      TxType.income => c.green,
      TxType.transfer => c.ink,
      null => c.ink,
    };

    final text = (signed && type != null)
        ? fmtSigned(amountMinor, type!)
        : fmtMoneyWithSign(amountMinor);

    return Text(
      text,
      maxLines: 1,
      style: useNumberFont
          ? AppTypography.numberStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            )
          : TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            ),
    );
  }
}
