import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../model/category.dart';
import '../model/tx_type.dart';

/// `category` 表 CRUD + 按类型排序查询。
class CategoryDao {
  /// 注入连接（测试可传内存库）。
  const CategoryDao(this._db);

  final Database _db;

  /// 使用全局单例连接构造。
  static Future<CategoryDao> create() async =>
      CategoryDao(await AppDatabase.instance);

  static const String _table = 'category';

  /// 全部分类。
  Future<List<Category>> list() async {
    final rows = await _db.query(_table, orderBy: 'type ASC, sort_order ASC, id ASC');
    return rows.map(Category.fromMap).toList();
  }

  /// 按类型查询（含全局 + 指定账本的自定义分类，按 `sort_order` 升序）。
  Future<List<Category>> listByType(TxType type, {int? bookId}) async {
    final rows = bookId == null
        ? await _db.query(
            _table,
            where: 'type = ?',
            whereArgs: [type.code],
            orderBy: 'sort_order ASC, id ASC',
          )
        : await _db.query(
            _table,
            where: 'type = ? AND (book_id IS NULL OR book_id = ?)',
            whereArgs: [type.code, bookId],
            orderBy: 'sort_order ASC, id ASC',
          );
    return rows.map(Category.fromMap).toList();
  }

  /// 宫格用：按类型查询且仅返回启用态。
  Future<List<Category>> listEnabledByType(TxType type, {int? bookId}) async {
    final rows = bookId == null
        ? await _db.query(
            _table,
            where: 'type = ? AND enabled = 1',
            whereArgs: [type.code],
            orderBy: 'sort_order ASC, id ASC',
          )
        : await _db.query(
            _table,
            where: 'type = ? AND enabled = 1 AND (book_id IS NULL OR book_id = ?)',
            whereArgs: [type.code, bookId],
            orderBy: 'sort_order ASC, id ASC',
          );
    return rows.map(Category.fromMap).toList();
  }

  /// 按 id 查询。
  Future<Category?> findById(int id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  /// 按语义 key 查询（返回第一个匹配，通常用于示例数据反查）。
  Future<Category?> findByKey(String iconKey) async {
    final rows = await _db.query(_table, where: 'icon_key = ?', whereArgs: [iconKey]);
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  /// 插入并返回自增 id。
  ///
  /// `toMap()` 里的 `id` 必须剔除：显式传 `id = 0` 会让 SQLite 把 rowid 钉成 0，
  /// 从而破坏 AUTOINCREMENT。
  Future<int> insert(Category category) async {
    return _db.insert(_table, category.toMap()..remove('id'));
  }

  /// 更新（整行）。
  Future<int> update(Category category) async {
    return _db.update(_table, category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  /// 删除。
  Future<int> delete(int id) async {
    return _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// 批量重排：按 [orderedIds] 顺序把 `sort_order` 写成 0..n-1。
  Future<void> reorder(List<int> orderedIds) async {
    final batch = _db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        _table,
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 该类型下一个排序序号。
  Future<int> nextSortOrder(TxType type) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS n FROM $_table WHERE type = ?',
      [type.code],
    );
    return _firstInt(rows, 'n');
  }

  /// 分类总数。
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return _firstInt(rows, 'c');
  }

  /// 该分类下是否仍有交易（删除保护提示用）。
  Future<int> txnCount(int categoryId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM txn WHERE category_id = ?',
      [categoryId],
    );
    return _firstInt(rows, 'c');
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
