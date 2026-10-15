import '../../core/constants.dart';

/// 账本模型（`book` 表）。
///
/// Model 铁律：只做数据搬运，不格式化、不 import Flutter 颜色类；
/// 颜色以 `'#RRGGBB'` 字符串流转，由 `core/format.dart` 的 `hexToColor()` 转换。
class Book {
  /// 主键。
  final int id;

  /// 账本名称。
  final String name;

  /// 图标语义 key（见 `icons/app_icons.dart`）。
  final String iconKey;

  /// 图标色 `'#RRGGBB'`。
  final String iconColor;

  /// 排序序号（升序）。
  final int sortOrder;

  /// 是否默认账本（不可删除）。
  final bool isDefault;

  /// 创建时间（UTC epoch ms）。
  final int createdAt;

  /// 更新时间（UTC epoch ms，供「更新于」展示）。
  final int updatedAt;

  /// 是否已归档。
  final bool archived;

  const Book({
    required this.id,
    required this.name,
    this.iconKey = AppConstants.defaultBookIconKey,
    this.iconColor = AppConstants.defaultBookIconColor,
    this.sortOrder = 0,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
  });

  /// 反序列化：所有可空列都给默认值，防止历史数据缺列崩溃。
  factory Book.fromMap(Map<String, Object?> m) => Book(
        id: m['id'] as int,
        name: m['name'] as String? ?? '',
        iconKey: m['icon_key'] as String? ?? AppConstants.defaultBookIconKey,
        iconColor: m['icon_color'] as String? ?? AppConstants.defaultBookIconColor,
        sortOrder: m['sort_order'] as int? ?? 0,
        isDefault: (m['is_default'] as int? ?? 0) == 1,
        createdAt: m['created_at'] as int? ?? 0,
        updatedAt: m['updated_at'] as int? ?? 0,
        archived: (m['archived'] as int? ?? 0) == 1,
      );

  /// 序列化（含 `id`，供 insert/update 复用）。
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'icon_key': iconKey,
        'icon_color': iconColor,
        'sort_order': sortOrder,
        'is_default': isDefault ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'archived': archived ? 1 : 0,
      };

  /// 局部拷贝（`id` / `createdAt` 不可变）。
  Book copyWith({
    String? name,
    String? iconKey,
    String? iconColor,
    int? sortOrder,
    int? updatedAt,
    bool? archived,
  }) =>
      Book(
        id: id,
        name: name ?? this.name,
        iconKey: iconKey ?? this.iconKey,
        iconColor: iconColor ?? this.iconColor,
        sortOrder: sortOrder ?? this.sortOrder,
        isDefault: isDefault,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        archived: archived ?? this.archived,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Book && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Book(id: $id, name: $name, default: $isDefault)';
}
