import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';
import '../db/app_database.dart';
import '../model/txn.dart';
import '../model/tx_type.dart';

/// `txn` 表 CRUD + 各类区间聚合 SQL。
///
/// 约定：
/// - 聚合方法返回**裸 Map / int**，由 Repository 负责转成上层数据结构
///   （DAO 不 import Repository，保持分层单向）；
/// - `tx_date` 一律 `'YYYY-MM-DD'` 字符串区间比较，走 `idx_txn_book_date` 索引。
class TxnDao {
  /// 注入连接（测试可传内存库）。
  const TxnDao(this._db);

  final Database _db;

  /// 使用全局单例连接构造。
  static Future<TxnDao> create() async => TxnDao(await AppDatabase.instance);

  /// 底层连接（供 Repository 执行清库 / 载入示例数据等批处理）。
  DatabaseExecutor get executor => _db;

  static const String _table = 'txn';

  /// 关联分类的查询列（`category_*` 为 join 出的运行时字段）。
  static const String _joinedColumns = '''
t.id, t.book_id, t.category_id, t.type, t.amount_minor, t.note,
t.tx_date, t.tx_time, t.created_at, t.updated_at,
c.name AS category_name, c.color_bg AS category_color_bg,
c.color_stroke AS category_color_stroke, c.icon_codepoint AS category_icon_codepoint
''';

  static const String _joinedFrom = 'txn t LEFT JOIN category c ON c.id = t.category_id';

  // ---------------------------------------------------------------- CRUD

  /// 插入并返回自增 id。
  ///
  /// `toMap()` 不含 `id`，交由 SQLite AUTOINCREMENT 分配。
  Future<int> insert(Txn txn) async {
    return _db.insert(_table, txn.toMap());
  }

  /// 批量插入（示例数据用）。
  Future<void> insertAll(List<Txn> txns) async {
    final batch = _db.batch();
    for (final t in txns) {
      batch.insert(_table, t.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// 更新（整行，按 `id`）。
  Future<int> update(Txn txn) async {
    return _db.update(_table, txn.toMap(), where: 'id = ?', whereArgs: [txn.id]);
  }

  /// 删除（硬删，P2 无回收站）。
  Future<int> delete(int id) async {
    return _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// 按 id 查询（含分类关联）。
  Future<Txn?> findById(int id) async {
    final rows = await _db.rawQuery(
      'SELECT $_joinedColumns FROM $_joinedFrom WHERE t.id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return Txn.fromMapJoined(rows.first);
  }

  // ---------------------------------------------------------------- 明细

  /// 某账本某日明细（按时间升序，同日按 `created_at` 次级排序）。
  Future<List<Txn>> listByDate(int bookId, String date) async {
    final rows = await _db.rawQuery(
      'SELECT $_joinedColumns FROM $_joinedFrom '
      "WHERE t.book_id = ? AND t.tx_date = ? ORDER BY t.tx_time ASC, t.created_at ASC, t.id ASC",
      [bookId, date],
    );
    return rows.map(Txn.fromMapJoined).toList();
  }

  /// 某账本闭区间明细（`from` ~ `to`，按日期 + 时间升序）。
  Future<List<Txn>> listByRange(int bookId, String from, String to) async {
    final rows = await _db.rawQuery(
      'SELECT $_joinedColumns FROM $_joinedFrom '
      "WHERE t.book_id = ? AND t.tx_date BETWEEN ? AND ? "
      'ORDER BY t.tx_date ASC, t.tx_time ASC, t.id ASC',
      [bookId, from, to],
    );
    return rows.map(Txn.fromMapJoined).toList();
  }

  // ---------------------------------------------------------------- 区间聚合

  /// 某账本闭区间某类型的金额合计（分）。
  Future<int> sumByRange(int bookId, String from, String to, TxType type) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(t.amount_minor), 0) AS s FROM $_table t '
      "WHERE t.book_id = ? AND t.tx_date BETWEEN ? AND ? AND t.type = ?",
      [bookId, from, to, type.code],
    );
    return _toInt(rows, 's');
  }

  /// 全账本闭区间某类型的金额合计（分）—— 预算「已用」跨账本汇总用。
  Future<int> sumByRangeAllBooks(String from, String to, TxType type) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS s FROM $_table '
      "WHERE tx_date BETWEEN ? AND ? AND type = ?",
      [from, to, type.code],
    );
    return _toInt(rows, 's');
  }

