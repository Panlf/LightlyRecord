import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../model/budget.dart';

/// `budget` 表单行读写（upsert `id = 1`）。
class BudgetDao {
  /// 注入连接（测试可传内存库）。
  const BudgetDao(this._db);

  final Database _db;

  /// 使用全局单例连接构造。
  static Future<BudgetDao> create() async =>
      BudgetDao(await AppDatabase.instance);

  static const String _table = 'budget';

  /// 单行 id（CHECK 约束强制）。
  static const int singleRowId = 1;

  /// 读取预算；不存在时返回 `enabled = false` 的默认值。
  Future<Budget> get() async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [singleRowId]);
    if (rows.isEmpty) {
      return const Budget(monthlyAmountMinor: 0, enabled: false, updatedAt: 0);
    }
    return Budget.fromMap(rows.first);
  }

  /// 保存预算（upsert `id = 1`）。
  ///
  /// 使用 `ConflictAlgorithm.replace` 保证幂等。
  Future<void> save({
    required bool enabled,
    required int monthlyAmountMinor,
    required int updatedAt,
  }) async {
    await _db.insert(
      _table,
      {
        'id': singleRowId,
        'monthly_amount_minor': monthlyAmountMinor,
        'enabled': enabled ? 1 : 0,
        'updated_at': updatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
