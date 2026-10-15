import 'tx_type.dart';

/// 交易模型（`txn` 表，核心事实表）。
///
/// - `amountMinor` 一律 `int`，单位「分」，永不为负（DB 有 `CHECK(amount_minor > 0)`）；
/// - `txDate` = `'YYYY-MM-DD'` 本地日期；`txTime` = `'HH:mm'`；
/// - `createdAt` / `updatedAt` = UTC epoch ms；
/// - `category*` 系列字段是 Repository join 后填充的运行时关联，**非 DB 列**。
class Txn {
  /// 主键。
  final int id;

  /// 所属账本。
  final int bookId;

  /// 所属分类。
  final int categoryId;

  /// 类型（冗余列，避免聚合时 join）。
  final TxType type;

  /// 金额，单位「分」。
  final int amountMinor;

  /// 备注（可为空串）。
  final String note;

  /// 本地日期 `'YYYY-MM-DD'`。
  final String txDate;

  /// 本地时间 `'HH:mm'`。
  final String txTime;

  /// 创建时间（UTC epoch ms）。
  final int createdAt;

  /// 更新时间（UTC epoch ms）。
  final int updatedAt;

  /// 运行时：分类名。
  final String? categoryName;

  /// 运行时：分类图标底色 `'#RRGGBB'`。
  final String? categoryColorBg;

  /// 运行时：分类图标描边色 `'#RRGGBB'`。
  final String? categoryColorStroke;

  /// 运行时：分类图标 codePoint。
  final int? categoryIconCodepoint;

  const Txn({
    required this.id,
    required this.bookId,
    required this.categoryId,
    required this.type,
    required this.amountMinor,
    this.note = '',
    required this.txDate,
    this.txTime = '00:00',
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryColorBg,
    this.categoryColorStroke,
    this.categoryIconCodepoint,
  });

  /// 纯 DB 列反序列化（不含 join 字段）。
  ///
  /// `id` 可缺省（`toMap()` 不产出 `id`），缺省时取 0。
  factory Txn.fromMap(Map<String, Object?> m) => Txn(
        id: m['id'] as int? ?? 0,
        bookId: m['book_id'] as int? ?? 0,
        categoryId: m['category_id'] as int? ?? 0,
        type: TxType.fromCode(m['type'] as int? ?? 1),
        amountMinor: m['amount_minor'] as int? ?? 0,
        note: m['note'] as String? ?? '',
        txDate: m['tx_date'] as String? ?? '',
        txTime: m['tx_time'] as String? ?? '00:00',
        createdAt: m['created_at'] as int? ?? 0,
        updatedAt: m['updated_at'] as int? ?? 0,
      );

  /// 带分类 join 的反序列化（Repository 查询统一走这里）。
  ///
  /// `id` 可缺省（`toMap()` 不产出 `id`），缺省时取 0。
  factory Txn.fromMapJoined(Map<String, Object?> m) => Txn(
        id: m['id'] as int? ?? 0,
        bookId: m['book_id'] as int? ?? 0,
        categoryId: m['category_id'] as int? ?? 0,
        type: TxType.fromCode(m['type'] as int? ?? 1),
        amountMinor: m['amount_minor'] as int? ?? 0,
        note: m['note'] as String? ?? '',
        txDate: m['tx_date'] as String? ?? '',
        txTime: m['tx_time'] as String? ?? '00:00',
        createdAt: m['created_at'] as int? ?? 0,
        updatedAt: m['updated_at'] as int? ?? 0,
        categoryName: m['category_name'] as String?,
        categoryColorBg: m['category_color_bg'] as String?,
        categoryColorStroke: m['category_color_stroke'] as String?,
        categoryIconCodepoint: m['category_icon_codepoint'] as int?,
      );

  /// 序列化（**不含**运行时关联字段，也不含 `id` 由调用方决定）。
  Map<String, Object?> toMap() => {
        'book_id': bookId,
        'category_id': categoryId,
        'type': type.code,
        'amount_minor': amountMinor,
        'note': note,
        'tx_date': txDate,
        'tx_time': txTime,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// 局部拷贝（`id` / `createdAt` 不可变；join 字段随 `categoryId` 变化需显式传入）。
  Txn copyWith({
    int? bookId,
    int? categoryId,
    TxType? type,
    int? amountMinor,
    String? note,
    String? txDate,
    String? txTime,
    int? updatedAt,
    String? categoryName,
    String? categoryColorBg,
    String? categoryColorStroke,
    int? categoryIconCodepoint,
  }) =>
      Txn(
        id: id,
        bookId: bookId ?? this.bookId,
        categoryId: categoryId ?? this.categoryId,
        type: type ?? this.type,
        amountMinor: amountMinor ?? this.amountMinor,
        note: note ?? this.note,
        txDate: txDate ?? this.txDate,
        txTime: txTime ?? this.txTime,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        categoryName: categoryName ?? this.categoryName,
        categoryColorBg: categoryColorBg ?? this.categoryColorBg,
        categoryColorStroke: categoryColorStroke ?? this.categoryColorStroke,
        categoryIconCodepoint:
            categoryIconCodepoint ?? this.categoryIconCodepoint,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Txn && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Txn(id: $id, $amountMinor 分, $type, $txDate $txTime, ${categoryName ?? categoryId})';
}
