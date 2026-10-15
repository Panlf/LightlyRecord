import 'package:flutter/foundation.dart';

import '../repository/stats_repository.dart';
import 'app_state.dart';

/// 我的页 Controller：全局口径统计（跨全部账本）。
///
/// 与 [BookController] 的本账本口径刻意区分：我的页三宫格带
/// 「全部」标签，账本页统计卡带「本账本」标签，两处数字
/// 不再矛盾（架构文档 §T05 验收要点）。
class MeController extends ChangeNotifier {
  /// 注入全局状态。
  MeController(this._appState);

  final AppState _appState;

  GlobalStats? _stats;
  int _bookCount = 0;
  bool _loading = false;
  String? _error;
  int _loadedVersion = -1;

  /// 全局统计（totalCount / bookCount / streakDays / persistDays）。
  GlobalStats? get stats => _stats;

  /// 账本总数（与 stats.bookCount 同源，单独暴露便于空态判断）。
  int get bookCount => _bookCount;

  /// 是否正在加载。
  bool get isLoading => _loading;

  /// 最近一次错误信息（`null` = 无错误）。
  String? get error => _error;

  /// 数据是否已过期（`dataVersion` 已变但还没重算）。
  ///
  /// 我的页是全局口径，不随当前账本切换变化，因此只监听
  /// `dataVersion`，不监听 bookId。
  bool get isStale => _loadedVersion != _appState.dataVersion;

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
  /// in-flight 期间发生写操作（`bumpData`）导致版本漂移时，丢弃本次
  /// 结果并自动重拉，避免旧数据盖上新版本号。
  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (!force && !isStale) return;

    final versionBefore = _appState.dataVersion;
    var superseded = false;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final stats = await _appState.stats.globalStats(todayResolver());
      final bookCount = await _appState.bookRepo.count();
      if (versionBefore != _appState.dataVersion) {
        superseded = true;
      } else {
        _stats = stats;
        _bookCount = bookCount;
        _error = null;
        _loadedVersion = _appState.dataVersion;
      }
    } catch (e) {
      _error = '数据加载失败，请稍后重试';
      debugPrint('MeController.load failed: $e');
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
