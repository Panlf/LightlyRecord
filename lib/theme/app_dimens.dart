import 'package:flutter/material.dart' show Cubic, Curve;

/// 圆角 / 间距 / 尺寸常量（逐项对齐交互原型）。
class AppDimens {
  const AppDimens._();

  // ---------------------------------------------------------------- 卡片
  /// 卡片圆角 24。
  static const double cardRadius = 24;

  /// 卡片内边距 20。
  static const double cardPadding = 20;

  /// 卡片标题与内容间距 12。
  static const double cardGap = 12;

  /// 次级卡片圆角 20（账本行 / 新建账本）。
  static const double cardRadiusSm = 20;

  /// 三级卡片圆角 18（当日汇总双卡）。
  static const double cardRadiusXs = 18;

  // ---------------------------------------------------------------- 页面
  /// 页面左右安全边距 20。
  static const double pageMargin = 20;

  /// 页面纵向间距 14。
  static const double pageGap = 14;

  // ---------------------------------------------------------------- 交易行
  /// 交易行行高 58。
  static const double txTileHeight = 58;

  /// 交易行图标尺寸 40。
  static const double txIconSize = 40;

  /// 交易行图标圆角 20。
  static const double txIconRadius = 20;

  /// 交易行图标与文字间距 12。
  static const double txGap = 12;

  // ---------------------------------------------------------------- 底部导航
  /// 底部导航总高 95。
  static const double tabBarHeight = 95;

  /// 胶囊导航高 62。
  static const double pillHeight = 62;

  /// 胶囊导航圆角 36。
  static const double pillRadius = 36;

  /// 胶囊内边距 4。
  static const double pillPadding = 4;

  /// 单个 Tab 圆角 26。
  static const double tabRadius = 26;

  /// 胶囊导航左右边距 16。
  static const double pillMargin = 16;

  // ---------------------------------------------------------------- FAB
  /// FAB 直径 54。
  static const double fabSize = 54;

  /// FAB 距右 22。
  static const double fabRight = 22;

  /// FAB 距底 = tabBarHeight + 23。
  static const double fabBottom = tabBarHeight + 23;

  /// FAB 展开后宽度 114。
  static const double fabExpandedWidth = 114;

  /// 收起态右移量 50 → 左缘探出屏幕 26px（给波浪留足展示空间）。
  static const double fabPeekOffset = 50;

  /// 收起态波浪振幅（展开态归零）。
  static const double fabWaveAmplitude = 7;

  /// 波浪周期数（左缘上下两个波峰）。
  static const double fabWaveCycles = 2;

  /// 展开态胶囊圆角（= 高度 / 2）。
  static const double fabRadius = 27;

  // ---------------------------------------------------------------- 分段控件
  /// 大分段高 44。
  static const double segHeight = 44;

  /// 大分段圆角 16。
  static const double segRadius = 16;

  /// 大分段内边距 4。
  static const double segPadding = 4;

  /// 大分段项圆角 12。
  static const double segItemRadius = 12;

  /// 小分段高 36。
  static const double segSmHeight = 36;

  /// 小分段圆角 12。
  static const double segSmRadius = 12;

  /// 小分段内边距 3。
  static const double segSmPadding = 3;

  /// 小分段项圆角 9。
  static const double segSmItemRadius = 9;

  // ---------------------------------------------------------------- 键盘
  /// 键盘键高 52。
  static const double keyHeight = 52;

  /// 键盘键圆角 16。
  static const double keyRadius = 16;

  /// 键盘行间距 10。
  static const double keyGap = 10;

  /// 「完成」键宽倍率（约 2.02）。
  static const double keyDoneFlex = 2.02;

  // ---------------------------------------------------------------- 日历
  /// 日期格行 / 列间距 2。
  ///
  /// **列间距不能是 0**：相邻格子一旦紧贴，选中的实心块就会被有热度底色的
  /// 邻格「续」上去——邻格有底色时边缘看着是直的，没底色（如当天无记录的
  /// 今天）就露出自己的圆角，于是选中块左右边缘时直时圆，像被削了一刀。
  static const double calCellGap = 2;

  /// 日期格高度 50。
  static const double calCellHeight = 50;

  /// 日期格圆角 14。
  static const double calCellRadius = 14;

  // ---------------------------------------------------------------- 分类宫格
  /// 分类宫格列数 4。
  static const int catColumns = 4;

