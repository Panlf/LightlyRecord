import 'package:flutter/material.dart';

/// 主题色 Token（`ThemeExtension`）。
///
/// **铁律**：组件内一律 `Theme.of(context).extension<AppColors>()!` 取色，
/// 禁止任何 `Color(0xFF…)` / `Colors.xxx` / `'#FFFFFF'` 字面量。
///
/// 18 个 Token + 派生常量（`heatBase` / `heatSpan` / `isDark` / 阴影派生）。
/// 色值逐条对照交互原型 `THEMES[i].vars`，**不得自行调色**。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// 页面背景。
  final Color bg;

  /// 卡片背景。
  final Color card;

  /// 分隔线（强）。
  final Color line;

  /// 分隔线（弱）。
  final Color line2;

  /// 进度条轨道（浅）。
  final Color track;

  /// 分段控件轨道（深）。
  final Color track2;

  /// 主文字。
  final Color ink;

  /// 次级文字。
  final Color ink2;

  /// 三级文字 / 占位。
  final Color ink3;

  /// 主题强调色（主色）。
  final Color green;

  /// 主题强调色（深，用于 chip 文字 / 收入金额）。
  final Color greenDeep;

  /// 主题强调色（浅，用于 chip 底色 / 头像底）。
  final Color greenLight;

  /// 支出红。
  final Color red;

  /// 柱状图非当月色。
  final Color barIdle;

  /// 开关关闭态。
  final Color switchOff;

  /// 虚线边框色。
  final Color dashed;

  /// 底部导航底色（半透明）。
  final Color tabbarBg;

  /// FAB 投影色。
  final Color fabShadow;

  /// 是否暗夜主题。
  final bool isDark;

  /// 热度底色基准透明度（浅色 .10 / 深色 .16）。
  final double heatBase;

  /// 热度底色跨度（浅色 .50 / 深色 .45）。
  final double heatSpan;

  const AppColors({
    required this.bg,
    required this.card,
    required this.line,
    required this.line2,
    required this.track,
    required this.track2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.green,
    required this.greenDeep,
    required this.greenLight,
    required this.red,
    required this.barIdle,
    required this.switchOff,
    required this.dashed,
    required this.tabbarBg,
    required this.fabShadow,
    required this.isDark,
    required this.heatBase,
    required this.heatSpan,
  });

  // ------------------------------------------------------------ 固定状态色
  // 非主题 Token，全局唯一（见架构文档 §7.4）。

  /// 超支 / 负向 chip 底色。
  static const Color redLight = Color(0xFFFCEAE5);

  /// 超支 / 负向 chip 文字色。
  static const Color redDeep = Color(0xFFE08A6B);

  /// 主色填充上的文字 / 图标色。
  static const Color onGreen = Color(0xFFFFFFFF);

  /// 选中态 / 深热度金额文字色。
  static const Color white = Color(0xFFFFFFFF);

  /// 完全透明色（系统栏 / 需要「无填充」语义处统一引用，避免散落 `Color(0x00000000)`）。
  static const Color transparent = Color(0x00000000);

  // ------------------------------------------------------------ 派生常量

  /// 卡片柔和投影（跟随主题墨色；暗夜主题下不投影）。
  Color get cardShadow => ink.withValues(alpha: isDark ? 0 : 0.06);

  /// 中等投影（分类选中态 / FAB 等）。
  Color get softShadow => ink.withValues(alpha: isDark ? 0 : 0.08);

  /// 选中态投影（跟随主色）。
  Color get accentShadow => green.withValues(alpha: isDark ? 0 : 0.25);

  /// 底部导航渐变的完全透明端（与 [tabbarBg] 同色系）。
  Color get tabbarFade => tabbarBg.withValues(alpha: 0);

  /// 热度底色：由 [heatBase] / [heatSpan] 与当日占比推导。
  ///
  /// [ratio] = 当日支出 / 当月最大单日支出（0~1）；纯收入日取 0。
  Color heatColor(double ratio) {
    final clamped = ratio.isNaN ? 0.0 : (ratio < 0 ? 0.0 : (ratio > 1 ? 1.0 : ratio));
    return green.withValues(alpha: heatBase + heatSpan * clamped);
  }

  // ------------------------------------------------------------ ThemeExtension

  @override
  AppColors copyWith({
    Color? bg,
    Color? card,
    Color? line,
    Color? line2,
    Color? track,
    Color? track2,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? green,
    Color? greenDeep,
    Color? greenLight,
    Color? red,
    Color? barIdle,
    Color? switchOff,
    Color? dashed,
    Color? tabbarBg,
    Color? fabShadow,
    bool? isDark,
    double? heatBase,
    double? heatSpan,
  }) =>
      AppColors(
        bg: bg ?? this.bg,
        card: card ?? this.card,
        line: line ?? this.line,
        line2: line2 ?? this.line2,
        track: track ?? this.track,
        track2: track2 ?? this.track2,
        ink: ink ?? this.ink,
        ink2: ink2 ?? this.ink2,
        ink3: ink3 ?? this.ink3,
        green: green ?? this.green,
        greenDeep: greenDeep ?? this.greenDeep,
        greenLight: greenLight ?? this.greenLight,
        red: red ?? this.red,
        barIdle: barIdle ?? this.barIdle,
        switchOff: switchOff ?? this.switchOff,
        dashed: dashed ?? this.dashed,
        tabbarBg: tabbarBg ?? this.tabbarBg,
        fabShadow: fabShadow ?? this.fabShadow,
        isDark: isDark ?? this.isDark,
        heatBase: heatBase ?? this.heatBase,
        heatSpan: heatSpan ?? this.heatSpan,
      );

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      track: Color.lerp(track, other.track, t)!,
      track2: Color.lerp(track2, other.track2, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenDeep: Color.lerp(greenDeep, other.greenDeep, t)!,
      greenLight: Color.lerp(greenLight, other.greenLight, t)!,
      red: Color.lerp(red, other.red, t)!,
      barIdle: Color.lerp(barIdle, other.barIdle, t)!,
      switchOff: Color.lerp(switchOff, other.switchOff, t)!,
      dashed: Color.lerp(dashed, other.dashed, t)!,
      tabbarBg: Color.lerp(tabbarBg, other.tabbarBg, t)!,
      fabShadow: Color.lerp(fabShadow, other.fabShadow, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
      heatBase: _lerpDouble(heatBase, other.heatBase, t),
      heatSpan: _lerpDouble(heatSpan, other.heatSpan, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppColors &&
          other.bg == bg &&
          other.card == card &&
          other.line == line &&
          other.line2 == line2 &&
          other.track == track &&
          other.track2 == track2 &&
          other.ink == ink &&
          other.ink2 == ink2 &&
          other.ink3 == ink3 &&
          other.green == green &&
          other.greenDeep == greenDeep &&
          other.greenLight == greenLight &&
          other.red == red &&
          other.barIdle == barIdle &&
          other.switchOff == switchOff &&
          other.dashed == dashed &&
          other.tabbarBg == tabbarBg &&
          other.fabShadow == fabShadow &&
          other.isDark == isDark &&
          other.heatBase == heatBase &&
          other.heatSpan == heatSpan);

  @override
  int get hashCode => Object.hashAll([
        bg,
        card,
        line,
        line2,
        track,
        track2,
        ink,
        ink2,
        ink3,
        green,
        greenDeep,
        greenLight,
        red,
        barIdle,
        switchOff,
        dashed,
        tabbarBg,
        fabShadow,
        isDark,
        heatBase,
        heatSpan,
      ]);

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
