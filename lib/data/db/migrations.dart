import 'package:sqflite/sqflite.dart';

import '../ddl.dart';

/// 版本化迁移脚本列表。
///
/// **纪律**：
/// - `scripts[n]` 负责把库从 `n-1` 升级到 `n`；
/// - v1 由 `onCreate` 全量建表，因此 `scripts` 中**没有** `1` 条目；
/// - 任何表结构变更必须新增 `scripts[n]` 条目并同步 `AppConstants.dbVersion`，
///   **禁止修改 [Ddl.all] 中已发布的语句**。
class Migrations {
  const Migrations._();

  /// 目标版本 → 迁移脚本。
  static const Map<int, Future<void> Function(Database db)?> scripts = {
    // 1: null, // v1 由 onCreate 全量建表
  };

  /// 依次执行 `from+1 .. to` 的增量脚本。
  ///
  /// 缺失脚本的版本会被跳过（并打印日志），不会中断升级流程。
  static Future<void> run(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      final script = scripts[v];
      if (script == null) {
        continue;
      }
      await script(db);
    }
  }
}