  /// 分类图标 48。
  static const double catIconSize = 48;

  /// 分类图标圆角 24。
  static const double catIconRadius = 24;

  /// 分类选中描边宽度 2。
  static const double catSelectedBorder = 2;

  /// 宫格间距 12。
  static const double catGap = 12;

  /// 分类图标 22（宫格底 48，直径占比约 46%，四周留白不憋屈）。
  static const double catIconGlyph = 22;

  // ---------------------------------------------------- 图标 / 颜色选择器格子
  /// 选择器格子边长 38。
  ///
  /// 必须显式给定尺寸：格子若靠 hug 内部的 20px Icon 决定大小，
  /// 背景圆框就会刚好把图标紧包住，视觉上很憋。
  static const double optionChipSize = 38;

  /// 选择器格子圆角 12。
  static const double optionChipRadius = 12;

  /// 选择器格子里的图标 20。
  static const double optionChipGlyph = 20;

  /// 选择器网格列数 6。
  static const int optionGridColumns = 6;

  /// 选择器网格间距 8。
  static const double optionGridGap = 8;

  // ---------------------------------------------------------------- 图表
  /// 环形图外径 140。
  static const double donutSize = 140;

  /// 环形图环宽 22。
  static const double donutStroke = 22;

  /// 环形图与图例间距 16。
  static const double donutGap = 16;

  /// 柱状图柱组高 96。
  static const double barsHeight = 96;

  /// 柱状图柱间距 8。
  static const double barsGap = 8;

  /// 柱状图圆角（上 8 / 下 4）。
  static const double barRadiusTop = 8;

  /// 柱状图底部圆角 4。
  static const double barRadiusBottom = 4;

  /// 柱状图标签间距 8。
  static const double barLabelGap = 8;

  /// 仪表外径 104。
  static const double gaugeSize = 104;

  /// 仪表半径 44。
  static const double gaugeRadius = 44;

  /// 仪表弧宽 10。
  static const double gaugeStroke = 10;

  // ---------------------------------------------------------------- 开关
  /// 开关宽 48。
  static const double switchWidth = 48;

  /// 开关高 28。
  static const double switchHeight = 28;

  /// 开关滑块 22。
  static const double switchKnob = 22;

  /// 开关滑块位移 20。
  static const double switchKnobShift = 20;

  // ---------------------------------------------------------------- 进度条
  /// 细进度条 6。
  static const double trackThin = 6;

  /// 粗进度条 8。
  static const double trackThick = 8;

  /// 进度条圆角 = 高度 / 2。
  static const double trackRadiusThin = 3;

  /// 粗进度条圆角 4。
  static const double trackRadiusThick = 4;

  // ---------------------------------------------------------------- 账本
  /// 账本图标 44。
  static const double bookIconSize = 44;

  /// 账本图标圆角 14。
  static const double bookIconRadius = 14;

  // ---------------------------------------------------------------- 头像
  /// 我的页头像 56。
  static const double avatarSize = 56;

  /// 通用小头像 36。
  static const double avatarSm = 36;

  // ---------------------------------------------------------------- 弹窗
  /// 弹窗圆角 28。
  static const double dialogRadius = 28;

  /// 弹窗最大宽度 318。
  static const double dialogMaxWidth = 318;

  /// 弹窗遮罩边距 34。
  static const double dialogMaskPadding = 34;

  // ---------------------------------------------------------------- 动画
  /// 右滑入路由时长 320ms。
  static const Duration slideDuration = Duration(milliseconds: 320);

  /// 右滑入曲线（对齐原型 `cubic-bezier(.32,.72,.35,1)`）。
  static const Curve slideCurve = Cubic(0.32, 0.72, 0.35, 1);

  /// 通用过渡 200ms。
  static const Duration animFast = Duration(milliseconds: 200);

  /// 通用过渡 300ms。
  static const Duration animNormal = Duration(milliseconds: 300);

  /// 双击退出判定窗口 2s。
  static const Duration doubleBackWindow = Duration(seconds: 2);

  /// Toast 普通时长 2s。
  static const Duration toastDuration = Duration(seconds: 2);

  /// Toast 圆角 16。
  static const double toastRadius = 16;

  /// Toast 错误时长 2.4s。
  static const Duration toastErrorDuration = Duration(milliseconds: 2400);
}
