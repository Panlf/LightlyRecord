import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

import 'app_dialog.dart';

/// 二次确认弹窗（删除交易用）。
///
/// 标题「删除这笔记录？」+ 正文「删除后不可恢复」+ 取消 / 删除（红）。
class ConfirmDialog {
  const ConfirmDialog._();

  /// 展示删除确认弹窗，返回 `true` 表示用户确认。
  static Future<bool> showDelete(
    BuildContext context, {
    String title = '删除这笔记录？',
    String message = '删除后不可恢复',
    String confirmLabel = '删除',
    String cancelLabel = '取消',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ConfirmBody(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return result ?? false;
  }

  /// 通用确认弹窗（自定义标题 / 正文 / 按钮文案）。
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
    bool destructive = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ConfirmBody(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return result ?? false;
  }
}

/// 弹窗主体（自绘，保证主题 Token 生效）。
class _ConfirmBody extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  const _ConfirmBody({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.destructive = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final confirmColor = destructive ? AppColors.redDeep : c.green;

    return Dialog(
      backgroundColor: c.card,
      surfaceTintColor: c.card,
      insetPadding: const EdgeInsets.all(AppDimens.dialogMaskPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.dialogRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimens.dialogMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.pageTitle,
                  fontWeight: AppTypography.semiBold,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.body,
                  color: c.ink2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppDialogButton(
                      label: cancelLabel,
                      foreground: c.ink2,
                      background: c.track,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDialogButton(
                      label: confirmLabel,
                      foreground: AppColors.white,
                      background: confirmColor,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
