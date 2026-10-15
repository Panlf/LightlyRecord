import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../data/model/txn.dart';
import '../data/model/tx_type.dart';
import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// 全 App 复用交易行。
///
/// 规格（严格对齐原型 `.t-item`）：
/// - 行高 58；
/// - 图标 40×40 圆角 20；
/// - 名称 15px 500；
/// - 备注 12px 单行省略；
/// - 金额 15px（支出红、收入绿、带 ±）。
class TxTile extends StatelessWidget {
  /// 分类名称。
  final String name;

  /// 备注（为空时只显示名称）。
  final String? note;

  /// 金额（分）。
  final int amountMinor;

  /// 交易类型（决定金额配色与正负号）。
  final TxType type;

  /// 图标底色 `'#RRGGBB'`。
  final String iconBgHex;

  /// 图标前景色 `'#RRGGBB'`。
  final String iconStrokeHex;

  /// 图标语义 key（或直接传 [icon]）。
  final String? iconKey;

  /// 图标 codePoint（与 [iconKey] 二选一，优先使用 [icon]）。
  final int? iconCodepoint;

  /// 点击回调。
  final VoidCallback? onTap;

  /// 右侧附加文案（如「今天 08:12」），默认空。
  final String? trailingText;

  const TxTile({
    required this.name,
    required this.amountMinor,
    required this.type,
    this.iconBgHex = AppConstants.defaultCategoryColorBg,
    this.iconStrokeHex = AppConstants.defaultCategoryColorStroke,
    this.iconKey,
    this.iconCodepoint,
    this.note,
    this.onTap,
    this.trailingText,
    super.key,
  });

  /// 由 [Txn] 模型构造（`category*` 运行时关联字段需已填充）。
  factory TxTile.fromTxn(Txn txn, {VoidCallback? onTap}) {
    return TxTile(
      name: txn.categoryName ?? '未分类',
      note: txn.note,
      amountMinor: txn.amountMinor,
      type: txn.type,
      iconBgHex: txn.categoryColorBg ?? AppConstants.defaultCategoryColorBg,
      iconStrokeHex: txn.categoryColorStroke ?? AppConstants.defaultCategoryColorStroke,
      iconCodepoint: txn.categoryIconCodepoint,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final iconBg = hexToColor(iconBgHex);
    final iconFg = hexToColor(iconStrokeHex);
    final icon = iconCodepoint != null
        ? AppIcons.fromCodepoint(iconCodepoint!)
        : AppIcons.of(iconKey);

    final amountColor = type.isIncome ? c.green : c.red;
    final noteText = (note ?? '').trim();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: AppDimens.txTileHeight,
        child: Row(
          children: [
            // 图标 40×40 圆角 20
            Container(
              width: AppDimens.txIconSize,
              height: AppDimens.txIconSize,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppDimens.txIconRadius),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: iconFg),
            ),
            const SizedBox(width: AppDimens.txGap),
            // 中部：名称 + 备注
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTypography.txnName,
                      fontWeight: AppTypography.medium,
                      color: c.ink,
                    ),
                  ),
                  if (noteText.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      noteText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.txnNote,
                        fontWeight: AppTypography.regular,
                        color: c.ink2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimens.txGap),
            // 金额
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtSigned(amountMinor, type),
                  maxLines: 1,
                  style: AppTypography.numberStyle(
                    fontSize: AppTypography.txnAmount,
                    fontWeight: AppTypography.medium,
                    color: amountColor,
                  ),
                ),
                if (trailingText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    trailingText!,
                    style: TextStyle(
                      fontSize: AppTypography.chip,
                      color: c.ink3,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
