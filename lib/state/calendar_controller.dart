import 'package:flutter/foundation.dart';

import '../core/date_ext.dart';
import '../repository/stats_repository.dart';
import 'app_state.dart';

/// 日历页 Controller：聚合 `calendarMonth()`，监听 [AppState.dataVersion] 自动重载。
///
/// 自身持有「当前显示年月 + 选中日」，这两个是**纯 UI 状态**（不落库），
/// 因此不参与 `isStale` 判定——翻月 / 选日一律显式 `load(force: true)`；
/// 只有 `dataVersion` / 账本变化才走 `attach()` 的被动重算。
///
/// 年月 / 选中日采用**懒初始化**：未被显式设置过时一律回落
/// [todayResolver]，因此测试可以在构造后覆盖 `todayResolver` 再 `load()`，
/// 不需要先手动 `goToToday()`。
class CalendarController extends ChangeNotifier {
  /// 注入全局状态。
  ///
  /// 不能用 `const`：`ChangeNotifier` 的构造不是 const。
  CalendarController(this._appState);

  final AppState _appState;

  CalendarMonth? _data;
  bool _loading = false;
  String? _error;
  int _loadedVersion = -1;
  int _loadedBookId = -1;

  int? _year;
  int? _month;
  DateTime? _selected;

  /// 日历数据；`null` 表示尚未加载完成。
  CalendarMonth? get data => _data;

  /// 是否正在加载。
  bool get isLoading => _loading;

  /// 最近一次错误信息（`null` = 无错误）。
  String? get error => _error;

  /// 当前显示年（未显式设置过 → 今天所在年）。
  int get year => _year ?? _today().year;

  /// 当前显示月（1~12；未显式设置过 → 今天所在月）。
  int get month => _month ?? _today().month;

  /// 当前选中日（本地，时间归零；未显式设置过 → 今天）。
  DateTime get selected => _selected ?? _today();

  /// 数据是否已过期（`dataVersion` 或账本已变但还没重算）。
  bool get isStale =>
      _loadedVersion != _appState.dataVersion ||
      _loadedBookId != _appState.bookId;

  /// 当前生效的基准日期（同时决定初始年月与选中日）。
  ///
  /// 测试可覆盖；生产环境取本地今天。
  @visibleForTesting
  DateTime Function() todayResolver = todayOf;

  /// 上一月（跨年自动进位：1 月 → 上年 12 月）。
  ///
  /// 选中日不在新月内时重置为新月 1 号，避免选中一个看不见的日期。
  void prevMonth() {
    final target = addMonths(DateTime(year, month, 1), -1);
    _year = target.year;
    _month = target.month;
    _resetSelectionIfOutside();
    notifyListeners();
    load(force: true);
  }

  /// 下一月（跨年自动进位：12 月 → 下年 1 月）。
  void nextMonth() {
    final target = addMonths(DateTime(year, month, 1), 1);
    _year = target.year;
    _month = target.month;
    _resetSelectionIfOutside();
    notifyListeners();
    load(force: true);
  }

  /// 选中某一天；仅当该日落在当前显示月内才生效。
  void selectDay(DateTime day) {
    final d = startOfDay(day);
    if (d.year != year || d.month != month) return;
    if (isSameDay(d, selected)) return;
    _selected = d;
    notifyListeners();
    load(force: true);
  }

  /// 回到今天（年月与选中日一并归位）。
  void goToToday() {
    final t = _today();
    _year = t.year;
    _month = t.month;
    _selected = t;
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
  /// 并发安全：同一时刻只允许一次 in-flight 请求，重复调用直接返回；
  /// in-flight 期间用户翻月 / 选日 / 别处写入导致参数漂移时，本次结果
  /// 丢弃并在 `_loading` 复位后用新参数自动重拉——否则会出现
  /// 「标题是 11 月、格子是 10 月」或数据版本被盖新的陈旧显示。
  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (!force && !isStale) return;

    final bookId = _appState.bookId;
    if (bookId <= 0) return;

    // 一次性取快照，避免 in-flight 期间用户翻月导致参数漂移。
    final year = this.year;
    final month = this.month;
    final selected = this.selected;
    final today = _today();
    final versionBefore = _appState.dataVersion;
    var superseded = false;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _appState.stats.calendarMonth(
        bookId,
        year,
        month,
        today,
        selected: selected,
      );
      // 查询期间参数漂移（翻月 / 选日 / 切账本 / 别处写入 / 跨午夜）
      // → 丢弃本次结果，finally 之后用新参数重拉。
      if (year != this.year ||
          month != this.month ||
          !isSameDay(selected, this.selected) ||
          !isSameDay(today, _today()) ||
          versionBefore != _appState.dataVersion ||
          bookId != _appState.bookId) {
        superseded = true;
      } else {
        _data = result;
        _error = null;
        _loadedVersion = _appState.dataVersion;
        _loadedBookId = bookId;
      }
    } catch (e) {
      _error = '数据加载失败，请稍后重试';
      debugPrint('CalendarController.load failed: $e');
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

  /// 基准今天（本地，时间归零）。
  DateTime _today() => startOfDay(todayResolver());

  /// 翻月后选中日不在新月内 → 重置为新月 1 号。
  void _resetSelectionIfOutside() {
    if (_selected == null) return;
    if (_selected!.year == year && _selected!.month == month) return;
    _selected = DateTime(year, month, 1);
  }
}
