import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// 右滑入 320ms 路由动画（对齐原型 `transition: transform .32s cubic-bezier(.32,.72,.35,1)`）。
///
/// 入场：从右侧 100% 平移进入 + 淡入；退场：反向。
class SlideRoute<T> extends PageRouteBuilder<T> {
  /// 目标页构造器。
  final WidgetBuilder builder;

  SlideRoute({
    required this.builder,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AppDimens.slideDuration,
          reverseTransitionDuration: AppDimens.slideDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppDimens.slideCurve,
              reverseCurve: AppDimens.slideCurve.flipped,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: curved,
                child: child,
              ),
            );
          },
        );
}
