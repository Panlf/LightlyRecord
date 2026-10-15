import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lightly_record/theme/app_theme.dart';
import 'package:lightly_record/theme/app_colors.dart';

/// T02 主题系统冒烟测试。
void main() {
  group('AppTheme', () {
    test('6 套预设全部可构造且色值齐全', () {
      for (final id in AppThemeId.values) {
        final colors = AppTheme.colorsOf(id);
        expect(colors.bg, isNotNull);
        expect(colors.card, isNotNull);
        expect(colors.ink, isNotNull);
        expect(colors.green, isNotNull);
        expect(colors.isDark, id == AppThemeId.dark);
      }
    });

    test('buildThemeData 注入 AppColors 扩展', () {
      for (final id in AppThemeId.values) {
        final theme = AppTheme.buildThemeData(id);
        final ext = theme.extension<AppColors>();
        expect(ext, isNotNull);
        expect(ext!.bg, AppTheme.colorsOf(id).bg);
        expect(theme.scaffoldBackgroundColor, ext.bg);
        expect(theme.brightness,
            ext.isDark ? Brightness.dark : Brightness.light);
      }
    });

    test('AppColors.copyWith / lerp 行为正确', () {
      final a = AppTheme.colorsOf(AppThemeId.mint);
      final b = AppTheme.colorsOf(AppThemeId.dark);

      final copied = a.copyWith(ink: b.ink);
      expect(copied.ink, b.ink);
      expect(copied.bg, a.bg);

      final mid = a.lerp(b, 0.5);
      expect(mid.bg, isNot(a.bg));
      expect(mid.bg, isNot(b.bg));
      expect(a.lerp(null, 0.5), same(a));
    });

    test('热度色透明度在 [heatBase, heatBase + heatSpan] 区间内', () {
      final light = AppTheme.colorsOf(AppThemeId.mint);
      final dark = AppTheme.colorsOf(AppThemeId.dark);
      expect(light.heatBase, 0.10);
      expect(light.heatSpan, 0.50);
      expect(dark.heatBase, 0.16);
      expect(dark.heatSpan, 0.45);

      // ratio 0 → base；ratio 1 → base + span
      expect(light.heatColor(0).a, closeTo(0.10, 0.001));
      expect(light.heatColor(1).a, closeTo(0.60, 0.001));
      expect(dark.heatColor(1).a, closeTo(0.61, 0.001));
    });

    test('AppThemeId.fromId 未知值回落 mint', () {
      expect(AppThemeId.fromId('dark'), AppThemeId.dark);
      expect(AppThemeId.fromId('nope'), AppThemeId.mint);
      expect(AppThemeId.fromId(null), AppThemeId.mint);
    });
  });
}
