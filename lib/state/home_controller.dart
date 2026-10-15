import 'package:flutter/foundation.dart';

import '../repository/stats_repository.dart';
import 'app_state.dart';

/// 今日页 Controller：聚合首页全部数据，监听 [AppState.dataVersion] 自动重载。
///
/// 设计要点：
/// - **不在自己体内持有账本 id**，每次 `load()` 都从 [AppState] 现取，
///   保证「切账本 → 首页数字立刻变」不需要额外发事件；
/// - 监听 `dataVersion` + `bookId` 两个信号，任一变化即重算；
/// - 计算期间置 `loading`，失败置 `error` 并保留上一次的成功数据
///   （避免网络/IO 抖动把用户已看到的数字清成 0）。
class HomeController extends ChangeNotifier {
  /// 注入全局状态。
  ///
  /// 不能用 `const`：`ChangeNotifier` 的构造不是 const。
  HomeController(this._appState);

  final AppState _appState;

  HomeStats? _stats;
  bool _loading = false;
  String? _error;
  int _loadedVersion = -1;
  int _loadedBookId = -1;

  /// 今日页数据；`null` 表示尚未加载完成。
  HomeStats? get stats => _stats;

  /// 是否正在加载。
  bool get isLoading => _loading;

  /// 最近一次错误信息（`null` = 无错误）。
  String? get error => _error;

  /// 数据是否已过期（`dataVersion` 或账本已变但还没重算）。
  bool get isStale =>
      _loadedVersion != _appState.dataVersion ||
      _loadedBookId != _appState.bookId;

  /// 当前生效的基准日期。
  ///
  /// 测试可覆盖；生产环境取本地今天。
  @visibleForTesting
  DateTime Function() todayResolver = todayOf;

  /// 开始监听全局状态。
  ///
  /// 在 `MultiProvider` 里用 `ChangeNotifierProvider.value` + 手动
  /// `addListener`，或由页面 `initState` 调用一次。
  void attach() {
    _appState.addListener(_onAppStateChanged);
  }

  /// 停止监听（页面 dispose 时调用）。
  void detach() {
    _appState.removeListener(_onAppStateChanged);
  }

  /// 立即加载 / 重算。
  ///
  /// 并发安全：同一时刻只允许一次 in-flight 请求，重复调用直接返回；
  /// in-flight 期间发生写操作（`bumpData`）或切账本导致参数漂移时，
  /// 丢弃本次结果并在 `_loading` 复位后自动重拉——否则旧数据会被
  /// 盖上新的版本号，isStale 恒 false，页面停留在陈旧数字上。
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
      final result = await _appState.stats.homeStats(bookId, todayResolver());
      if (versionBefore != _appState.dataVersion || bookId != _appState.bookId) {
        superseded = true;
      } else {
        _stats = result;
        _error = null;
        _loadedVersion = _appState.dataVersion;
        _loadedBookId = bookId;
      }
    } catch (e) {
      _error = '数据加载失败，请稍后重试';
      debugPrint('HomeController.load failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }

    if (superseded) {
      await load(force: true);
    }
  }

  void _onAppStateChanged() {
    if (isStale) {
      load();
    }
  }
}
