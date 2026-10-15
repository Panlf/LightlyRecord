import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_locator.dart';
import '../core/constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 主题切换与持久化，暴露 [AppColors]。
///
/// 架构文档 §2 归属 `state/` 层，但**主题系统本身属于 T02 交付物**
/// （验收项「6 套主题切换即时生效」+ §11 A10「状态栏图标跟随 isDark 转亮」），
/// 因此提前到 T02 落地。T03 引入 `MultiProvider` 时直接 `ChangeNotifierProvider`
/// 挂载本类即可，无需改写。
///
/// 用法（不依赖 provider 的最小接法）：
/// ```dart
/// final controller = ThemeController();
/// controller.addListener(() { /* rebuild */ });
/// controller.setTheme(AppThemeId.dark);
/// ```
class ThemeController extends ChangeNotifier {
  /// 当前主题 id。
  AppThemeId _themeId;

  /// 当前色值表（随 [_themeId] 联动）。
  AppColors get colors => AppTheme.colorsOf(_themeId);

  /// 当前主题 id（只读）。
  AppThemeId get themeId => _themeId;

  ThemeController({AppThemeId initial = AppThemeId.mint})
      : _themeId = initial;

  /// 从持久化 pref 恢复主题；必须在 `AppLocator.init()` 之后调用。
  ///
  /// pref 缺失或不可解析时退化为薄荷绿（与 seed 一致）。
  /// `AppLocator` 未就绪时直接返回当前值（DB 异常时 App 仍能以默认主题启动）。
  Future<AppThemeId> restore() async {
    final repo = AppLocator.prefRepository;
    if (!AppLocator.isReady || repo == null) return _themeId;
    final raw = await repo.get(AppConstants.prefKeyThemeId);
    final restored = AppThemeId.fromId(raw);
    if (restored != _themeId) {
      _themeId = restored;
      notifyListeners();
    }
    return _themeId;
  }

  /// 切换主题：先通知再落盘，保证下次冷启动一致。
  ///
  /// 同时按 `AppColors.isDark` 翻转系统状态栏 / 导航栏图标亮度
  /// （架构文档 §11 A10：暗夜下图标转亮）。
  /// `AppLocator` 未就绪时只做内存切换，跳过持久化。
  Future<void> setTheme(AppThemeId id) async {
    if (id == _themeId) return;
    _themeId = id;
    notifyListeners();
    final repo = AppLocator.prefRepository;
    if (!AppLocator.isReady || repo == null) return;
    await repo.set(AppConstants.prefKeyThemeId, id.id);
    _syncSystemUiOverlay(colors);
  }

  /// 按当前主题刷新系统栏图标亮度。
  ///
  /// 在 `MaterialApp` 首帧后调用一次；主题切换时由 [setTheme] 内部调用。
  void syncSystemUiOverlay() => _syncSystemUiOverlay(colors);

  void _syncSystemUiOverlay(AppColors c) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppColors.transparent,
      statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: AppColors.transparent,
      systemNavigationBarIconBrightness:
          c.isDark ? Brightness.light : Brightness.dark,
    ));
  }
}
