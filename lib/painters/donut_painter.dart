import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 环形图一个分段。
class DonutSlice {
  /// 段色。
  final Color color;

  /// 占比 0~1（同组之和应为 1）。
  final double ratio;

  const DonutSlice(this.color, this.ratio);
}

/// 环形图 Painter。
///
/// - `drawArc` 绘制，12 点方向起笔、顺时针；
/// - 环宽 22（[strokeWidth]），外径 = `min(width, height)`；
/// - 无数据 / 占比和为 0 时整圈画 [trackColor] 灰环；
/// - 段与段之间留 1px 间隙，避免相邻同色段糊在一起。
class DonutPainter extends CustomPainter {
  /// 分段列表（降序）。
  final List<DonutSlice> slices;

  /// 空态 / 底环颜色。
  final Color trackColor;

  /// 环宽。
  final double strokeWidth;

  /// 段间隙（弧度）。
  final double gapRadians;

  const DonutPainter({
    required this.slices,
    required this.trackColor,
    this.strokeWidth = 22,
    this.gapRadians = 0.012,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final radius = (side - strokeWidth) / 2;
    if (radius <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..isAntiAlias = true;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    final total = slices.fold<double>(0, (sum, s) => sum + s.ratio);
    if (total <= 0) return;

    var start = -math.pi / 2; // 12 点方向
    for (final slice in slices) {
      if (slice.ratio <= 0) continue;
      final sweep = (slice.ratio / total) * math.pi * 2;
      if (sweep <= gapRadians * 2) {
        start += sweep;
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = slice.color
        ..isAntiAlias = true;
      canvas.drawArc(
        rect,
        start + gapRadians / 2,
        sweep - gapRadians,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) {
    return oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        !_sameSlices(oldDelegate.slices, slices);
  }

  bool _sameSlices(List<DonutSlice> a, List<DonutSlice> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].color != b[i].color || a[i].ratio != b[i].ratio) return false;
    }
    return true;
  }
}
