import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../model/pref.dart';

/// `pref` 表 KV 读写。
class PrefDao {
  /// 注入连接（测试可传内存库）。
  const PrefDao(this._db);

  final Database _db;

  /// 使用全局单例连接构造。
  static Future<PrefDao> create() async => PrefDao(await AppDatabase.instance);

  static const String _table = 'pref';

  /// 读取单个 key。
  Future<String?> get(String key) async {
    final rows = await _db.query(_table, where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// 写入 / 更新单个 key（upsert）。
  Future<void> set(String key, String value, int updatedAt) async {
    await _db.insert(
      _table,
      {'key': key, 'value': value, 'updated_at': updatedAt},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 批量写入（一次事务，避免 N 次 IO）。
  Future<void> setAll(Map<String, String> entries, int updatedAt) async {
    final batch = _db.batch();
    for (final e in entries.entries) {
      batch.insert(
        _table,
        {'key': e.key, 'value': e.value, 'updated_at': updatedAt},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 删除单个 key。
  Future<int> remove(String key) async {
    return _db.delete(_table, where: 'key = ?', whereArgs: [key]);
  }

  /// 全部 KV。
  Future<Map<String, String>> all() async {
    final rows = await _db.query(_table);
    return {
      for (final r in rows) r['key'] as String: r['value'] as String? ?? '',
    };
  }

  /// 全部条目（含 `updated_at`）。
  Future<List<PrefEntry>> list() async {
    final rows = await _db.query(_table, orderBy: 'key ASC');
    return rows.map(PrefEntry.fromMap).toList();
  }

  /// 某 key 是否存在。
  Future<bool> has(String key) async {
    final rows = await _db.query(_table, columns: ['key'], where: 'key = ?', whereArgs: [key]);
    return rows.isNotEmpty;
  }
}
