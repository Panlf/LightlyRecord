import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';
import '../../core/logger.dart';
import '../ddl.dart';
import 'migrations.dart';
import 'seed_data.dart';

/// 建库 / 开库 / 关闭 + `onCreate` / `onUpgrade` / `onDowngrade` 调度。
///
/// 单例：整个 App 生命周期只开一次连接，由 `AppLocator.init()` 触发。
class AppDatabase {
  const AppDatabase._();

  static Database? _db;

  /// 当前数据库连接（未打开时自动打开）。
  static Future<Database> get instance async => _db ??= await open();

  /// 当前连接（可能为 `null`，仅用于同步场景判空）。
  static Database? get dbOrNull => _db;

  /// 打开（或创建）数据库。
  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, AppConstants.dbName);
    Log.d('AppDatabase.open -> $path (v${AppConstants.dbVersion})');

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onConfigure: (db) async {
        // 每个连接都必须显式开启外键约束，否则 ON DELETE CASCADE 不生效。
        await db.execute(Ddl.pragmaForeignKeys);
      },
      onCreate: (db, version) async {
        Log.d('AppDatabase.onCreate v$version');
        final batch = db.batch();
        for (final sql in Ddl.all) {
          batch.execute(sql);
        }
        await batch.commit(noResult: true);
        await SeedData.run(db);
      },
      onUpgrade: (db, from, to) async {
        Log.d('AppDatabase.onUpgrade $from -> $to');
        await Migrations.run(db, from, to);
      },
      // 降级 = 打开一个比本机代码更旧的库（只可能来自侧载旧包覆盖安装）。
      // 原实现 onDatabaseDowngradeDelete 会**删光用户数据重建**，对记账
      // 应用是灾难；改为显式报错，让调用方（启动链）记录日志后降级启动。
      onDowngrade: (db, from, to) async {
        throw StateError(
          '数据库版本 v$from 高于本应用支持的 v$to，拒绝降级打开（不删除用户数据）',
        );
      },
    );
  }

  /// 关闭连接（仅测试 / 注销场景使用）。
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
