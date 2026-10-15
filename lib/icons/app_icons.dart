import 'package:flutter/material.dart';

import '../core/constants.dart';

/// 一个图标候选项（语义 key + 展示名 + IconData）。
class AppIconOption {
  /// 语义 key（与 DB `category.icon_key` / `book.icon_key` 对应）。
  final String key;

  /// 中文展示名（选择器里显示）。
  final String label;

  /// Material Icon 常量。
  final IconData icon;

  const AppIconOption(this.key, this.label, this.icon);
}

/// 一个配色候选项。
class AppColorOption {
  /// 色值 `'#RRGGBB'`。
  final String hex;

  /// 中文展示名。
  final String label;

  const AppColorOption(this.hex, this.label);
}

/// 语义 key → Material `IconData` 注册表 + 图标选择器候选集。
///
/// 与 `icons/app_icons.dart`、`data/db/seed_data.dart` 是全 App 仅有的两处
/// 允许出现色值字面量的位置（分类 / 账本配色属于**数据色**，非主题 Token）。
class AppIcons {
  const AppIcons._();

  /// 图标字体族（Material Icons）。
  static const String fontFamily = 'MaterialIcons';

  /// 未知 key 的兜底图标。
  static const IconData fallback = Icons.help_outline;

  /// 语义 key → IconData。
  static const Map<String, IconData> registry = {
    // ---- 支出 ----
    'food': Icons.restaurant,
    'transport': Icons.directions_bus,
    'shopping': Icons.shopping_bag,
    'home': Icons.home,
    'fun': Icons.music_note,
    'medical': Icons.local_hospital,
    'study': Icons.menu_book,
    'social': Icons.redeem,
    'other_out': Icons.more_horiz,
    // ---- 收入 ----
    'salary': Icons.account_balance_wallet,
    'parttime': Icons.work,
    'invest': Icons.trending_up,
    'redpacket': Icons.card_giftcard,
    'reimburse': Icons.receipt_long,
    'other_in': Icons.more_horiz,
    // ---- 转账（P2 预留） ----
    'transfer': Icons.swap_horiz,
    'credit_repay': Icons.credit_card,
    // ---- 账本 ----
    'book': Icons.menu_book,
    'travel': Icons.flight_takeoff,
    'decor': Icons.home_repair_service,
    'shop': Icons.shopping_cart,
    'school': Icons.school,
    'pet': Icons.pets,
    'fastfood': Icons.fastfood,
    'love': Icons.favorite,
    // ---- 通用 / 界面 ----
    'add': Icons.add,
    'close': Icons.close,
    'back': Icons.arrow_back_ios,
    'delete': Icons.delete_outline,
    'edit': Icons.edit_outlined,
    'calendar': Icons.calendar_today_outlined,
    'note': Icons.edit_note,
    'chart': Icons.pie_chart_outline,
    'list': Icons.format_list_bulleted,
    'person': Icons.person_outline,
    'settings': Icons.settings_outlined,
    'download': Icons.file_download_outlined,
    'bell': Icons.notifications_none_outlined,
    'palette': Icons.palette_outlined,
    'info': Icons.info_outline,
    'wallet': Icons.account_balance_wallet_outlined,
    'empty': Icons.receipt_long_outlined,
  };

  /// 语义 key → IconData；未知 key 回落 [fallback]。
  static IconData of(String? key) => registry[key] ?? fallback;

  /// DB 里的 `(iconCodepoint, iconFontFamily)` → IconData。
  ///
  /// `iconFontFamily` 非 `'MaterialIcons'` 时回落 [fallback]，
  /// 防止自定义字体被当成图标渲染。
  static IconData fromCodepoint(int codepoint, [String? fontFamily]) {
    if (codepoint <= 0) return fallback;
    if (fontFamily != null && fontFamily != 'MaterialIcons') return fallback;
    return IconData(codepoint, fontFamily: fontFamily ?? 'MaterialIcons');
  }

  /// 账本图标候选集（对齐架构文档 §6.4）。
  static const List<AppIconOption> bookOptions = [
    AppIconOption('book', '账本', Icons.menu_book),
    AppIconOption('travel', '旅行', Icons.flight_takeoff),
    AppIconOption('decor', '家居', Icons.home_repair_service),
    AppIconOption('shop', '购物', Icons.shopping_cart),
    AppIconOption('school', '学习', Icons.school),
    AppIconOption('pet', '宠物', Icons.pets),
    AppIconOption('fastfood', '餐饮', Icons.fastfood),
    AppIconOption('love', '爱心', Icons.favorite),
  ];

  /// 分类图标候选集（支出 / 收入 / 转账三态共用一套候选）。
  static const List<AppIconOption> categoryOptions = [
    AppIconOption('food', '餐饮', Icons.restaurant),
    AppIconOption('transport', '交通', Icons.directions_bus),
    AppIconOption('shopping', '购物', Icons.shopping_bag),
    AppIconOption('home', '居家', Icons.home),
    AppIconOption('fun', '娱乐', Icons.music_note),
    AppIconOption('medical', '医疗', Icons.local_hospital),
    AppIconOption('study', '学习', Icons.menu_book),
    AppIconOption('social', '人情', Icons.redeem),
    AppIconOption('salary', '工资', Icons.account_balance_wallet),
    AppIconOption('parttime', '兼职', Icons.work),
    AppIconOption('invest', '理财', Icons.trending_up),
    AppIconOption('redpacket', '红包', Icons.card_giftcard),
    AppIconOption('reimburse', '报销', Icons.receipt_long),
    AppIconOption('transfer', '互转', Icons.swap_horiz),
    AppIconOption('credit_repay', '信用卡', Icons.credit_card),
    AppIconOption('other_out', '其他', Icons.more_horiz),
  ];

  /// 默认账本图标色（与 seed_data 播种值一致）。
  static const String defaultBookColor = AppConstants.defaultBookIconColor;

  /// 账本图标色板（对齐架构文档 §6.4）。
  static const List<AppColorOption> colorPalette = [
    AppColorOption('#3E9F7C', '墨绿'),
    AppColorOption('#5B8DB8', '雾蓝'),
    AppColorOption('#8B6FC7', '薰衣紫'),
    AppColorOption('#C99A3F', '暖沙'),
    AppColorOption('#D16B8C', '樱花粉'),
    AppColorOption('#E08A6B', '陶土'),
    AppColorOption('#7BA85C', '青草'),
    AppColorOption('#6B85D9', '矢车菊'),
  ];
}
