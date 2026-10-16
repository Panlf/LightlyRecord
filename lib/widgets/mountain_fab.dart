import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 波浪两段式 FAB（记一笔入口）。
///
/// 行为与视觉：
/// - **收起态**：整体右移，仅左缘约 26px 探入屏幕；左缘是一条平滑的
///   **波浪**（由 [_FabPainter] 自绘，上下两个波峰），取代原来的方角矩形；
/// - **展开态**：300ms 缓动展开为 114px 宽，波浪抹平、四角化成 27px
///   大圆角胶囊，淡入白色加号 + 「记一笔」文案；主色投影跟随轮廓；
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
        final width =
            lerpDouble(AppDimens.fabSize, AppDimens.fabExpandedWidth, t)!;
        // 收起态右移，左缘约 26px 探入屏幕
        final offsetX = lerpDouble(AppDimens.fabPeekOffset, 0, t)!;

        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: GestureDetector(
            onTap: _handleTap,
            child: CustomPaint(
              painter: _FabPainter(
                color: c.green,
                shadow: c.fabShadow,
                progress: t,
              ),
              child: SizedBox(
                width: width,
                height: AppDimens.fabSize,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 加号与文案随展开淡入（收起态探出部分看不到）
                    Opacity(
                      opacity: t,
                      child: const Icon(Icons.add,
                          size: 24, color: AppColors.onGreen),
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

/// FAB 轮廓绘制器：主色填充 + 柔和投影，形状随展开进度插值。
///
/// - `progress = 0`（收起）：四角无圆角，左缘为 [AppDimens.fabWaveCycles]
///   个周期的余弦波浪（振幅 [AppDimens.fabWaveAmplitude]）；
/// - `progress = 1`（展开）：波浪振幅归零、四角变成 [AppDimens.fabRadius]
///   圆角 → 胶囊。
///
/// 用自绘而不是 `ClipPath` 的理由：投影必须**跟着轮廓**走。若用外层
/// Container 画投影 + 内层裁剪主色块，被波浪裁掉的区域仍会残留投影，
/// 边缘出现一圈脏阴影。
class _FabPainter extends CustomPainter {
  const _FabPainter({
    required this.color,
    required this.shadow,
    required this.progress,
  });

  /// 主色填充。
  final Color color;

  /// 投影色。
  final Color shadow;

  /// 0 = 收起（波浪最深），1 = 展开（胶囊）。
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // 投影：轮廓下方 8px、模糊 10（等价于 BoxShadow blurRadius 20）
    canvas.save();
    canvas.translate(0, 8);
    canvas.drawPath(
      path,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.restore();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FabPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.shadow != shadow;

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    final amp = AppDimens.fabWaveAmplitude * (1 - progress);
    final r = AppDimens.fabRadius * progress;

    final p = Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0);
    if (r > 0) {
      p.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    }
    p.lineTo(w, h - r);
    if (r > 0) {
      p.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));
    }
    p.lineTo(r, h);
    if (r > 0) {
      p.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
    }

    // 左缘波浪：自下而上采样，保证上下端点与圆角衔接
    const steps = 44;
    final top = r;
    final bottom = h - r;
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      final y = bottom + (top - bottom) * u;
      final x =
          amp * (1 - math.cos(2 * math.pi * AppDimens.fabWaveCycles * u)) / 2;
      p.lineTo(x, y);
    }
    if (r > 0) {
      p.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    }
    p.close();
    return p;
  }
}
