import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'router/app_routes.dart';
import 'state/app_state.dart';
import 'state/book_controller.dart';
import 'state/calendar_controller.dart';
import 'state/home_controller.dart';
import 'state/me_controller.dart';
import 'state/stats_controller.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';

/// MaterialApp + MultiProvider + 路由表 + 主题注入。
///
/// Provider 分层：
/// - [AppState]：全局单例，当前账本 + `dataVersion` 总线 + 各 Repository 入口；
/// - [ThemeController]：主题切换与持久化（T02 落地）；
/// - [HomeController] / [StatsController] / [CalendarController] /
///   [BookController] / [MeController]：由 [AppState] 派生，
///   监听 `dataVersion` 自动重算。
class LightlyRecordApp extends StatelessWidget {
  /// 全局状态（由 `main.dart` 构造并 `init()` 后传入）。
  final AppState appState;

  const LightlyRecordApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<ThemeController>.value(
          value: appState.themeController,
        ),
        // 首页 Controller：依赖 AppState，用 ProxyProvider 派生
        // （AppState 变化时不会重建 Controller 实例，只触发其内部监听）。
        ChangeNotifierProxyProvider<AppState, HomeController>(
          create: (_) => HomeController(appState),
          update: (_, appState, previous) => previous ?? HomeController(appState),
        ),
        // 图表页 Controller（T04）：多 mode / period 两个维度。
        ChangeNotifierProxyProvider<AppState, StatsController>(
          create: (_) => StatsController(appState),
          update: (_, appState, previous) =>
              previous ?? StatsController(appState),
        ),
        // 日历页 Controller（T04）：自身持有显示年月与选中日。
        ChangeNotifierProxyProvider<AppState, CalendarController>(
          create: (_) => CalendarController(appState),
          update: (_, appState, previous) =>
              previous ?? CalendarController(appState),
        ),
        // 账本页 Controller（T05）：列表 + 本账本统计卡。
        ChangeNotifierProxyProvider<AppState, BookController>(
          create: (_) => BookController(appState),
          update: (_, appState, previous) => previous ?? BookController(appState),
        ),
        // 我的页 Controller（T05）：全局口径统计。
        ChangeNotifierProxyProvider<AppState, MeController>(
          create: (_) => MeController(appState),
          update: (_, appState, previous) => previous ?? MeController(appState),
        ),
      ],
      child: _ThemedApp(appState: appState),
    );
  }
}

/// 主题 + 路由外壳（拆出来只为让 `ListenableBuilder` 的子树尽量小）。
class _ThemedApp extends StatelessWidget {
  const _ThemedApp({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    // 主题切换即时生效：监听 ThemeController 重建 MaterialApp。
    final themeController = context.watch<ThemeController>();

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => MaterialApp(
        title: '轻记',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        theme: AppTheme.buildThemeData(themeController.themeId),
        initialRoute: AppRoutes.shell,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        // 字体缩放钳制到 1.3：界面为固定像素布局（对齐原型），
        // 系统超大字体下多处固定宽高会 RenderFlex 溢出；
        // 钳制保证可读性与布局完整性的平衡。
        builder: (context, child) {
          final scaler = MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: 1.3);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          );
        },
        // 中文日期选择器必需
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('zh'),
          Locale('en', 'US'),
        ],
        locale: const Locale('zh', 'CN'),
      ),
    );
  }
}
