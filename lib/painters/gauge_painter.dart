import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 同期对比仪表弧 Painter。
///
/// 严格对齐原型 `renderCompare()`：
/// - 半径 44、弧宽 10、整圈周长 `2π×44 = 276.46`；
/// - 弧长 = `min(100, max(6, |v|)) / 100 × 周长`（百分比被限制在 6% ~ 100%）；
/// - 12 点方向起笔、顺时针，圆头端点。
class GaugePainter extends CustomPainter {
  /// 涨跌幅，如 `-0.08`（-8%）/ `0.065`（+6.5%）。
  final double ratio;

  /// 底环颜色（轨道）。
  final Color trackColor;

  /// 弧颜色（好消息绿 / 坏消息红，由调用方决定）。
  final Color arcColor;

  /// 半径。
  final double radius;

  /// 弧宽。
  final double strokeWidth;

  /// 最小可见百分比（6%）。
  final double minPercent;

  /// 最大百分比（100%）。
  final double maxPercent;

  const GaugePainter({
    required this.ratio,
    required this.trackColor,
    required this.arcColor,
    this.radius = 44,
    this.strokeWidth = 10,
    this.minPercent = 6,
    this.maxPercent = 100,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final r = math.min(radius, (side - strokeWidth) / 2);
    if (r <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r);

    // 底环
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..isAntiAlias = true;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    final circumference = 2 * math.pi * r;
    // NaN 防御：仓库层保证无基期返回 null，但防御性钳到 0
    // （math.min/max 遇 NaN 会返回 NaN 并一路传进 drawArc）。
    final cleanRatio = ratio.isNaN ? 0.0 : ratio;
    final percent = math.min(maxPercent, math.max(minPercent, cleanRatio.abs() * 100));
    final arc = percent / 100 * circumference;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arcColor
      ..isAntiAlias = true;
    // -π/2 = 12 点方向起笔
    canvas.drawArc(rect, -math.pi / 2, arc, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
