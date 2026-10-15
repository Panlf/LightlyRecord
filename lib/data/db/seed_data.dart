/// 首次启动播种：默认账本 + 17 个系统分类 + 6 行 pref + 1 行 budget(enabled=0)。
///
/// 本文件与 `icons/app_icons.dart` 是全 App 仅有的两处允许出现色值字面量的位置
/// （分类/账本配色属于**数据色**，非主题 Token）。
library;

import 'package:flutter/material.dart' show Icons;
import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';
import '../model/tx_type.dart';

/// 一条分类播种规格。
class CategorySeed {
  final String name;
  final TxType type;
  final String iconKey;
  final int iconCodepoint;
  final String colorBg;
  final String colorStroke;

  const CategorySeed({
    required this.name,
    required this.type,
    required this.iconKey,
    required this.iconCodepoint,
    required this.colorBg,
    required this.colorStroke,
  });
}

/// 播种数据。全部日期相对运行时生成，无任何硬编码日期。
class SeedData {
  const SeedData._();

  /// 支出分类（9 个，`type = 1`）。
  static final List<CategorySeed> _expenseCategories = [
    CategorySeed(
      name: '餐饮',
      type: TxType.expense,
      iconKey: 'food',
      iconCodepoint: Icons.restaurant.codePoint,
      colorBg: '#E4F5EE',
      colorStroke: '#3E9F7C',
    ),
    CategorySeed(
      name: '交通',
      type: TxType.expense,
      iconKey: 'transport',
      iconCodepoint: Icons.directions_bus.codePoint,
      colorBg: '#E6F1FA',
      colorStroke: '#5B8DB8',
    ),
    CategorySeed(
      name: '购物',
      type: TxType.expense,
      iconKey: 'shopping',
      iconCodepoint: Icons.shopping_bag.codePoint,
      colorBg: '#EFEBFA',
      colorStroke: '#8B6FC7',
    ),
    CategorySeed(
      name: '居家',
      type: TxType.expense,
      iconKey: 'home',
      iconCodepoint: Icons.home.codePoint,
      colorBg: '#FBF3E0',
      colorStroke: '#C99A3F',
    ),
    CategorySeed(
      name: '娱乐',
      type: TxType.expense,
      iconKey: 'fun',
      iconCodepoint: Icons.music_note.codePoint,
      colorBg: '#FAE9EF',
      colorStroke: '#D16B8C',
    ),
    CategorySeed(
      name: '医疗',
      type: TxType.expense,
      iconKey: 'medical',
      iconCodepoint: Icons.local_hospital.codePoint,
      colorBg: '#FCEAE5',
      colorStroke: '#E08A6B',
    ),
    CategorySeed(
      name: '学习',
      type: TxType.expense,
      iconKey: 'study',
      iconCodepoint: Icons.menu_book.codePoint,
      colorBg: '#EAF4E2',
      colorStroke: '#7BA85C',
    ),
    CategorySeed(
      name: '人情',
      type: TxType.expense,
      iconKey: 'social',
      iconCodepoint: Icons.redeem.codePoint,
      colorBg: '#E9EEFB',
      colorStroke: '#6B85D9',
    ),
    CategorySeed(
      name: '其他',
      type: TxType.expense,
      iconKey: 'other_out',
      iconCodepoint: Icons.more_horiz.codePoint,
      colorBg: '#EEF2F0',
      colorStroke: '#9DB3A9',
    ),
  ];

