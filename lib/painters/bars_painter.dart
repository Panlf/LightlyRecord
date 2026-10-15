import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 柱状图一根柱子。
class BarValue {
  /// 数值（分，或任意正数；Painter 只做归一化，不解析单位）。
  final int value;

  /// 是否高亮（当前所在周期）。
  final bool hot;

  const BarValue(this.value, {this.hot = false});
}

/// 柱状图 Painter。
///
/// - `RoundedRect` 圆角 8/8/4/4（上圆下方，对齐原型 `.bars .b`）；
/// - 柱高按当期**最大值**归一化；最大值为 0 时全部画 2% 的占位高度；
/// - 柱间距 8；非高亮用 [idleColor]，高亮用 [hotColor]。
class BarsPainter extends CustomPainter {
  /// 柱子列表（顺序即从左到右）。
  final List<BarValue> bars;

  /// 非当月 / 非当前周期颜色。
  final Color idleColor;

  /// 高亮颜色。
  final Color hotColor;

  /// 柱间距。
  final double gap;

  /// 顶部圆角。
  final double radiusTop;

  /// 底部圆角。
  final double radiusBottom;

  /// 空态占位高度比例。
  final double emptyRatio;

  const BarsPainter({
    required this.bars,
    required this.idleColor,
    required this.hotColor,
    this.gap = 8,
    this.radiusTop = 8,
    this.radiusBottom = 4,
    this.emptyRatio = 0.02,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;

    final count = bars.length;
    final slot = size.width / count;
    final barWidth = math.max(0.0, slot - gap);
    if (barWidth <= 0) return;

    final maxValue = bars.fold<int>(0, (m, b) => b.value > m ? b.value : m);

    for (var i = 0; i < count; i++) {
      final bar = bars[i];
      final ratio = maxValue <= 0 ? emptyRatio : bar.value / maxValue;
      final h = math.max(barWidth * 0.5, size.height * ratio.clamp(0.0, 1.0));
      final left = i * slot + gap / 2;
      final top = size.height - h;

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barWidth, h),
        topLeft: Radius.circular(radiusTop),
        topRight: Radius.circular(radiusTop),
        bottomLeft: Radius.circular(radiusBottom),
        bottomRight: Radius.circular(radiusBottom),
      );

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = bar.hot ? hotColor : idleColor
        ..isAntiAlias = true;
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BarsPainter oldDelegate) {
    return oldDelegate.idleColor != idleColor ||
        oldDelegate.hotColor != hotColor ||
        oldDelegate.gap != gap ||
        oldDelegate.radiusTop != radiusTop ||
        oldDelegate.radiusBottom != radiusBottom ||
        !_sameBars(oldDelegate.bars, bars);
  }

  bool _sameBars(List<BarValue> a, List<BarValue> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value || a[i].hot != b[i].hot) return false;
    }
    return true;
  }
}
