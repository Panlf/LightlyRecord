import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../model/book.dart';

/// `book` 表 CRUD + 计数 / 累计支出聚合。
class BookDao {
  /// 注入连接（测试可传内存库）。
  const BookDao(this._db);

  final Database _db;

  /// 使用全局单例连接构造（连接由 `AppDatabase.instance` 打开）。
  static Future<BookDao> create() async => BookDao(await AppDatabase.instance);

  static const String _table = 'book';

  /// 全部账本（未归档优先，再按 `sort_order` / `id` 升序）。
  Future<List<Book>> list() async {
    final rows = await _db.query(
      _table,
      orderBy: 'archived ASC, sort_order ASC, id ASC',
    );
    return rows.map(Book.fromMap).toList();
  }

  /// 按 id 查询。
  Future<Book?> findById(int id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  /// 默认账本（`is_default = 1`）。
  Future<Book?> findDefault() async {
    final rows = await _db.query(_table, where: 'is_default = 1', limit: 1);
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  /// 插入并返回自增 id。
  ///
  /// `toMap()` 里的 `id` 必须剔除：显式传 `id = 0` 会让 SQLite 把 rowid 钉成 0，
  /// 从而破坏 AUTOINCREMENT。
  Future<int> insert(Book book) async {
    return _db.insert(_table, book.toMap()..remove('id'));
  }

  /// 更新（整行）。
  Future<int> update(Book book) async {
    return _db.update(_table, book.toMap(), where: 'id = ?', whereArgs: [book.id]);
  }

  /// 仅更新名称。
  Future<int> updateName(int id, String name, int updatedAt) async {
    return _db.update(
      _table,
      {'name': name, 'updated_at': updatedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新图标 / 图标色。
  Future<int> updateIcon(int id, String iconKey, String iconColor, int updatedAt) async {
    return _db.update(
      _table,
      {'icon_key': iconKey, 'icon_color': iconColor, 'updated_at': updatedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 刷新 `updated_at`。
  Future<int> touch(int id, int updatedAt) async {
    return _db.update(
      _table,
      {'updated_at': updatedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除账本（级联删除其交易）。
  Future<int> delete(int id) async {
    return _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// 账本总数。
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return _firstInt(rows, 'c');
  }

  /// 下一个排序序号（`MAX(sort_order) + 1`）。
  Future<int> nextSortOrder() async {
    final rows =
        await _db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) + 1 AS n FROM $_table');
    return _firstInt(rows, 'n');
  }

  /// 该账本累计支出（分，全部时间）。
  Future<int> totalExpenseMinor(int bookId) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount_minor), 0) AS s FROM txn '
      'WHERE book_id = ? AND type = ?',
      [bookId, 1],
    );
    return _firstInt(rows, 's');
  }

  /// 该账本交易笔数。
  Future<int> txnCount(int bookId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM txn WHERE book_id = ?',
      [bookId],
    );
    return _firstInt(rows, 'c');
  }

  /// 该账本最近一笔交易的 `updated_at`（无交易返回 `null`）。
  Future<int?> lastTxnUpdatedAt(int bookId) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(updated_at) AS u FROM txn WHERE book_id = ?',
      [bookId],
    );
    if (rows.isEmpty) return null;
    final v = rows.first['u'];
    return v == null ? null : v as int;
  }

  /// 取聚合结果首行某列的整数值，缺失返回 0。
  int _firstInt(List<Map<String, Object?>> rows, String column) {
    if (rows.isEmpty) return 0;
    final v = rows.first[column];
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
