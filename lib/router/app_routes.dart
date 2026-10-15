import 'package:flutter/material.dart';

import '../pages/add_tx/add_tx_page.dart';
import '../pages/budget/budget_page.dart';
import '../pages/category/category_page.dart';
import '../pages/shell/main_shell.dart';
import '../pages/theme/theme_page.dart';
import '../pages/tx_detail/tx_detail_page.dart';
import '../widgets/slide_route.dart';

/// 全局 Navigator Key（`AppToast` 等无 context 场景取 Overlay 用）。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 路由名常量 + `onGenerateRoute`。
///
/// 滑入页（记一笔 / 交易详情 / 预算 / 主题 / 分类）统一走 [SlideRoute]（右滑入 320ms）。
class AppRoutes {
  const AppRoutes._();

  /// 主壳（底部 5 Tab）。
  static const String shell = '/';

  /// 记一笔滑入页。
  static const String addTx = '/add-tx';

  /// 交易详情 / 编辑滑入页。
  static const String txDetail = '/tx-detail';

  /// 预算管理滑入页。
  static const String budget = '/budget';

  /// 主题外观滑入页。
  static const String theme = '/theme';

  /// 分类与账本管理滑入页。
  static const String category = '/category';

  /// 路由表（未知路由回落 [shell]）。
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case shell:
        return _noAnim(const MainShell());
      case addTx:
        return SlideRoute(builder: (_) => const AddTxPage());
      case txDetail:
        final args = settings.arguments;
        return SlideRoute(
          builder: (_) => TxDetailPage(txnId: args is int ? args : 0),
        );
      case budget:
        return SlideRoute(builder: (_) => const BudgetPage());
      case theme:
        return SlideRoute(builder: (_) => const ThemePage());
      case category:
        return SlideRoute(builder: (_) => const CategoryPage());
      default:
        return _noAnim(const MainShell());
    }
  }

  /// 主壳用无动画路由（Tab 内部状态由 `IndexedStack` 保持）。
  static Route<dynamic> _noAnim(Widget page) =>
      PageRouteBuilder<dynamic>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        settings: const RouteSettings(name: shell),
      );
}
