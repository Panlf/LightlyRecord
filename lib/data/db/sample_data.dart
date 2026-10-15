import 'package:sqflite/sqflite.dart';

import '../../core/date_ext.dart';
import '../../core/format.dart';
import '../model/tx_type.dart';

/// 一条示例数据规格（金额以「元」字符串表达，落库前统一转「分」）。
class _SampleRow {
  final int dayOffset;
  final String time;
  final String categoryKey;
  final String note;
  final String yuan;
  final TxType type;

  const _SampleRow({
    required this.dayOffset,
    required this.time,
    required this.categoryKey,
    required this.note,
    required this.yuan,
    required this.type,
  });
}

/// 示例数据（原型 `dayTx` 移植，日期相对今天 `T` 生成）。
///
/// **严禁硬编码具体日期**：一律 `DateTime(now.year, now.month, now.day - offset)`。
class SampleData {
  const SampleData._();

  /// 22 条示例数据（顺序即插入顺序）。
  static const List<_SampleRow> _rows = [
    _SampleRow(
      dayOffset: 0,
      time: '08:12',
      categoryKey: 'food',
      note: '豆浆油条',
      yuan: '26.50',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 0,
      time: '08:40',
      categoryKey: 'transport',
      note: '交通通勤',
      yuan: '4.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 0,
      time: '14:05',
      categoryKey: 'food',
      note: '瑞幸生椰拿铁',
      yuan: '32.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 0,
      time: '19:40',
      categoryKey: 'food',
      note: '火锅聚餐',
      yuan: '128.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 1,
      time: '10:00',
      categoryKey: 'reimburse',
      note: '差旅报销到账',
      yuan: '680.00',
      type: TxType.income,
    ),
    _SampleRow(
      dayOffset: 1,
      time: '17:22',
      categoryKey: 'shopping',
      note: '周末采购',
      yuan: '156.80',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 1,
      time: '21:05',
      categoryKey: 'transport',
      note: '回家',
      yuan: '28.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 1,
      time: '12:10',
      categoryKey: 'food',
      note: '公司食堂',
      yuan: '35.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 2,
      time: '09:00',
      categoryKey: 'redpacket',
      note: '爸妈给的爱心红包',
      yuan: '200.00',
      type: TxType.income,
    ),
    _SampleRow(
      dayOffset: 2,
      time: '19:30',
      categoryKey: 'fun',
      note: '《浪浪山》IMAX',
      yuan: '88.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 2,
      time: '15:12',
      categoryKey: 'food',
      note: '喜多芋圆葡萄',
      yuan: '22.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 3,
      time: '18:40',
      categoryKey: 'food',
      note: '麻辣香锅',
      yuan: '42.50',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 4,
      time: '09:00',
      categoryKey: 'salary',
      note: '10月工资到账',
      yuan: '12000.00',
      type: TxType.income,
    ),
    _SampleRow(
      dayOffset: 4,
      time: '19:00',
      categoryKey: 'food',
      note: '大学室友小聚',
      yuan: '268.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 5,
      time: '08:15',
      categoryKey: 'shopping',
      note: '早餐三明治',
      yuan: '18.50',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 5,
      time: '08:40',
      categoryKey: 'transport',
      note: '交通通勤',
      yuan: '4.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 6,
      time: '10:30',
      categoryKey: 'parttime',
      note: '周末兼职结算',
      yuan: '1850.00',
      type: TxType.income,
    ),
    _SampleRow(
      dayOffset: 6,
      time: '10:30',
      categoryKey: 'home',
      note: '9月物业水电',
      yuan: '320.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 8,
      time: '20:00',
      categoryKey: 'study',
      note: '《Flutter 实战》',
      yuan: '89.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 14,
      time: '16:40',
      categoryKey: 'shopping',
      note: '节前囤货',
      yuan: '98.20',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 14,
      time: '09:20',
      categoryKey: 'transport',
      note: '中秋回家加油',
      yuan: '300.00',
      type: TxType.expense,
    ),
    _SampleRow(
      dayOffset: 16,
      time: '15:00',
      categoryKey: 'parttime',
      note: '上月外包尾款',
      yuan: '6000.00',
      type: TxType.income,
    ),
  ];

  /// 示例数据条数。
  static int get count => _rows.length;

  /// 把示例数据写入 [bookId] 账本，返回插入条数。
  ///
  /// - 分类通过 `icon_key` 反查 id；找不到时退化为该类型的「其他」分类；
  /// - 金额用 `parseYuanToMinor`（字符串切分）转分；
  /// - 日期 = `DateTime(now.year, now.month, now.day - offset)`。
  static Future<int> load(DatabaseExecutor db, int bookId) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    // icon_key + type → id
    final catRows = await db.query('category', columns: ['id', 'icon_key', 'type']);
    final byKey = <String, int>{};
    final fallback = <TxType, int>{};
    for (final r in catRows) {
      final key = r['icon_key'] as String? ?? '';
      final type = TxType.fromCode(r['type'] as int? ?? 1);
      final id = r['id'] as int;
      if (key.isNotEmpty) {
        byKey.putIfAbsent(key, () => id);
      }
      if (key.startsWith('other_')) {
        fallback[type] = id;
      }
    }

    final batch = db.batch();
    var inserted = 0;

    for (final row in _rows) {
      final categoryId = byKey[row.categoryKey] ?? fallback[row.type] ?? 0;
      if (categoryId == 0) {
        continue;
      }
      final date = addDays(DateTime(now.year, now.month, now.day), -row.dayOffset);
      batch.insert('txn', {
        'book_id': bookId,
        'category_id': categoryId,
        'type': row.type.code,
        'amount_minor': parseYuanToMinor(row.yuan),
        'note': row.note,
        'tx_date': ymd(date),
        'tx_time': row.time,
        'created_at': nowMs,
        'updated_at': nowMs,
      });
      inserted++;
    }

    await batch.commit(noResult: true);
    return inserted;
  }

  /// 清空全部交易（保留账本与分类），返回删除条数。
  static Future<int> clearAll(DatabaseExecutor db) async {
    return db.delete('txn');
  }
}