  /// 收入分类（6 个，`type = 2`）。
  static final List<CategorySeed> _incomeCategories = [
    CategorySeed(
      name: '工资',
      type: TxType.income,
      iconKey: 'salary',
      iconCodepoint: Icons.account_balance_wallet.codePoint,
      colorBg: '#E4F5EE',
      colorStroke: '#3E9F7C',
    ),
    CategorySeed(
      name: '兼职',
      type: TxType.income,
      iconKey: 'parttime',
      iconCodepoint: Icons.work.codePoint,
      colorBg: '#E6F1FA',
      colorStroke: '#5B8DB8',
    ),
    CategorySeed(
      name: '理财',
      type: TxType.income,
      iconKey: 'invest',
      iconCodepoint: Icons.trending_up.codePoint,
      colorBg: '#EFEBFA',
      colorStroke: '#8B6FC7',
    ),
    CategorySeed(
      name: '红包',
      type: TxType.income,
      iconKey: 'redpacket',
      iconCodepoint: Icons.card_giftcard.codePoint,
      colorBg: '#FAE9EF',
      colorStroke: '#D16B8C',
    ),
    CategorySeed(
      name: '报销',
      type: TxType.income,
      iconKey: 'reimburse',
      iconCodepoint: Icons.receipt_long.codePoint,
      colorBg: '#FBF3E0',
      colorStroke: '#C99A3F',
    ),
    CategorySeed(
      name: '其他',
      type: TxType.income,
      iconKey: 'other_in',
      iconCodepoint: Icons.more_horiz.codePoint,
      colorBg: '#EEF2F0',
      colorStroke: '#9DB3A9',
    ),
  ];

  /// 转账分类（2 个，`type = 3`，P2 预留；P0/P1 不出现在宫格）。
  static final List<CategorySeed> _transferCategories = [
    CategorySeed(
      name: '账户互转',
      type: TxType.transfer,
      iconKey: 'transfer',
      iconCodepoint: Icons.swap_horiz.codePoint,
      colorBg: '#E9EEFB',
      colorStroke: '#6B85D9',
    ),
    CategorySeed(
      name: '信用卡还款',
      type: TxType.transfer,
      iconKey: 'credit_repay',
      iconCodepoint: Icons.credit_card.codePoint,
      colorBg: '#FCEAE5',
      colorStroke: '#E08A6B',
    ),
  ];

  /// 全部 17 个系统分类（按 支出 → 收入 → 转账 顺序）。
  static List<CategorySeed> get allCategories => [
        ..._expenseCategories,
        ..._incomeCategories,
        ..._transferCategories,
      ];

  /// 播种入口：由 `AppDatabase.onCreate` 调用。
  ///
  /// - 1 个默认账本「日常账本」（`is_default = 1`）；
  /// - 17 个系统分类；
  /// - 6 行 pref（`current_book_id` 指向刚插入的默认账本）；
  /// - 1 行 budget（`enabled = 0`）。
  static Future<void> run(DatabaseExecutor db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final bookId = await db.insert(
      'book',
      {
        'name': AppConstants.defaultBookName,
        'icon_key': AppConstants.defaultBookIconKey,
        'icon_color': AppConstants.defaultBookIconColor,
        'sort_order': 0,
        'is_default': 1,
        'created_at': now,
        'updated_at': now,
        'archived': 0,
      },
    );

    final batch = db.batch();

    var sort = 0;
    for (final c in allCategories) {
      batch.insert('category', {
        'name': c.name,
        'type': c.type.code,
        'icon_key': c.iconKey,
        'icon_codepoint': c.iconCodepoint,
        'icon_font_family': 'MaterialIcons',
        'color_bg': c.colorBg,
        'color_stroke': c.colorStroke,
        'sort_order': sort++,
        'is_system': 1,
        'enabled': 1,
        'book_id': null,
      });
    }

    for (final entry in _prefs(bookId, now).entries) {
      batch.insert('pref', {
        'key': entry.key,
        'value': entry.value,
        'updated_at': now,
      });
    }

    batch.insert('budget', {
      'id': 1,
      'monthly_amount_minor': 0,
      'enabled': 0,
      'updated_at': now,
    });

    await batch.commit(noResult: true);
  }

  /// 初始 pref 行（key → value）。
  static Map<String, String> _prefs(int bookId, int now) => {
        AppConstants.prefKeyThemeId: AppConstants.defaultThemeId,
        AppConstants.prefKeyCurrentBookId: '$bookId',
        AppConstants.prefKeyNickname: AppConstants.defaultNickname,
        AppConstants.prefKeyReminderEnabled: '0',
        AppConstants.prefKeyReminderTime: AppConstants.defaultReminderTime,
        AppConstants.prefKeySampleLoaded: '0',
      };

  /// 供迁移 / 修复脚本复用的默认 pref Map（保持与 [_prefs] 一致）。
  static Map<String, String> defaultPrefs(int bookId) =>
      _prefs(bookId, DateTime.now().millisecondsSinceEpoch);
}
