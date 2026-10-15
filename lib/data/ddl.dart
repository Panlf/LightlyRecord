/// 全量表结构 DDL 常量（供 `migrations.dart` / `app_database.dart` 引用）。
///
/// **纪律**：已发布的语句**禁止修改**；任何表结构变更必须新增一条迁移脚本，
/// 并把 [dbVersion] +1（见 `data/db/migrations.dart`）。
library;

/// 建表 DDL 集合。顺序无关（无跨表外键依赖），但保持一致便于阅读。
class Ddl {
  const Ddl._();

  /// 开启外键约束（每个连接都必须执行，`onConfigure` 里调用）。
  static const String pragmaForeignKeys = 'PRAGMA foreign_keys = ON';

  /// `book` 账本表。
  static const String createBook = '''
CREATE TABLE IF NOT EXISTS book (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,
  icon_key    TEXT    NOT NULL DEFAULT 'book',
  icon_color  TEXT    NOT NULL DEFAULT '#3E9F7C',
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_default  INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  archived    INTEGER NOT NULL DEFAULT 0
)
''';

  /// `category` 分类表。
  static const String createCategory = '''
CREATE TABLE IF NOT EXISTS category (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT    NOT NULL,
  type            INTEGER NOT NULL,
  icon_key        TEXT    NOT NULL,
  icon_codepoint  INTEGER NOT NULL,
  icon_font_family TEXT   NOT NULL DEFAULT 'MaterialIcons',
  color_bg        TEXT    NOT NULL,
  color_stroke    TEXT    NOT NULL,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  is_system       INTEGER NOT NULL DEFAULT 1,
  enabled         INTEGER NOT NULL DEFAULT 1,
  book_id         INTEGER NULL REFERENCES book(id) ON DELETE CASCADE
)
''';

  /// 分类索引：按类型 + 启用态 + 排序查询。
  static const String createIndexCategoryType =
      'CREATE INDEX IF NOT EXISTS idx_category_type ON category(type, enabled, sort_order)';

  /// `txn` 交易表（核心事实表）。
  ///
  /// 表名用 `txn` 而非 `transaction`（后者是 SQL 关键字）。
  static const String createTxn = '''
CREATE TABLE IF NOT EXISTS txn (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id       INTEGER NOT NULL REFERENCES book(id)      ON DELETE CASCADE,
  category_id   INTEGER NOT NULL REFERENCES category(id)  ON DELETE RESTRICT,
  type          INTEGER NOT NULL,
  amount_minor  INTEGER NOT NULL CHECK (amount_minor > 0),
  note          TEXT    NOT NULL DEFAULT '',
  tx_date       TEXT    NOT NULL,
  tx_time       TEXT    NOT NULL DEFAULT '00:00',
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
)
''';

  /// 交易索引：账本 + 日期（今日/日历/区间查询主力）。
  static const String createIndexTxnBookDate =
      'CREATE INDEX IF NOT EXISTS idx_txn_book_date ON txn(book_id, tx_date)';

  /// 交易索引：账本 + 日期 + 类型（区间收支聚合）。
  static const String createIndexTxnBookDateType =
      'CREATE INDEX IF NOT EXISTS idx_txn_book_date_type ON txn(book_id, tx_date, type)';

  /// 交易索引：日期（全局口径查询）。
  static const String createIndexTxnDate =
      'CREATE INDEX IF NOT EXISTS idx_txn_date ON txn(tx_date)';

  /// 交易索引：分类（按分类聚合 / 防删已引用分类）。
  static const String createIndexTxnCategory =
      'CREATE INDEX IF NOT EXISTS idx_txn_category ON txn(category_id)';

  /// `budget` 预算表（全局单份，CHECK 强制 `id = 1`）。
  static const String createBudget = '''
CREATE TABLE IF NOT EXISTS budget (
  id                   INTEGER PRIMARY KEY CHECK (id = 1),
  monthly_amount_minor INTEGER NOT NULL DEFAULT 0,
  enabled              INTEGER NOT NULL DEFAULT 0,
  updated_at           INTEGER NOT NULL
)
''';

  /// `pref` 偏好 KV 表。
  static const String createPref = '''
CREATE TABLE IF NOT EXISTS pref (
  key        TEXT PRIMARY KEY,
  value      TEXT    NOT NULL,
  updated_at INTEGER NOT NULL
)
''';

  /// 全量建表语句列表（`onCreate` 批量执行）。
  static const List<String> all = [
    createBook,
    createCategory,
    createIndexCategoryType,
    createTxn,
    createIndexTxnBookDate,
    createIndexTxnBookDateType,
    createIndexTxnDate,
    createIndexTxnCategory,
    createBudget,
    createPref,
  ];
}
