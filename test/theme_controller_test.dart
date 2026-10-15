import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightly_record/state/theme_controller.dart';
import 'package:lightly_record/theme/app_colors.dart';
import 'package:lightly_record/theme/app_theme.dart';

/// T02 主题系统验收：6 套预设可构建、切换即时生效、暗夜对比度达标。
///
/// 数据层（DDL / 播种 / DAO）的回归在 `data_layer_test.dart`，此处不重复。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme 6 套预设', () {
    test('6 套全部可构建 MaterialApp，且 brightness 跟随 isDark', () {
      for (final id in AppThemeId.values) {
        final theme = AppTheme.buildThemeData(id);
        final colors = theme.extension<AppColors>()!;
        expect(colors, isNotNull, reason: id.id);
        expect(theme.brightness,
            colors.isDark ? Brightness.dark : Brightness.light);
        // scaffold 底色跟随 bg token，不写死
        expect(theme.scaffoldBackgroundColor, colors.bg);
      }
      expect(AppThemeId.values.length, 6);
    });

    test('isDark 仅 dark 为 true', () {
      expect(AppTheme.colorsOf(AppThemeId.mint).isDark, isFalse);
      expect(AppTheme.colorsOf(AppThemeId.blue).isDark, isFalse);
      expect(AppTheme.colorsOf(AppThemeId.sand).isDark, isFalse);
      expect(AppTheme.colorsOf(AppThemeId.sakura).isDark, isFalse);
      expect(AppTheme.colorsOf(AppThemeId.lav).isDark, isFalse);
      expect(AppTheme.colorsOf(AppThemeId.dark).isDark, isTrue);
    });

    test('短码往返 + 未知值退化', () {
      for (final id in AppThemeId.values) {
        expect(AppThemeId.fromId(id.id), id);
      }
      expect(AppThemeId.fromId('nope'), AppThemeId.mint);
      expect(AppThemeId.fromId(null), AppThemeId.mint);
      expect(AppThemeId.fromId(''), AppThemeId.mint);
    });

    test('6 套主题 bg/card/ink 三元组互不相同（防抄错行）', () {
      final sigs = AppThemeId.values
          .map(AppTheme.colorsOf)
          .map((c) => '${c.bg.toARGB32()}|${c.card.toARGB32()}|${c.ink.toARGB32()}')
          .toSet();
      expect(sigs.length, 6);
    });

    test('暗夜主题文字对比度达标（ink >= 4.5:1，ink2 >= 3:1）', () {
      final c = AppTheme.colorsOf(AppThemeId.dark);
      expect(_contrast(c.ink, c.bg), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.ink2, c.bg), greaterThanOrEqualTo(3.0));
      expect(_contrast(c.red, c.bg), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.greenDeep, c.bg), greaterThanOrEqualTo(4.5));
    });

    /// 6 套主题的 WCAG 对比度实测值（`ink / ink2 / greenDeep / red` 对 `bg`）。
    ///
    /// 色值逐条转写自交互原型 `THEMES[i].vars` 与架构文档 §10 色值表，
    /// **工程师不得自行调色**。这里把实测结果固化成断言下限，
    /// 作用是「防止有人手滑改坏色值」，而不是定义无障碍标准。
    ///
    /// | 主题 | ink | ink2 | greenDeep | red |
    /// |---|---|---|---|---|
    /// | mint | 11.15 | 2.57 | 3.04 | 2.56 |
    /// | blue | 11.99 | 2.95 | 4.86 | 2.50 |
    /// | sand | 11.52 | 2.98 | 3.55 | 2.70 |
    /// | sakura | 12.23 | 3.05 | 4.67 | 2.68 |
    /// | lav | 12.52 | 3.27 | 5.58 | 2.69 |
    /// | dark | 12.89 | 6.68 | 8.65 | 5.41 |
    ///
    /// **已上报的遗留问题（设计层决策，非工程 Bug）**：
    /// 原型 `.t-amt`（15px/500 支出金额）直接用 `--red` 作文字色，
    /// 浅色 5 套实测仅 2.50–2.70:1，低于 WCAG AA 正文 4.5:1；
    /// `ink2`（次要文案）在 mint/blue/sand 实测 2.57–2.98:1。
    /// `ink`（主文案）6 套全部 11.15:1 以上，达标。
    /// 待架构师 / 产品确认是否收紧 `--red` 与 `--ink-2`。
    test('6 套主题对比度不低于设计系统实测下限（防色值被改坏）', () {
      for (final id in AppThemeId.values) {
        final c = AppTheme.colorsOf(id);
        final ctx = '${id.id}(ink=${_contrast(c.ink, c.bg).toStringAsFixed(2)},'
            'ink2=${_contrast(c.ink2, c.bg).toStringAsFixed(2)},'
            'greenDeep=${_contrast(c.greenDeep, c.bg).toStringAsFixed(2)},'
            'red=${_contrast(c.red, c.bg).toStringAsFixed(2)})';

        // 主文案：硬性达标线
        expect(_contrast(c.ink, c.bg), greaterThanOrEqualTo(4.5),
            reason: '$ctx 主文案 ink 必须 >= 4.5:1');

        // 次要 / 强调色：只防回归，阈值取全表最小值再留 0.1 余量
        expect(_contrast(c.ink2, c.bg), greaterThanOrEqualTo(2.4), reason: ctx);
        expect(_contrast(c.greenDeep, c.bg), greaterThanOrEqualTo(2.9),
            reason: ctx);
        expect(_contrast(c.red, c.bg), greaterThanOrEqualTo(2.4), reason: ctx);
      }
    });

    test('heatBase / heatSpan 派生值符合架构文档 §10', () {
      for (final id in AppThemeId.values) {
        final c = AppTheme.colorsOf(id);
        if (id == AppThemeId.dark) {
          expect(c.heatBase, 0.16);
          expect(c.heatSpan, 0.45);
        } else {
          expect(c.heatBase, 0.10);
          expect(c.heatSpan, 0.50);
        }
      }
    });
  });

  group('ThemeController', () {
    test('切换即时通知监听者，且 colors 跟随', () async {
      final controller = ThemeController();
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.themeId, AppThemeId.mint);
      expect(controller.colors.isDark, isFalse);

      await controller.setTheme(AppThemeId.dark);
      expect(controller.themeId, AppThemeId.dark);
      expect(controller.colors.isDark, isTrue);
      expect(controller.colors, AppTheme.colorsOf(AppThemeId.dark));
      expect(notified, 1);

      // 重复设置同一主题不再通知
      await controller.setTheme(AppThemeId.dark);
      expect(notified, 1);

      await controller.setTheme(AppThemeId.sakura);
      expect(controller.colors, AppTheme.colorsOf(AppThemeId.sakura));
      expect(notified, 2);
    });

    test('restore：AppLocator 未就绪时安全返回当前主题', () async {
      final controller = ThemeController(initial: AppThemeId.blue);
      expect(await controller.restore(), AppThemeId.blue);
    });

    testWidgets('主题切换经 ListenableBuilder 传播到 MaterialApp', (tester) async {
      // 复刻 lib/app.dart 的接线方式（ListenableBuilder + buildThemeData），
      // 验证「controller 通知 → MaterialApp.theme 重建」这条链路。
      // 完整 App 装配（含 AppState / DB）见 main_shell_test.dart 的
      // _pumpShell 装配。
      final controller = ThemeController();

      Widget harness() => ListenableBuilder(
            listenable: controller,
            builder: (context, _) => MaterialApp(
              theme: AppTheme.buildThemeData(controller.themeId),
              home: const SizedBox.shrink(),
            ),
          );

      await tester.pumpWidget(harness());
      var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.brightness, Brightness.light);
      expect(app.theme?.extension<AppColors>()!.isDark, isFalse);

      await controller.setTheme(AppThemeId.dark);
      await tester.pump();

      app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.brightness, Brightness.dark);
      expect(app.theme?.extension<AppColors>()!.isDark, isTrue);
      expect(app.theme?.scaffoldBackgroundColor,
          AppTheme.colorsOf(AppThemeId.dark).bg);
    });
  });
}

/// WCAG 相对亮度对比度（`(Lmax + 0.05) / (Lmin + 0.05)`）。
double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}
