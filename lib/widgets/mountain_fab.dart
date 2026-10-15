import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 山峦两段式 FAB。
///
/// 行为与视觉严格对齐原型 `.fab`：
/// - **收起态**：整体右移 `宽 + 4`，仅左缘约 18px 探入屏幕；
///   左缘为山峦锯齿（齿尖探向屏幕内）；
/// - **展开态**：300ms 缓动展开为 114px 宽，锯齿抹平为直左缘，
///   淡入白色加号 + 「记一笔」文案；主色投影；
/// - 展开态点击 → 触发 [onTap]（跳记一笔）并收起；
/// - 展开态点击屏幕任意处 → 收起（自包含 Overlay 屏障，
///   不依赖 main_shell 改动）；
/// - 仅今日 / 日历 Tab 显示由 main_shell 控制。
class MountainFab extends StatefulWidget {
  /// 展开态点击回调（跳转记一笔页）。
  final VoidCallback onTap;

  const MountainFab({required this.onTap, super.key});

  @override
  State<MountainFab> createState() => _MountainFabState();
}

class _MountainFabState extends State<MountainFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDimens.animNormal,
    value: 0,
  );

  /// 展开态（离散状态，用于点击语义判定）。
  bool _expanded = false;

  /// 展开时的全屏屏障（点外部收起）。
  OverlayEntry? _barrierEntry;

  @override
  void dispose() {
    _removeBarrier();
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_expanded) {
      _collapse();
      widget.onTap();
    } else {
      _expand();
    }
  }

  void _expand() {
    if (_expanded) return;
    setState(() => _expanded = true);
    _controller.forward();
    _insertBarrier();
  }

  void _collapse() {
    if (!_expanded) return;
    setState(() => _expanded = false);
    _controller.reverse();
    _removeBarrier();
  }

  void _insertBarrier() {
    if (_barrierEntry != null) return;
    _barrierEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        // 屏障必须给 FAB 所在通道「留洞」：Overlay 层级高于路由内容，
        // 若整屏拦截，展开态下点 FAB 会先命中屏障（只能收起，
        // 永远打不开记一笔页）。右侧通道（右边距 + 展开宽）不挂手势，
        // 命中自然穿透到下层的 FAB。
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _collapse,
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(
              width: AppDimens.fabRight + AppDimens.fabExpandedWidth,
            ),
          ],
        ),
      ),
    );
    Overlay.maybeOf(context)?.insert(_barrierEntry!);
  }

  void _removeBarrier() {
    _barrierEntry?.remove();
    _barrierEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 与原型同一缓动曲线
        final t = AppDimens.slideCurve.transform(_controller.value);
        final width = lerpDouble(AppDimens.fabSize, AppDimens.fabExpandedWidth, t)!;
        // 收起态右移「宽 + 4」，左缘约 18px 探入屏幕
        final offsetX = lerpDouble(AppDimens.fabSize + 4, 0, t)!;

        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: GestureDetector(
            onTap: _handleTap,
            child: Container(
              width: width,
              height: AppDimens.fabSize,
              decoration: BoxDecoration(
                color: c.green,
                boxShadow: [
                  BoxShadow(
                    color: c.fabShadow,
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipPath(
                clipper: _MountainClipper(t),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 加号与文案随展开淡入（收起态探出部分看不到）
                    Opacity(
                      opacity: t,
                      child: const Icon(Icons.add, size: 24, color: AppColors.onGreen),
                    ),
                    if (t > 0) ...[
                      SizedBox(width: 7 * t),
                      Opacity(
                        opacity: t,
                        child: const Text(
                          '记一笔',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 山峦锯齿裁剪器。
///
/// 收起态（progress = 0）左缘为 8 齿锯齿（齿深 24%），
/// 展开态（progress = 1）齿深归零、左缘抹平——与原型两个
/// 点数一致的 polygon 对应，可随动画平滑过渡。
class _MountainClipper extends CustomClipper<Path> {
  const _MountainClipper(this.progress);

  /// 0 = 收起（锯齿最深），1 = 展开（左缘平直）。
  final double progress;

  @override
  Path getClip(Size size) {
    final toothDepth = 0.24 * (1 - progress);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height);

    // 自下往上沿左缘走 8 个齿（y 从 .88 到 .04，偶数齿贴边、奇数齿探入）
    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.88 - 0.12 * i);
      final x = size.width * (i.isEven ? 0 : toothDepth);
      path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _MountainClipper old) => old.progress != progress;
}
