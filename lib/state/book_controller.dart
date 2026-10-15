import 'package:flutter/foundation.dart';

import '../data/model/book.dart';
import '../repository/stats_repository.dart';
import 'app_state.dart';

/// 账本页数据：账本列表 + 每本统计 + 当前账本统计卡。
///
/// 设计要点与 [HomeController] 一致：
/// - 不在自己体内持有账本 id，每次 `load()` 从 [AppState] 现取，
///   保证「切账本 → 账本页选中态与统计卡立刻变」；
/// - 监听 `dataVersion` + `bookId`，任一变化即重算；
/// - 写操作（新建 / 重命名 / 删除 / 切换）统一走 Repository +
///   [AppState]，失败以 Toast 反馈，页面不直接碰 DAO。
class BookController extends ChangeNotifier {
  /// 注入全局状态。
  BookController(this._appState);

  final AppState _appState;

  List<Book> _books = const [];
  BookStats? _stats;
  bool _loading = false;
  String? _error;
  int _loadedVersion = -1;
  int _loadedBookId = -1;

  /// 每本账本的交易笔数（列表行副标题用）。
  final Map<int, int> _txnCounts = {};

  /// 每本账本累计支出（分，列表行右侧金额用）。
  final Map<int, int> _totalExpense = {};

  /// 每本账本最近一笔交易的更新时间（epoch ms；无交易为 null）。
  final Map<int, int?> _lastUpdatedAt = {};

  /// 账本列表（未归档优先，按 sort_order 升序）。
  List<Book> get books => _books;

  /// 当前账本统计卡数据（本账本口径）。
  BookStats? get stats => _stats;

  /// 每本账本的交易笔数。
  Map<int, int> get txnCounts => _txnCounts;

  /// 每本账本累计支出（分）。
  Map<int, int> get totalExpense => _totalExpense;

  /// 每本账本最近更新时间（epoch ms）。
  Map<int, int?> get lastUpdatedAt => _lastUpdatedAt;

  /// 是否正在加载。
  bool get isLoading => _loading;

  /// 最近一次错误信息（`null` = 无错误）。
  String? get error => _error;

  /// 数据是否已过期（`dataVersion` 或账本已变但还没重算）。
  bool get isStale =>
      _loadedVersion != _appState.dataVersion ||
      _loadedBookId != _appState.bookId;

  /// 当前生效的基准日期（测试可覆盖）。
  @visibleForTesting
  DateTime Function() todayResolver = todayOf;

  /// 开始监听全局状态。
  void attach() {
    _appState.addListener(_onAppStateChanged);
  }

  /// 停止监听（页面 dispose 时调用）。
  void detach() {
    _appState.removeListener(_onAppStateChanged);
  }

  /// 立即加载 / 重算（并发安全：同一时刻只允许一次 in-flight）。
  ///
  /// in-flight 期间发生写操作（`bumpData`）或切账本导致参数漂移时，
  /// 丢弃本次结果并自动重拉，避免旧数据盖上新版本号。
  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (!force && !isStale) return;

    final bookId = _appState.bookId;
    if (bookId <= 0) return;

    final versionBefore = _appState.dataVersion;
    var superseded = false;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final books = await _appState.bookRepo.list();
      final stats = await _appState.stats.bookStats(bookId, todayResolver());
      // 行内副标题数据：逐本取笔数 / 累计支出 / 最近更新时间
      // （账本数量通常 < 10，三次轻查询可接受；避免页面层直接调
      // Repository 破坏分层）。
      final counts = <int, int>{};
      final expense = <int, int>{};
      final lastAt = <int, int?>{};
      for (final b in books) {
        counts[b.id] = await _appState.bookRepo.txnCount(b.id);
        expense[b.id] = await _appState.bookRepo.totalExpenseMinor(b.id);
        lastAt[b.id] = await _appState.bookRepo.lastTxnUpdatedAt(b.id);
      }
      if (versionBefore != _appState.dataVersion || bookId != _appState.bookId) {
        superseded = true;
      } else {
        _books = books;
        _stats = stats;
        _txnCounts
          ..clear()
          ..addAll(counts);
        _totalExpense
          ..clear()
          ..addAll(expense);
        _lastUpdatedAt
          ..clear()
          ..addAll(lastAt);
        _error = null;
        _loadedVersion = _appState.dataVersion;
        _loadedBookId = bookId;
      }
    } catch (e) {
      _error = '数据加载失败，请稍后重试';
      debugPrint('BookController.load failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }

    if (superseded) {
      await load(force: true);
    }
  }

  /// 新建账本并立即切换过去。
  ///
  /// 返回 `null` 表示成功；否则为面向用户的错误文案。
  Future<String?> createBook(String name) async {
    try {
      final id = await _appState.bookRepo.create(name: name);
      await _appState.selectBook(id);
      return null;
    } catch (e) {
      debugPrint('BookController.createBook failed: $e');
      return '新建账本失败，请稍后重试';
    }
  }

  /// 重命名账本；**仅当改的是当前账本**才同步页头展示，
  /// 否则会把非当前账本的名字写到首页标题上。
  Future<String?> renameBook(int id, String name) async {
    final result = await _appState.bookRepo.rename(id, name);
    if (result.isFailure) return result.messageOrNull ?? '重命名失败';
    if (id == _appState.bookId) {
      final book = await _appState.bookRepo.getById(id);
      if (book != null) _appState.refreshBookName(book.name);
    }
    return null;
  }

  /// 删除账本；默认账本由仓库层拒绝。
  ///
  /// 删除的是当前账本时，先切到另一本再删，避免出现
  /// 「当前账本已不存在」的中间态；若只剩默认账本，删除会被
  /// 仓库层拒绝，无需切换。
  Future<String?> deleteBook(int id) async {
    if (id == _appState.bookId) {
      // 优先用已加载列表；尚未加载过时实时查库，保证删当前账本前
      // 一定先切走（否则 bookId 会指向已删除的账本）。
      final all = _books.isNotEmpty ? _books : await _appState.bookRepo.list();
      final other = all.where((b) => b.id != id).toList();
      if (other.isNotEmpty) {
        await _appState.selectBook(other.first.id);
      }
    }
    final result = await _appState.bookRepo.delete(id);
    if (result.isFailure) return result.messageOrNull ?? '删除失败';
    // 列表与统计卡立即重算（删的可能是非当前账本，也要刷新列表）
    _appState.bumpData();
    return null;
  }

  /// 切换账本（同一本不重复触发）。
  Future<String?> switchBook(int id) async {
    if (id == _appState.bookId) return null;
    await _appState.selectBook(id);
    return null;
  }

  void _onAppStateChanged() {
    if (isStale) {
      load();
    }
  }
}
