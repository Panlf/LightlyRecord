import '../../core/constants.dart';
import 'tx_type.dart';

/// 分类模型（`category` 表）。
///
/// 图标用 `IconData(iconCodepoint, fontFamily: iconFontFamily)` 还原，
/// 即 Material Icons 的 `Icons.xxx.codePoint` 编译期常量。
class Category {
  /// 主键。
  final int id;

  /// 分类名称，如「餐饮」。
  final String name;

  /// 分类类型。
  final TxType type;

  /// 图标语义 key。
  final String iconKey;

  /// Material Icon codePoint。
  final int iconCodepoint;

  /// 图标字体族，恒为 `'MaterialIcons'`。
  final String iconFontFamily;

  /// 图标底色 `'#RRGGBB'`。
  final String colorBg;

  /// 图标描边色 `'#RRGGBB'`（同时作为环形图段色）。
  final String colorStroke;

  /// 排序序号。
  final int sortOrder;

  /// 是否系统预置（不可删除）。
  final bool isSystem;

  /// 是否启用（0 = 停用，不出现在宫格）。
  final bool enabled;

  /// 所属账本；`null` = 全局通用。
  final int? bookId;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.iconCodepoint,
    this.iconFontFamily = 'MaterialIcons',
    required this.colorBg,
    required this.colorStroke,
    this.sortOrder = 0,
    this.isSystem = true,
    this.enabled = true,
    this.bookId,
  });

  /// 反序列化：可空列全部给默认值。
  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int,
        name: m['name'] as String? ?? '',
        type: TxType.fromCode(m['type'] as int? ?? 1),
        iconKey: m['icon_key'] as String? ?? 'other_out',
        iconCodepoint: m['icon_codepoint'] as int? ?? 0,
        iconFontFamily: m['icon_font_family'] as String? ?? 'MaterialIcons',
        colorBg: m['color_bg'] as String? ?? AppConstants.defaultCategoryColorBg,
        colorStroke: m['color_stroke'] as String? ?? AppConstants.defaultCategoryColorStroke,
        sortOrder: m['sort_order'] as int? ?? 0,
        isSystem: (m['is_system'] as int? ?? 1) == 1,
        enabled: (m['enabled'] as int? ?? 1) == 1,
        bookId: m['book_id'] as int?,
      );

  /// 序列化（含 `id`）。
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type.code,
        'icon_key': iconKey,
        'icon_codepoint': iconCodepoint,
        'icon_font_family': iconFontFamily,
        'color_bg': colorBg,
        'color_stroke': colorStroke,
        'sort_order': sortOrder,
        'is_system': isSystem ? 1 : 0,
        'enabled': enabled ? 1 : 0,
        'book_id': bookId,
      };

  /// 局部拷贝（`id` 不可变）。
  Category copyWith({
    String? name,
    TxType? type,
    String? iconKey,
    int? iconCodepoint,
    String? colorBg,
    String? colorStroke,
    int? sortOrder,
    bool? enabled,
    int? bookId,
  }) =>
      Category(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        iconKey: iconKey ?? this.iconKey,
        iconCodepoint: iconCodepoint ?? this.iconCodepoint,
        iconFontFamily: iconFontFamily,
        colorBg: colorBg ?? this.colorBg,
        colorStroke: colorStroke ?? this.colorStroke,
        sortOrder: sortOrder ?? this.sortOrder,
        isSystem: isSystem,
        enabled: enabled ?? this.enabled,
        bookId: bookId ?? this.bookId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Category && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Category(id: $id, name: $name, type: ${type.code})';
}
