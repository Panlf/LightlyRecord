import 'package:flutter/foundation.dart';

import '../data/model/tx_type.dart';
import '../repository/stats_repository.dart';
import 'app_state.dart';

/// 图表页 Controller：聚合 `chartBundle()`，监听 [AppState.dataVersion] 自动重载。
///
/// 与 [HomeController] 同构，额外多两个维度：
/// - `mode`（支出 / 收入）与 `period`（周 / 月 / 年）由页面切换，
///   任一变化都视为过期，强制重算；
/// - 由于 UI 上「本期」永远跟随本地今天，切换这两个维度时不需要重新取
///   `today`，只影响仓库侧的口径参数。
class StatsController extends ChangeNotifier {
  /// 注入全局状态。
  ///
  /// 不能用 `const`：`ChangeNotifier` 的构造不是 const。
  StatsController(this._appState);

  final AppState _appState;

  ChartBundle? _stats;
  bool _loading = false;
  String? _error;
  int _loadedVersion = -1;
  int _loadedBookId = -1;
  TxType _loadedMode = TxType.expense;
  Period _loadedPeriod = Period.month;

  /// 当前收支视角（默认支出）。
  TxType _mode = TxType.expense;

  /// 当前统计周期（默认本月）。
  Period _period = Period.month;

  /// 图表页数据；`null` 表示尚未加载完成。
  ChartBundle? get stats => _stats;

  /// 是否正在加载。
  bool get isLoading => _loading;

  /// 最近一次错误信息（`null` = 无错误）。
  String? get error => _error;

  /// 当前收支视角。
  TxType get mode => _mode;

  /// 当前统计周期。
  Period get period => _period;

  /// 数据是否已过期（`dataVersion` / 账本 / 视角 / 周期任一变化即重算）。
  bool get isStale =>
      _loadedVersion != _appState.dataVersion ||
      _loadedBookId != _appState.bookId ||
      _loadedMode != _mode ||
      _loadedPeriod != _period;

  /// 当前生效的基准日期。
  ///
  /// 测试可覆盖；生产环境取本地今天。
  @visibleForTesting
  DateTime Function() todayResolver = todayOf;

  /// 切换收支视角；值未变化时忽略，变化则立即重算。
  void setMode(TxType mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    load(force: true);
  }

  /// 切换统计周期；值未变化时忽略，变化则立即重算。
  void setPeriod(Period period) {
    if (period == _period) return;
    _period = period;
    notifyListeners();
    load(force: true);
  }

  /// 开始监听全局状态。
  void attach() {
    _appState.addListener(_onAppStateChanged);
  }

  /// 停止监听（页面 dispose 时调用）。
  void detach() {
    _appState.removeListener(_onAppStateChanged);
  }

  /// 立即加载 / 重算。
  ///
  /// 并发安全：同一时刻只允许一次 in-flight 请求，重复调用直接返回。
  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (!force && !isStale) return;

    final bookId = _appState.bookId;
    if (bookId <= 0) return;

    final mode = _mode;
    final period = _period;
    final versionBefore = _appState.dataVersion;
    // in-flight 期间用户又切了视角 / 周期 / 账本，或别处写入导致版本漂移
    // （需要丢弃本次结果并重拉，否则会把旧数据盖上新的版本号）。
    var superseded = false;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _appState.stats.chartBundle(
        bookId,
        mode,
        period,
        todayResolver(),
      );
      if (mode != _mode ||
          period != _period ||
          versionBefore != _appState.dataVersion ||
          bookId != _appState.bookId) {
        superseded = true;
      } else {
        _stats = result;
        _error = null;
        _loadedVersion = _appState.dataVersion;
        _loadedBookId = bookId;
        _loadedMode = mode;
        _loadedPeriod = period;
      }
    } catch (e) {
      _error = '数据加载失败，请稍后重试';
      debugPrint('StatsController.load failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }

    // 被更新的请求顶掉 → 立刻用新参数重拉（此时 `_loading` 已复位）。
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
