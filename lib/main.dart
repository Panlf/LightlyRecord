import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/app_locator.dart';
import 'core/logger.dart';
import 'state/app_state.dart';
import 'state/theme_controller.dart';

/// 入口：`AppLocator.init()`（DB → DAO → Repository）→ 构造 `AppState`
/// → `AppState.init()` → `runApp`。
///
/// 时序约束：**必须先 `AppLocator.init()` 再构造 AppState**——Repository
/// 是 `AppLocator` 的 `late final` 字段，init 之前访问会抛
/// `LateInitializationError`（启动即崩）。
///
/// 失败分级：
/// - `AppLocator.init()` 失败 = DB 不可用，App 无法工作 → 记录日志后
///   继续抛出（Flutter 错误页兜底）；
/// - `themeController.restore()` / `appState.init()` 失败 = 可降级 →
///   以默认主题 + 默认账本名继续启动，用户至少能进界面。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 主题控制器先于 DB 构造：DB 未就绪时它仍能以默认主题渲染。
  final themeController = ThemeController();

  // 第一步：DB → DAO → Repository（失败即不可恢复）
  try {
    await AppLocator.init();
  } catch (e, s) {
    Log.e('AppLocator.init failed', e, s);
    rethrow;
  }

  // 第二步：构造全局状态（Repository 已就绪）
  final appState = AppState(
    bookRepository: AppLocator.bookRepository!,
    categoryRepository: AppLocator.categoryRepository!,
    prefRepository: AppLocator.prefRepository!,
    txnRepository: AppLocator.txnRepository!,
    statsRepository: AppLocator.statsRepository!,
    budgetRepository: AppLocator.budgetRepository!,
    themeController: themeController,
  );
  // 供「无 context 场景」（保存后触发全局刷新）取用；正常路径请从
  // BuildContext 取，便于测试替换。
  AppState.instance = appState;

  // 第三步：恢复主题与当前账本（失败降级，不阻断启动）
  try {
    await themeController.restore();
    await appState.init();
  } catch (e, s) {
    Log.e('App init failed', e, s);
  }

  // 状态栏 / 导航栏图标亮度跟随 isDark（架构文档 §11 A10）。
  themeController.syncSystemUiOverlay();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      // LightlyRecordApp 内部还会再套一层 MultiProvider；这里提前提供
      // AppState 是为了让 _ThemedApp 的 ListenableBuilder 能立刻取到它。
      child: LightlyRecordApp(appState: appState),
    ),
  );
}
