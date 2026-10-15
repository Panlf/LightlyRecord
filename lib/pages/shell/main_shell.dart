import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../router/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/mountain_fab.dart';
import '../books/books_page.dart';
import '../calendar/calendar_page.dart';
import '../home/home_page.dart';
import '../me/me_page.dart';
import '../stats/stats_page.dart';
import 'pill_tab_bar.dart';

/// 主壳：`IndexedStack` × 5 保持状态 + `PopScope` 双击退出 + FAB 显隐。
///
/// - 5 个 Tab（今日 / 图表 / 日历 / 账本 / 我的）用 `IndexedStack` 保持各自状态
///   （切走再切回滚动位置与数据不丢）；
/// - 非首页 Tab 按返回键先回到今日页；首页 2s 内连按两次退出；
/// - FAB 仅在「今日」「日历」两个 Tab 显示，位置严格对齐原型
///   （`right: 22`、`bottom: 95 + 23`）。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// 供子页面（如今日页「全部 >」）切换到指定 Tab。
  static void switchTabOf(BuildContext context, int index) {
    final state = context.findRootAncestorStateOfType<MainShellState>();
    state?.switchTo(index);
  }

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  static const int _homeIndex = 0;
  static const int _calendarIndex = 2;

  /// 切换到指定 Tab（同一 Tab 不重复触发）。
  void switchTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  int _index = _homeIndex;
  DateTime? _lastBackPress;

  final List<Widget> _pages = const [
    HomePage(),
    StatsPage(),
    CalendarPage(),
    BooksPage(),
    MePage(),
  ];

  bool get _showFab => _index == _homeIndex || _index == _calendarIndex;

  void _onTabChanged(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  /// 返回键处理：非首页先回首页；首页 2s 内双击退出。
  Future<bool> _handleBack() async {
    if (_index != _homeIndex) {
      setState(() {
        _index = _homeIndex;
        // 回首页不属于「按了一次退出」，重置双击窗口，
        // 避免用户随即在首页按返回时直接退出 App。
        _lastBackPress = null;
      });
      return false;
    }
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) <= AppDimens.doubleBackWindow) {
      return true;
    }
    _lastBackPress = now;
    AppToast.show('再按一次退出轻记');
    return false;
  }

  void _openAddTx() {
    Navigator.of(context).pushNamed(AppRoutes.addTx);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBack();
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            // IndexedStack：保持 5 个 Tab 的状态
            IndexedStack(index: _index, children: _pages),

            // 底部胶囊导航（含向上渐隐的过渡，保证导航上方有呼吸空间）
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: AppDimens.tabBarHeight,
                padding: const EdgeInsets.only(
                  left: AppDimens.pillMargin,
                  right: AppDimens.pillMargin,
                  top: 12,
                  bottom: 21,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      c.tabbarFade,
                      c.tabbarBg,
                      c.tabbarBg,
                    ],
                    stops: const [0, 0.28, 1],
                  ),
                ),
                child: PillTabBar(
                  currentIndex: _index,
                  onTap: _onTabChanged,
                ),
              ),
            ),

            // 山峦 FAB（仅今日 / 日历 Tab 显示）
            if (_showFab)
              Positioned(
                right: AppDimens.fabRight,
                bottom: AppDimens.fabBottom,
                child: MountainFab(onTap: _openAddTx),
              ),
          ],
        ),
      ),
    );
  }
}
