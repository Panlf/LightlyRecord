import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'app_colors.dart';
import 'app_typography.dart';

/// 主题 id 枚举（6 套预设，id 与原型 `THEMES[i].id` 一一对应）。
enum AppThemeId {
  /// 薄荷绿（默认）。
  mint('mint', '薄荷绿'),

  /// 雾蓝。
  blue('blue', '雾蓝'),

  /// 暖沙。
  sand('sand', '暖沙'),

  /// 樱花粉。
  sakura('sakura', '樱花粉'),

  /// 薰衣紫。
  lav('lav', '薰衣紫'),

  /// 暗夜。
  dark('dark', '暗夜');

  /// 持久化到 `pref.theme_id` 的短码。
  final String id;

  /// 主题外观页展示名。
  final String label;

  const AppThemeId(this.id, this.label);

  /// 短码 → 枚举；未知值退化为 [AppThemeId.mint]。
  static AppThemeId fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => AppThemeId.mint);
}

/// 6 套预设色值表 + `buildThemeData()`。
///
/// 色值逐条转写自交互原型 `THEMES[i].vars`，**工程师直接照抄，不要自行调色**。
class AppTheme {
  const AppTheme._();

  // ------------------------------------------------------------ 6 套预设

  /// 薄荷绿。
  static const AppColors mint = AppColors(
    bg: Color(0xFFF5F8F6),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE3EBE6),
    line2: Color(0xFFE5EEE9),
    track: Color(0xFFEDF3EF),
    track2: Color(0xFFE7EFEA),
    ink: Color(0xFF2C3A34),
    ink2: Color(0xFF8FA099),
    ink3: Color(0xFFA7B5AE),
    green: Color(0xFF57B894),
    greenDeep: Color(0xFF3E9F7C),
    greenLight: Color(0xFFE4F5EE),
    red: Color(0xFFEE7B66),
    barIdle: Color(0xFFCFE8DC),
    switchOff: Color(0xFFDDE7E1),
    dashed: Color(0xFFBFD6CB),
    tabbarBg: Color(0xF6F5F8F6),
    fabShadow: Color(0x5957B894),
    isDark: false,
    heatBase: 0.10,
    heatSpan: 0.50,
  );

  /// 雾蓝。
  static const AppColors blue = AppColors(
    bg: Color(0xFFF3F7FB),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFDFE8F2),
    line2: Color(0xFFE2EBF4),
    track: Color(0xFFE9F0F7),
    track2: Color(0xFFE0EAF3),
    ink: Color(0xFF26333F),
    ink2: Color(0xFF7E93A6),
    ink3: Color(0xFFA3B3C0),
    green: Color(0xFF5B8DB8),
    greenDeep: Color(0xFF41709B),
    greenLight: Color(0xFFE6F1FA),
    red: Color(0xFFE0857A),
    barIdle: Color(0xFFCBDDEB),
    switchOff: Color(0xFFD8E3EE),
    dashed: Color(0xFFB9CCDD),
    tabbarBg: Color(0xF6F3F7FB),
    fabShadow: Color(0x595B8DB8),
    isDark: false,
    heatBase: 0.10,
    heatSpan: 0.50,
  );

  /// 暖沙。
  static const AppColors sand = AppColors(
    bg: Color(0xFFFAF7F1),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFEEE5D5),
    line2: Color(0xFFF0E8DA),
    track: Color(0xFFF3EDE1),
    track2: Color(0xFFEFE7D8),
    ink: Color(0xFF3A342A),
    ink2: Color(0xFF9A8F7B),
    ink3: Color(0xFFB5AA95),
    green: Color(0xFFC99A3F),
    greenDeep: Color(0xFFA87B27),
    greenLight: Color(0xFFFBF3E0),
    red: Color(0xFFDE7E63),
    barIdle: Color(0xFFEDDCB8),
    switchOff: Color(0xFFE7DCC6),
    dashed: Color(0xFFD6C6A6),
    tabbarBg: Color(0xF6FAF7F1),
    fabShadow: Color(0x59C99A3F),
    isDark: false,
    heatBase: 0.10,
    heatSpan: 0.50,
  );

  /// 樱花粉。
  static const AppColors sakura = AppColors(
    bg: Color(0xFFFBF5F6),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFF0E2E7),
    line2: Color(0xFFF3E7EC),
    track: Color(0xFFF6EAEE),
    track2: Color(0xFFF3E3E9),
    ink: Color(0xFF3B2C33),
    ink2: Color(0xFFA08795),
    ink3: Color(0xFFBFA8B4),
    green: Color(0xFFD16B8C),
    greenDeep: Color(0xFFB04E71),
    greenLight: Color(0xFFFAE9EF),
    red: Color(0xFFDE7E63),
    barIdle: Color(0xFFF2D3DE),
    switchOff: Color(0xFFEBD5DE),
    dashed: Color(0xFFDFB9C8),
    tabbarBg: Color(0xF6FBF5F6),
    fabShadow: Color(0x59D16B8C),
    isDark: false,
    heatBase: 0.10,
    heatSpan: 0.50,
  );

  /// 薰衣紫。
  static const AppColors lav = AppColors(
    bg: Color(0xFFF8F6FC),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE6DFF2),
    line2: Color(0xFFEBE5F5),
    track: Color(0xFFEFEBF7),
    track2: Color(0xFFEAE4F4),
    ink: Color(0xFF322C3D),
    ink2: Color(0xFF8E84A3),
    ink3: Color(0xFFADA3BF),
    green: Color(0xFF8B6FC7),
    greenDeep: Color(0xFF6F54A8),
    greenLight: Color(0xFFEFEBFA),
    red: Color(0xFFDE7E63),
    barIdle: Color(0xFFDAD0EE),
    switchOff: Color(0xFFDFD7EC),
    dashed: Color(0xFFC6B8E0),
    tabbarBg: Color(0xF6F8F6FC),
    fabShadow: Color(0x598B6FC7),
    isDark: false,
    heatBase: 0.10,
    heatSpan: 0.50,
  );

  /// 暗夜。
  static const AppColors dark = AppColors(
    bg: Color(0xFF1F2A25),
    card: Color(0xFF2A3833),
    line: Color(0xFF3A4C44),
    line2: Color(0xFF3A4C44),
    track: Color(0xFF33443C),
    track2: Color(0xFF2E3F38),
    ink: Color(0xFFE9F1EC),
    ink2: Color(0xFF9DB3A9),
    ink3: Color(0xFF7C8F85),
    green: Color(0xFF57B894),
    greenDeep: Color(0xFF8FD4B5),
    greenLight: Color(0x2957B894),
    red: Color(0xFFEE7B66),
    barIdle: Color(0xFF3D5A4E),
    switchOff: Color(0xFF3D4C45),
    dashed: Color(0xFF4A5D54),
    tabbarBg: Color(0xF61F2A25),
    fabShadow: Color(0x7357B894),
    isDark: true,
    heatBase: 0.16,
    heatSpan: 0.45,
  );

  // ------------------------------------------------------------ 查询

  /// 主题 id → 色值表。
  static AppColors colorsOf(AppThemeId id) => switch (id) {
        AppThemeId.mint => mint,
        AppThemeId.blue => blue,
        AppThemeId.sand => sand,
        AppThemeId.sakura => sakura,
        AppThemeId.lav => lav,
        AppThemeId.dark => dark,
      };

  /// 主题 id → 色值表（按持久化短码）。
  static AppColors colorsFromKey(String? key) => colorsOf(AppThemeId.fromId(key));

  /// 主题外观页 2 列预览用的三色块（背景 / 卡片 / **主色**）。
  ///
  /// 第三元必须是主色 `green`：预览卡底部的主色条要代表该主题的
  /// 强调色；早期版本返回 `track`（轨道灰），6 套主题的色条全是灰的。
  static (Color, Color, Color) previewTriple(AppThemeId id) {
    final c = colorsOf(id);
    return (c.bg, c.card, c.green);
  }

  // ------------------------------------------------------------ ThemeData

  /// 构造完整的 [ThemeData]。
  ///
  /// 按 `isDark` 切换 [Brightness]；注入 `extensions: [colors]`；
  /// 配置 `scaffoldBackgroundColor / cardColor / dividerColor / switchTheme`。
  static ThemeData buildThemeData(AppThemeId id) {
    final c = colorsOf(id);
    final brightness = c.isDark ? Brightness.dark : Brightness.light;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    );

    final scheme = base.colorScheme.copyWith(
      primary: c.green,
      onPrimary: AppColors.onGreen,
      secondary: c.greenDeep,
      onSecondary: AppColors.white,
      surface: c.card,
      onSurface: c.ink,
      error: c.red,
      onError: AppColors.white,
      outline: c.line,
      shadow: c.ink,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      cardColor: c.card,
      dividerColor: c.line,
      splashColor: c.green.withValues(alpha: 0.08),
      highlightColor: c.green.withValues(alpha: 0.04),
      extensions: <ThemeExtension<dynamic>>[c],
      // 状态栏图标随主题明暗切换
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: c.bg,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: _transparent,
          statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.green;
          return c.switchOff;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          return AppColors.white;
        }),
        trackOutlineColor: WidgetStateProperty.all(_transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.green,
        linearTrackColor: c.track,
        circularTrackColor: c.track,
      ),
      textTheme: AppTypography.textTheme(c.ink),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: c.card,
      ),
    );
  }

  /// 完全透明色。
  static const Color _transparent = Color(0x00000000);
}
