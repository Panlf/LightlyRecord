import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// 弹窗 / 面板统一套件（自绘，保证主题 Token 生效、样式全局一致）。
///
/// **为什么不用系统 `AlertDialog`**：Material 3 的默认弹窗会在输入框下
/// 留一条下划线、在按钮区上方留一条分割线（就是那个"下面两条横线"），
/// 与全 App 的圆角卡片语言冲突。这里统一自绘：
/// - 圆角 28、卡片底色、无表面着色（surfaceTint）；
/// - 圆角填充输入框（无下划线）；
/// - 两枚 46px 胶囊按钮（取消灰底 / 确定主色）；
/// - 底部面板统一圆角浮层 + 顶部小横条。
class AppDialog {
  const AppDialog._();

  // ---------------------------------------------------------------- 输入弹窗

  /// 输入弹窗（改昵称 / 新建账本 / 重命名账本）。
  ///
  /// 返回用户输入（已 `trim()` 前的原文），取消返回 `null`。
  static Future<String?> showInput(
    BuildContext context, {
    required String title,
    String hint = '',
    String initial = '',
    int maxLength = 20,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _InputDialog(
        title: title,
        hint: hint,
        initial: initial,
        maxLength: maxLength,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
  }

  // ---------------------------------------------------------------- 底部面板

  /// 通用底部面板：圆角浮层 + 顶部小横条 + 可选标题 + 选项行。
  ///
  /// 选项行自行 `Navigator.pop(value)`，返回值透传给调用方。
  static Future<T?> showSheet<T>(
    BuildContext context, {
    String? title,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final c = Theme.of(sheetContext).extension<AppColors>()!;
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;

        return SafeArea(
          child: Container(
            margin:
                const EdgeInsets.symmetric(horizontal: AppDimens.pageMargin),
            padding: EdgeInsets.fromLTRB(
              AppDimens.cardPadding,
              10,
              AppDimens.cardPadding,
              AppDimens.cardPadding + bottomInset,
            ),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _SheetHandle(colors: c)),
                if (title != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTypography.cardTitle,
                      fontWeight: AppTypography.semiBold,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                ] else
                  const SizedBox(height: 6),
                ...children,
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- 日期选择

  /// 主题化日期选择器（去掉 Material 3 默认分割线，配色跟随 Token）。
  static Future<DateTime?> showDate(
    BuildContext context, {
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) {
    final c = Theme.of(context).extension<AppColors>()!;
    final base = Theme.of(context);

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
      builder: (context, child) => Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            primary: c.green,
            onPrimary: AppColors.onGreen,
            surface: c.card,
            onSurface: c.ink,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: c.card,
            surfaceTintColor: AppColors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.dialogRadius),
            ),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: c.card,
            surfaceTintColor: AppColors.transparent,
            // 关键：去掉日历头部与按钮区的默认分割线
            dividerColor: AppColors.transparent,
            headerBackgroundColor: c.green,
            headerForegroundColor: AppColors.onGreen,
            todayBackgroundColor: WidgetStateProperty.all(c.greenLight),
            todayForegroundColor: WidgetStateProperty.all(c.greenDeep),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.dialogRadius),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: c.green),
          ),
        ),
        child: child!,
      ),
    );
  }

  // ---------------------------------------------------------------- 输入框装饰

  /// 圆角填充输入框装饰（无下划线，供底部面板内的表单复用）。
  static InputDecoration fieldDecoration(
    BuildContext context, {
    String? hintText,
    String? labelText,
  }) {
    final c = Theme.of(context).extension<AppColors>()!;
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      hintStyle: TextStyle(fontSize: AppTypography.body, color: c.ink3),
      labelStyle: TextStyle(fontSize: AppTypography.body, color: c.ink2),
      floatingLabelStyle: TextStyle(fontSize: AppTypography.body, color: c.green),
      counterText: '',
      filled: true,
      fillColor: c.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c.green, width: 1.5),
      ),
    );
  }
}

/// 弹窗胶囊按钮（取消 / 确定）。
class AppDialogButton extends StatelessWidget {
  /// 构造弹窗按钮。
  const AppDialogButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color background;
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

/// 底部面板选项行（图标 + 主文案 + 副文案，圆角点击区、无分割线）。
class AppSheetOption extends StatelessWidget {
  /// 构造选项行。
  const AppSheetOption({
    required this.label,
    required this.onTap,
    this.icon,
    this.desc,
    this.color,
    super.key,
  });

  final String label;
  final IconData? icon;
  final String? desc;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final effective = color ?? c.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.segItemRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: effective),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppTypography.segLabel,
                      fontWeight: AppTypography.medium,
                      color: effective,
                    ),
                  ),
                  if (desc != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc!,
                      style: TextStyle(
                        fontSize: AppTypography.txnNote,
                        color: c.ink2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部面板顶部小横条。
class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: colors.track2,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// 输入弹窗主体（自绘，无下划线、无分割线）。
class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.maxLength,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String hint;
  final String initial;
  final int maxLength;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
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
                maxLength: widget.maxLength,
                cursorColor: c.green,
                style: TextStyle(fontSize: AppTypography.body, color: c.ink),
                decoration: AppDialog.fieldDecoration(
                  context,
                  hintText: widget.hint,
                ),
                onSubmitted: (value) => Navigator.of(context).pop(value),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AppDialogButton(
                      label: widget.cancelLabel,
                      foreground: c.ink2,
                      background: c.track,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDialogButton(
                      label: widget.confirmLabel,
                      foreground: AppColors.onGreen,
                      background: c.green,
                      onTap: () => Navigator.of(context).pop(_controller.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
