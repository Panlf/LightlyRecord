library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// 记一笔 / 编辑记录两个表单页共用的小组件套件。
///
/// 抽成单一文件的理由：两个页面的顶栏、备注弹窗、文字按钮**规格必须逐像素一致**，
/// 分开放最容易出现「改了一处忘了另一处」。二者都只依赖主题 Token，
/// 不涉及任何业务状态。

/// 表单页顶栏：取消 / 标题 / 保存（[onSave] 为 null 时右侧留空）。
class FormTopBar extends StatelessWidget {
  /// 构造顶栏。
  const FormTopBar({
    required this.title,
    required this.onCancel,
    this.onSave,
    this.saving = false,
    super.key,
  });

  /// 标题文案。
  final String title;

  /// 取消 / 返回回调。
  final VoidCallback onCancel;

  /// 保存回调；`null` 表示查看态（右侧不显示保存）。
  final VoidCallback? onSave;

  /// 是否保存中（置灰 + 文案变「保存中」）。
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.pageMargin),
        child: Row(
          children: [
            GestureDetector(
              onTap: onCancel,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Icon(Icons.chevron_left, size: 17, color: c.ink2),
                  Text(
                    '取消',
                    style: TextStyle(
                      fontSize: AppTypography.segLabel,
                      color: c.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: AppTypography.semiBold,
                color: c.ink,
              ),
            ),
            const Spacer(),
            if (onSave != null)
              GestureDetector(
                onTap: saving ? null : onSave,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  saving ? '保存中' : '保存',
                  style: TextStyle(
                    fontSize: AppTypography.segLabel,
                    fontWeight: AppTypography.semiBold,
                    color: saving ? c.ink3 : c.green,
                  ),
                ),
              )
            else
              const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

/// 金额卡内的文字按钮（备注 / 日期）。
class CardActionButton extends StatelessWidget {
  /// 构造文字按钮。
  const CardActionButton({
    required this.label,
    required this.onTap,
    this.icon,
    super.key,
  });

  /// 文案。
  final String label;

  /// 点击回调。
  final VoidCallback onTap;

  /// 前置图标（可选）。
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: c.ink3),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTypography.txnNote,
                color: c.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹窗按钮（取消 / 确定 两枚，规格与 [FormTopBar] 体系一致）。
class DialogActionButton extends StatelessWidget {
  /// 构造弹窗按钮。
  const DialogActionButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
    super.key,
  });

  /// 文案。
  final String label;

  /// 文字色。
  final Color foreground;

  /// 底色。
  final Color background;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.segLabel,
            fontWeight: AppTypography.medium,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

/// 备注输入弹窗。
class NoteDialog {
  const NoteDialog._();

  /// 展示备注弹窗，返回用户输入的字符串（取消返回 `null`）。
  ///
  /// [initial] 为已有备注（编辑态回显）；长度上限取
  /// [AppConstants.maxNoteLength]。
  static Future<String?> show(
    BuildContext context, {
    String initial = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _NoteDialogBody(initial: initial),
    );
  }
}

/// 备注弹窗主体（自绘，保证主题 Token 生效）。
class _NoteDialogBody extends StatefulWidget {
  const _NoteDialogBody({required this.initial});

  /// 已有备注。
  final String initial;

  @override
  State<_NoteDialogBody> createState() => _NoteDialogBodyState();
}

class _NoteDialogBodyState extends State<_NoteDialogBody> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

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
                '添加备注',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.pageTitle,
                  fontWeight: AppTypography.semiBold,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: AppConstants.maxNoteLength,
                decoration: InputDecoration(
                  hintText: '选填，最多 ${AppConstants.maxNoteLength} 字',
                  hintStyle: TextStyle(
                    fontSize: AppTypography.body,
                    color: c.ink3,
                  ),
                  filled: true,
                  fillColor: c.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(fontSize: AppTypography.body, color: c.ink),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DialogActionButton(
                      label: '取消',
                      foreground: c.ink2,
                      background: c.track,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DialogActionButton(
                      label: '确定',
                      foreground: AppColors.onGreen,
                      background: c.green,
                      onTap: () =>
                          Navigator.of(context).pop(_controller.text.trim()),
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
