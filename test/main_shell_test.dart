import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lightly_record/core/constants.dart';
import 'package:lightly_record/data/dao/book_dao.dart';
import 'package:lightly_record/data/dao/budget_dao.dart';
import 'package:lightly_record/data/dao/category_dao.dart';
import 'package:lightly_record/data/dao/pref_dao.dart';
import 'package:lightly_record/data/dao/txn_dao.dart';
import 'package:lightly_record/data/ddl.dart';
import 'package:lightly_record/data/db/seed_data.dart';
import 'package:lightly_record/pages/books/books_page.dart';
import 'package:lightly_record/pages/calendar/calendar_page.dart';
import 'package:lightly_record/pages/home/home_page.dart';
import 'package:lightly_record/pages/me/me_page.dart';
import 'package:lightly_record/pages/shell/main_shell.dart';
import 'package:lightly_record/pages/shell/pill_tab_bar.dart';
import 'package:lightly_record/pages/stats/stats_page.dart';
import 'package:lightly_record/repository/book_repository.dart';
import 'package:lightly_record/repository/budget_repository.dart';
import 'package:lightly_record/repository/category_repository.dart';
import 'package:lightly_record/repository/pref_repository.dart';
import 'package:lightly_record/repository/stats_repository.dart';
import 'package:lightly_record/repository/txn_repository.dart';
import 'package:lightly_record/state/app_state.dart';
import 'package:lightly_record/state/book_controller.dart';
import 'package:lightly_record/state/calendar_controller.dart';
import 'package:lightly_record/state/home_controller.dart';
import 'package:lightly_record/state/me_controller.dart';
import 'package:lightly_record/state/stats_controller.dart';
import 'package:lightly_record/state/theme_controller.dart';
import 'package:lightly_record/theme/app_theme.dart';
import 'package:lightly_record/widgets/mountain_fab.dart';

/// 主壳冒烟测试：真实装配（内存库 + 完整 Provider 树）下
/// 5 Tab 渲染 / 切换 / 状态保持 / FAB 显隐。
///
/// 说明：MainShell 的 5 个页面在 initState 里会 `context.read`
/// 各自的 Controller，且 Controller 会真实查库（内存库，零成本），
/// 因此必须提供完整 Provider 装配——裸 MaterialApp 泵入会在
/// HomePage.initState 抛 ProviderNotFoundException。
Future<void> _pumpShell(WidgetTester tester) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppConstants.dbVersion,
      onConfigure: (d) async => d.execute(Ddl.pragmaForeignKeys),
      onCreate: (d, v) async {
        final batch = d.batch();
        for (final sql in Ddl.all) {
          batch.execute(sql);
        }
        await batch.commit(noResult: true);
        await SeedData.run(d);
      },
    ),
  );
  addTearDown(db.close);

  final themeController = ThemeController();
  final appState = AppState(
    bookRepository: BookRepositoryImpl(BookDao(db)),
    categoryRepository: CategoryRepositoryImpl(CategoryDao(db)),
    prefRepository: PrefRepositoryImpl(PrefDao(db)),
    txnRepository: TxnRepositoryImpl(TxnDao(db), CategoryDao(db)),
    statsRepository: StatsRepositoryImpl(
      txnDao: TxnDao(db),
      budgetDao: BudgetDao(db),
      bookDao: BookDao(db),
    ),
    budgetRepository: BudgetRepositoryImpl(BudgetDao(db)),
    themeController: themeController,
  );
  await appState.init();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProxyProvider<AppState, HomeController>(
          create: (_) => HomeController(appState),
          update: (_, s, p) => p ?? HomeController(s),
        ),
        ChangeNotifierProxyProvider<AppState, StatsController>(
          create: (_) => StatsController(appState),
          update: (_, s, p) => p ?? StatsController(s),
        ),
        ChangeNotifierProxyProvider<AppState, CalendarController>(
          create: (_) => CalendarController(appState),
          update: (_, s, p) => p ?? CalendarController(s),
        ),
        ChangeNotifierProxyProvider<AppState, BookController>(
          create: (_) => BookController(appState),
          update: (_, s, p) => p ?? BookController(s),
        ),
        ChangeNotifierProxyProvider<AppState, MeController>(
          create: (_) => MeController(appState),
          update: (_, s, p) => p ?? MeController(s),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.buildThemeData(AppThemeId.mint),
        home: const MainShell(),
      ),
    ),
  );
  // 等首帧加载（各 Controller 查内存库 + 页面渲染）完成
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('主壳渲染 5 个 Tab，且 5 个页面全部保持挂载', (tester) async {
    await _pumpShell(tester);

    // 5 个 Tab 文案
    for (final label in ['今日', '图表', '日历', '账本', '我的']) {
      expect(find.text(label), findsOneWidget, reason: 'Tab「$label」应存在');
    }

    // IndexedStack 会把 5 个页面全部挂载（状态保持的前提）。
    // 非选中页被标记为 offstage，因此必须 skipOffstage: false 才能找到。
    expect(find.byType(HomePage, skipOffstage: false), findsOneWidget);
    expect(find.byType(StatsPage, skipOffstage: false), findsOneWidget);
    expect(find.byType(CalendarPage, skipOffstage: false), findsOneWidget);
    expect(find.byType(BooksPage, skipOffstage: false), findsOneWidget);
    expect(find.byType(MePage, skipOffstage: false), findsOneWidget);
    expect(find.byType(PillTabBar), findsOneWidget);

    // 真实页面内容抽查（不依赖时间的稳定文案）
    expect(find.text('本月支出'), findsOneWidget, reason: '今日页概览卡');
    expect(find.text('我的账本'), findsOneWidget, reason: '账本页页头');
  });

  testWidgets('切 Tab 后内容与 FAB 显隐正确', (tester) async {
    await _pumpShell(tester);

    // 默认「今日」→ FAB 显示（山峦 FAB）
    expect(find.byType(MountainFab), findsOneWidget);

    // 切到「图表」→ FAB 隐藏（图表页双分段可见）
    await tester.tap(find.text('图表'));
    await tester.pumpAndSettle();
    expect(find.byType(MountainFab), findsNothing);
    expect(find.text('本年'), findsOneWidget, reason: '图表页周期分段');

    // 切到「日历」→ FAB 重新显示（热度脚注可见）
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.byType(MountainFab), findsOneWidget);
    expect(
      find.text('颜色越深表示当天支出越多 · 点击日期查看明细'),
      findsOneWidget,
      reason: '日历脚注',
    );

    // 切到「我的」→ FAB 隐藏（菜单可见）
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.byType(MountainFab), findsNothing);
    expect(find.text('预算管理'), findsOneWidget, reason: '我的页菜单首项');

    // 切回「今日」→ FAB 恢复
    await tester.tap(find.text('今日'));
    await tester.pumpAndSettle();
    expect(find.byType(MountainFab), findsOneWidget);
  });

  testWidgets('6 套主题均可构建 MaterialApp', (tester) async {
    for (final id in AppThemeId.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildThemeData(id),
          home: const SizedBox.shrink(),
        ),
      );
      await tester.pump();
    }
  });
}
