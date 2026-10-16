import 'dart:async' show Timer;

import 'package:flutter/material.dart';

import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// Overlay 自绘 Toast。
///
/// 用法：`AppToast.show('已保存')`；错误类文案建议传 [error] 以使用 2.4s 时长。
class AppToast {
  const AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// 展示 Toast。
  ///
  /// [message] 文案；[duration] 自定义时长（默认普通 2s，错误 2.4s）；
  /// [error] 为 true 时使用错误时长与红色调。
  static void show(
    String message, {
    Duration? duration,
    bool error = false,
  }) {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      return;
    }
    _dismiss();

    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        error: error,
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(
      duration ?? (error ? AppDimens.toastErrorDuration : AppDimens.toastDuration),
      _dismiss,
    );
  }

  /// 立即隐藏。
  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

/// Toast 本体（自绘，无第三方依赖）。
class _ToastWidget extends StatelessWidget {
  final String message;
  final bool error;

  const _ToastWidget({required this.message, required this.error});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final mq = MediaQuery.of(context);

    // 跟随当前主题的主色：成功态取主题绿，错误态取红。
    // 以前用 c.ink（近黑），跟页面主题完全脱钩，深色/浅色主题下都显得脏。
    final base = error ? c.red : c.green;

    return Positioned(
      left: 48,
      right: 48,
      // 键盘弹出时随 inset 上移，避免 Toast 浮在自定义键盘上挡按键
      bottom: mq.size.height * 0.28 + mq.viewInsets.bottom,
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - t)),
                child: child,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(AppDimens.toastRadius),
                boxShadow: [
                  BoxShadow(
                    color: base.withValues(alpha: 0.26),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    error ? Icons.error_outline : Icons.check_circle_outline,
                    size: 15,
                    color: AppColors.onGreen,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        // 不带任何 decoration：这里以前混进来过下划线，
                        // 在深色底上看着就是文字下面两条横线。
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.w500,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
