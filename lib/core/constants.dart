/// 应用级常量：数据库名/版本、默认账本、偏好键名、金额上限等。
///
/// 本文件是纯 Dart 常量集合，不依赖 Flutter，可被任意层安全引用。
library;

/// 全局静态常量表。
class AppConstants {
  const AppConstants._();

  // ---------------------------------------------------------------- 数据库
  /// 数据库文件名（落在 `getDatabasesPath()` 下）。
  static const String dbName = 'lightly_record.db';

  /// 当前库版本。任何表结构变更都必须 +1 并在 `Migrations.scripts` 注册增量脚本。
  static const int dbVersion = 1;

  // ---------------------------------------------------------------- 账本
  /// 首次启动播种的默认账本名称。
  static const String defaultBookName = '日常账本';

  /// 默认账本图标语义 key（见 `icons/app_icons.dart`）。
  static const String defaultBookIconKey = 'book';

  /// 默认账本图标色（`#RRGGBB`）。
  static const String defaultBookIconColor = '#3E9F7C';

  // ---------------------------------------------------------------- 数据色兜底
  // 分类 / 账本配色属「数据色」而非主题 Token。默认值集中在 constants.dart
  // （纯 Dart，Model 可安全 import 而不引入 Flutter 依赖）与 seed_data.dart
  // 两处，组件内一律经 hexToColor() 转换，不写字面色值。

  /// 分类图标底色兜底（历史数据缺列 / 分类被删时使用）。
  static const String defaultCategoryColorBg = '#EEF2F0';

  /// 分类图标前景兜底。
  static const String defaultCategoryColorStroke = '#9DB3A9';

  /// 「其他」分类的语义 key。
  static const String otherCategoryKey = 'other_out';

  // ---------------------------------------------------------------- 偏好
  /// 当前主题 id（mint/blue/sand/sakura/lav/dark）。
  static const String prefKeyThemeId = 'theme_id';

  /// 当前账本 id。
  static const String prefKeyCurrentBookId = 'current_book_id';

  /// 用户昵称。
  static const String prefKeyNickname = 'nickname';

  /// 头像在应用私有目录的绝对路径（空 = 未设置，显示默认人像）。
  static const String prefKeyAvatarPath = 'avatar_path';

  /// 记账提醒开关（R23，P2 预留）。
  static const String prefKeyReminderEnabled = 'reminder_enabled';

  /// 记账提醒时间（R23，P2 预留）。
  static const String prefKeyReminderTime = 'reminder_time';

  /// 示例数据是否已载入（防重复载入）。
  static const String prefKeySampleLoaded = 'sample_loaded';

  /// 默认主题 id。
  static const String defaultThemeId = 'mint';

  /// 默认昵称。
  static const String defaultNickname = '轻记用户';

  /// 默认提醒时间。
  static const String defaultReminderTime = '21:00';

  // ---------------------------------------------------------------- 金额
  /// 金额整数部分最多 7 位 → 最大 `9,999,999.99` 元 = 999999999 分。
  static const int maxAmountMinor = 999999999;

  /// 1 元 = 100 分。
  static const int minorPerYuan = 100;

  // ---------------------------------------------------------------- 分页
  /// 列表分页大小（导出/明细懒加载用）。
  static const int pageSize = 50;

  // ---------------------------------------------------------------- 业务
  /// 转账功能开放开关（P2 预留，P0/P1 恒为 false）。
  static const bool transferEnabled = false;

  /// 「今日」问候语等场景使用的中午分界小时。
  static const int noonHour = 12;

  /// 备注最大长度（字）。
  static const int maxNoteLength = 50;
}
