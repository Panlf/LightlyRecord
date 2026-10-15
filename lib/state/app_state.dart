import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/date_ext.dart';
import '../repository/book_repository.dart';
import '../repository/budget_repository.dart';
import '../repository/category_repository.dart';
import '../repository/pref_repository.dart';
import '../repository/stats_repository.dart';
import '../repository/txn_repository.dart';
import 'theme_controller.dart';

/// 全局应用状态：当前账本 + `dataVersion` 版本号总线。
///
/// **为什么用版本号而不是事件**：记一笔 / 编辑 / 删除 / 切换账本之后，
/// 首页、日历、图表、账本、我的 5 个页面的数字全部要重算。若每个页面各自
/// 监听 Repository，容易出现「A 页面已刷新、B 页面还是旧值」的中间态。
/// 这里只维护一个自增整数 [dataVersion]，所有写操作结束后 `bumpData()`，
/// 各 Controller 监听它即可保证**同一帧内全部一起重算**。
///
/// 分层位置：`pages → state → repository`，UI 禁止直接接触 DAO。
class AppState extends ChangeNotifier {
  /// 注入依赖。
  ///
  /// 不能用 `const`：`ChangeNotifier` 的构造不是 const。
  AppState({
    required BookRepository bookRepository,
    required CategoryRepository categoryRepository,
    required PrefRepository prefRepository,
    required TxnRepository txnRepository,
    required StatsRepository statsRepository,
    required BudgetRepository budgetRepository,
    required ThemeController themeController,
  })  : _bookRepository = bookRepository,
        _categoryRepository = categoryRepository,
        _prefRepository = prefRepository,
        _txnRepository = txnRepository,
        _statsRepository = statsRepository,
        _budgetRepository = budgetRepository,
        _themeController = themeController;

  final BookRepository _bookRepository;
  final CategoryRepository _categoryRepository;
  final PrefRepository _prefRepository;
  final TxnRepository _txnRepository;
  final StatsRepository _statsRepository;
  final BudgetRepository _budgetRepository;
  final ThemeController _themeController;

  /// 全局单例（由 `main.dart` 构造后经 `MultiProvider` 下发）。
  ///
  /// 仅用于「无 context 场景」（如保存后需要触发全局刷新）；
  /// 正常路径请从 `BuildContext` 取，便于测试替换。
  static AppState? instance;

  int _bookId = 0;
  String _bookName = '';
  String _nickname = '';
  int _dataVersion = 0;
  bool _ready = false;

  /// 当前账本 id（0 = 尚未初始化）。
  int get bookId => _bookId;

  /// 当前账本名（跟随账本切换联动）。
  String get bookName => _bookName;

  /// 用户昵称（首页问候语 / 我的页共用，编辑后全机联动）。
  String get nickname => _nickname;

  /// 数据版本号；每次写操作 +1。
  int get dataVersion => _dataVersion;

  /// 是否已完成初始化（账本已就绪）。
  bool get isReady => _ready;

  /// 主题控制器（与 [AppState] 同生命周期，由 `MultiProvider` 一并下发）。
  ThemeController get themeController => _themeController;

  /// 统计口径入口（UI 层唯一允许的取数通道）。
  StatsRepository get stats => _statsRepository;

  /// 交易写操作入口。
  TxnRepository get txnRepo => _txnRepository;

  /// 账本入口。
  BookRepository get bookRepo => _bookRepository;

  /// 分类入口。
  CategoryRepository get categoryRepo => _categoryRepository;

  /// 偏好入口。
  PrefRepository get prefRepo => _prefRepository;

  /// 预算入口（全局单份，我的页预算管理用）。
  BudgetRepository get budgetRepo => _budgetRepository;

  /// 初始化：恢复当前账本 → 标记就绪。
  ///
  /// pref 无记录 / 账本已被删时退化为默认账本（不存在则创建）。
  Future<void> init() async {
    final storedId = await _prefRepository.currentBookId();
    var book = storedId == null ? null : await _bookRepository.getById(storedId);
    book ??= await _bookRepository.ensureDefault();

    _bookId = book.id;
    _bookName = book.name;
    _nickname = await _prefRepository.nickname();
    _ready = true;
    notifyListeners();
  }

  /// 切换账本：先落盘再通知，保证冷启动后仍是这一个。
  Future<void> selectBook(int bookId) async {
    if (bookId == _bookId) return;
    final book = await _bookRepository.getById(bookId);
    if (book == null) return;
    _bookId = book.id;
    _bookName = book.name;
    await _prefRepository.setCurrentBookId(book.id);
    notifyListeners();
  }

  /// 账本被重命名后同步页头展示。
  void refreshBookName(String name) {
    if (name.trim().isEmpty || name == _bookName) return;
    _bookName = name;
    notifyListeners();
  }

  /// 昵称被修改后同步首页问候语 / 我的页展示。
  ///
  /// 落盘由调用方（我的页）经 [PrefRepository.setNickname] 完成，
  /// 这里只负责广播；空值回落默认昵称，与仓库口径一致。
  void refreshNickname(String name) {
    final trimmed = name.trim();
    final next = trimmed.isEmpty ? fallbackNickname() : trimmed;
    if (next == _nickname) return;
    _nickname = next;
    notifyListeners();
  }

  /// 数据变更：版本号 +1，触发所有 Controller 重算。
  ///
  /// 任何写操作（记一笔 / 编辑 / 删除 / 载入示例数据 / 清空）之后都必须调用。
  void bumpData() {
    _dataVersion++;
    notifyListeners();
  }

  /// 供测试 / 热重置使用：清空单例引用。
  @visibleForTesting
  static void debugResetInstance() => instance = null;
}

/// 今日基准日期（供 Controller 复用；抽成函数便于测试注入）。
///
/// 单独放一个顶层函数而不是 `AppState.today()`，避免测试时为了改一天
/// 就要 mock 整个 AppState。
DateTime todayOf() => today();

/// 默认昵称兜底（与 seed 一致）。
String fallbackNickname() => AppConstants.defaultNickname;
