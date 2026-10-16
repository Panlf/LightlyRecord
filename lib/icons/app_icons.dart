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
    'ramen': Icons.ramen_dining,
    'cafe': Icons.local_cafe,
    'snack': Icons.cookie,
    'grocery': Icons.shopping_cart,
    'transport': Icons.directions_bus,
    'taxi': Icons.local_taxi,
    'subway': Icons.subway,
    'train': Icons.train,
    'flight': Icons.flight,
    'fuel': Icons.local_gas_station,
    'parking': Icons.local_parking,
    'shopping': Icons.shopping_bag,
    'market': Icons.local_mall,
    'store': Icons.storefront,
    'home': Icons.home,
    'rent': Icons.home_work,
    'kitchen': Icons.kitchen,
    'furniture': Icons.chair,
    'cleaning': Icons.cleaning_services,
    'utilities': Icons.bolt,
    'phone': Icons.smartphone,
    'internet': Icons.wifi,
    'medical': Icons.local_hospital,
    'medicine': Icons.medication,
    'study': Icons.menu_book,
    'school': Icons.school,
    'office': Icons.business_center,
    'device': Icons.laptop_mac,
    'fun': Icons.music_note,
    'movie': Icons.movie,
    'game': Icons.sports_esports,
    'fitness': Icons.fitness_center,
    'travel': Icons.flight_takeoff,
    'beauty': Icons.spa,
    'clothing': Icons.checkroom,
    'laundry': Icons.local_laundry_service,
    'pet': Icons.pets,
    'social': Icons.redeem,
    'baby': Icons.child_care,
    'other_out': Icons.more_horiz,
    // ---- 收入 ----
    'salary': Icons.account_balance_wallet,
    'bonus': Icons.emoji_events,
    'parttime': Icons.work,
    'freelance': Icons.handyman,
    'invest': Icons.trending_up,
    'deposit': Icons.savings,
    'bank': Icons.account_balance,
    'interest': Icons.attach_money,
    'payment': Icons.payments,
    'sales': Icons.point_of_sale,
    'subsidy': Icons.volunteer_activism,
    'redpacket': Icons.card_giftcard,
    'reimburse': Icons.receipt_long,
    'refund': Icons.undo,
    'lottery': Icons.celebration,
    'award': Icons.military_tech,
    'other_in': Icons.more_horiz,
    // ---- 转账（P2 预留） ----
    'transfer': Icons.swap_horiz,
    'credit_repay': Icons.credit_card,
    // ---- 账本 ----
    // 注意：'travel' / 'school' / 'pet' 与支出候选集同 key 且同图标，
    // 已统一收在支出段，这里不再重复登记（const map 不允许重复 key）。
    'book': Icons.menu_book,
    'decor': Icons.home_repair_service,
    'shop': Icons.shopping_cart,
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

  /// 支出分类图标候选集（新收支类型为「支出」的分类时用）。
  static const List<AppIconOption> expenseOptions = [
    AppIconOption('food', '餐饮', Icons.restaurant),
    AppIconOption('ramen', '面食', Icons.ramen_dining),
    AppIconOption('cafe', '咖啡', Icons.local_cafe),
    AppIconOption('snack', '零食', Icons.cookie),
    AppIconOption('grocery', '买菜', Icons.shopping_cart),
    AppIconOption('transport', '交通', Icons.directions_bus),
    AppIconOption('taxi', '打车', Icons.local_taxi),
    AppIconOption('subway', '地铁', Icons.subway),
    AppIconOption('train', '火车', Icons.train),
    AppIconOption('flight', '机票', Icons.flight),
    AppIconOption('fuel', '加油', Icons.local_gas_station),
    AppIconOption('parking', '停车', Icons.local_parking),
    AppIconOption('shopping', '购物', Icons.shopping_bag),
    AppIconOption('market', '超市', Icons.local_mall),
    AppIconOption('store', '门店', Icons.storefront),
    AppIconOption('home', '居家', Icons.home),
    AppIconOption('rent', '房租房贷', Icons.home_work),
    AppIconOption('kitchen', '厨具', Icons.kitchen),
    AppIconOption('furniture', '家居', Icons.chair),
    AppIconOption('cleaning', '家政', Icons.cleaning_services),
    AppIconOption('utilities', '水电', Icons.bolt),
    AppIconOption('phone', '话费', Icons.smartphone),
    AppIconOption('internet', '网络', Icons.wifi),
    AppIconOption('medical', '医疗', Icons.local_hospital),
    AppIconOption('medicine', '药品', Icons.medication),
    AppIconOption('study', '学习', Icons.menu_book),
    AppIconOption('school', '教育', Icons.school),
    AppIconOption('office', '办公', Icons.business_center),
    AppIconOption('device', '数码', Icons.laptop_mac),
    AppIconOption('fun', '娱乐', Icons.music_note),
    AppIconOption('movie', '影视', Icons.movie),
    AppIconOption('game', '游戏', Icons.sports_esports),
    AppIconOption('fitness', '运动', Icons.fitness_center),
    AppIconOption('travel', '旅行', Icons.flight_takeoff),
    AppIconOption('beauty', '美容', Icons.spa),
    AppIconOption('clothing', '服饰', Icons.checkroom),
    AppIconOption('laundry', '洗护', Icons.local_laundry_service),
    AppIconOption('pet', '宠物', Icons.pets),
    AppIconOption('social', '人情', Icons.redeem),
    AppIconOption('baby', '育儿', Icons.child_care),
    AppIconOption('credit_repay', '信用卡', Icons.credit_card),
    AppIconOption('other_out', '其他', Icons.more_horiz),
  ];

  /// 收入分类图标候选集。
  static const List<AppIconOption> incomeOptions = [
    AppIconOption('salary', '工资', Icons.account_balance_wallet),
    AppIconOption('bonus', '奖金', Icons.emoji_events),
    AppIconOption('parttime', '兼职', Icons.work),
    AppIconOption('freelance', '外快', Icons.handyman),
    AppIconOption('invest', '理财', Icons.trending_up),
    AppIconOption('deposit', '存款', Icons.savings),
    AppIconOption('bank', '银行结息', Icons.account_balance),
    AppIconOption('interest', '利息', Icons.attach_money),
    AppIconOption('payment', '收款', Icons.payments),
    AppIconOption('sales', '销售', Icons.point_of_sale),
    AppIconOption('subsidy', '补贴', Icons.volunteer_activism),
    AppIconOption('redpacket', '红包', Icons.card_giftcard),
    AppIconOption('reimburse', '报销', Icons.receipt_long),
    AppIconOption('refund', '退款', Icons.undo),
    AppIconOption('lottery', '中奖', Icons.celebration),
    AppIconOption('award', '荣誉金', Icons.military_tech),
    AppIconOption('transfer', '互转', Icons.swap_horiz),
    AppIconOption('other_in', '其他', Icons.more_horiz),
  ];

  /// 分类图标候选集（支出 + 收入，转账态共用）。
  static const List<AppIconOption> categoryOptions = [
    ...expenseOptions,
    ...incomeOptions,
  ];

  /// 按收支类型取对应的候选集：新建 / 编辑都只给本类型会用到的图标，
  /// 避免支出分类里冒出「工资」、收入分类里冒出「加油」这类错位选项。
  static List<AppIconOption> optionsFor(bool isIncome) =>
      isIncome ? incomeOptions : expenseOptions;

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