  /// 某账本某日某类型的金额合计（分）。
  Future<int> sumByDate(int bookId, String date, TxType type) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS s FROM $_table '
      'WHERE book_id = ? AND tx_date = ? AND type = ?',
      [bookId, date, type.code],
    );
    return _toInt(rows, 's');
  }

  /// 某账本某日笔数。
  Future<int> countByDate(int bookId, String date) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE book_id = ? AND tx_date = ?',
      [bookId, date],
    );
    return _toInt(rows, 'c');
  }

  /// 全库交易总笔数（我的页全局口径）。
  Future<int> countAll({int? bookId}) async {
    final rows = bookId == null
        ? await _db.rawQuery('SELECT COUNT(*) AS c FROM $_table')
        : await _db.rawQuery(
            'SELECT COUNT(*) AS c FROM $_table WHERE book_id = ?',
            [bookId],
          );
    return _toInt(rows, 'c');
  }

  // ---------------------------------------------------------------- 图表聚合

  /// 按分类聚合（降序）。
  ///
  /// 返回列：`category_id` / `name` / `color_bg` / `color_stroke` / `amount_minor`。
  /// 占比由 Repository 计算（DAO 不产生业务口径）。
  Future<List<Map<String, Object?>>> groupByCategory(
    int bookId,
    String from,
    String to,
    TxType type,
  ) async {
    return _db.rawQuery(
      '''
SELECT t.category_id AS category_id,
       COALESCE(c.name, '其他')      AS name,
       COALESCE(c.color_bg, '${AppConstants.defaultCategoryColorBg}')     AS color_bg,
       COALESCE(c.color_stroke, '${AppConstants.defaultCategoryColorStroke}') AS color_stroke,
       SUM(t.amount_minor)           AS amount_minor
FROM txn t
LEFT JOIN category c ON c.id = t.category_id
WHERE t.book_id = ? AND t.tx_date BETWEEN ? AND ? AND t.type = ?
GROUP BY t.category_id
ORDER BY amount_minor DESC, t.category_id ASC
''',
      [bookId, from, to, type.code],
    );
  }

  /// 日历热度：某账本某月「每日支出合计」。
  ///
  /// 返回 `{ 'YYYY-MM-DD': amountMinor }`，仅包含有支出的日期。
  Future<Map<String, int>> dailyExpenseInMonth(
    int bookId,
    int year,
    int month,
  ) async {
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final to = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final rows = await _db.rawQuery(
      '''
SELECT tx_date, SUM(amount_minor) AS s
FROM $_table
WHERE book_id = ? AND tx_date BETWEEN ? AND ? AND type = ?
GROUP BY tx_date
''',
      [bookId, from, to, TxType.expense.code],
    );
    return {
      for (final r in rows)
        r['tx_date'] as String: _asInt(r['s']),
    };
  }

  /// 日历热度：某账本某月「每日收入合计」。
  Future<Map<String, int>> dailyIncomeInMonth(
    int bookId,
    int year,
    int month,
  ) async {
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final to = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final rows = await _db.rawQuery(
      '''
SELECT tx_date, SUM(amount_minor) AS s
FROM $_table
WHERE book_id = ? AND tx_date BETWEEN ? AND ? AND type = ?
GROUP BY tx_date
''',
      [bookId, from, to, TxType.income.code],
    );
    return {
      for (final r in rows)
        r['tx_date'] as String: _asInt(r['s']),
    };
  }

  // ---------------------------------------------------------------- 打卡 / 天数

  /// 有交易的日期集合（升序；`bookId = null` 表示全局）。
  Future<List<String>> distinctDates({int? bookId, String? from, String? to}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (bookId != null) {
      where.add('book_id = ?');
      args.add(bookId);
    }
    if (from != null) {
      where.add('tx_date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('tx_date <= ?');
      args.add(to);
    }
    final clause = where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}';
    final rows = await _db.rawQuery(
      'SELECT DISTINCT tx_date FROM $_table$clause ORDER BY tx_date ASC',
      args,
    );
    return rows.map((r) => r['tx_date'] as String).toList();
  }

  /// 首次记账日期（`bookId = null` 表示全局）；无记录返回 `null`。
  Future<String?> firstTxDate({int? bookId}) async {
    final rows = bookId == null
        ? await _db.rawQuery('SELECT MIN(tx_date) AS d FROM $_table')
        : await _db.rawQuery(
            'SELECT MIN(tx_date) AS d FROM $_table WHERE book_id = ?',
            [bookId],
          );
    if (rows.isEmpty) return null;
    return rows.first['d'] as String?;
  }

  /// 最近一笔交易的 `updated_at`（无记录返回 `null`）。
  Future<int?> lastUpdatedAt({int? bookId}) async {
    final rows = bookId == null
        ? await _db.rawQuery('SELECT MAX(updated_at) AS u FROM $_table')
        : await _db.rawQuery(
            'SELECT MAX(updated_at) AS u FROM $_table WHERE book_id = ?',
            [bookId],
          );
    if (rows.isEmpty) return null;
    return rows.first['u'] as int?;
  }

  /// 全部交易（导出用，按日期时间升序）。
  Future<List<Txn>> listAll() async {
    final rows = await _db.rawQuery(
      'SELECT $_joinedColumns FROM $_joinedFrom ORDER BY t.tx_date ASC, t.tx_time ASC, t.id ASC',
    );
    return rows.map(Txn.fromMapJoined).toList();
  }

  /// 裸 SQL 聚合转 int。
  int _toInt(List<Map<String, Object?>> rows, String column) {
    if (rows.isEmpty) return 0;
    return _asInt(rows.first[column]);
  }

  /// 宽松转 int（兼容 sqflite 在不同平台返回 int / num / String）。
  int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
