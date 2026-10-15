import 'package:flutter/material.dart';

/// 字号 / 字重 / 行高常量（逐项对齐交互原型 px）。
///
/// 全部为逻辑像素；原型 390×844 画布即 1:1 对应。
class AppTypography {
  const AppTypography._();

  /// 金额大数字（记一笔金额卡 40px）。
  static const double bigAmount = 40;

  /// 环形图中心金额 16px。
  static const double donutValue = 16;

  /// 仪表中心数值 17px。
  static const double gaugeValue = 17;

  /// 页头标题 17px。
  static const double pageTitle = 17;

  /// 卡片标题 / 分段标签 15px。
  static const double cardTitle = 15;

  /// 交易行名称 15px。
  static const double txnName = 15;

  /// 交易行金额 15px。
  static const double txnAmount = 15;

  /// 正文 / 标签 13px。
  static const double body = 13;

  /// 图例文字 13px。
  static const double legend = 13;

  /// 交易行备注 12px。
  static const double txnNote = 12;

  /// 图例数值 12px。
  static const double legendValue = 12;

  /// 分段控件（小）标签 12px。
  static const double segSmLabel = 12;

  /// 分类宫格名称 12px。
  static const double catName = 12;

  /// 柱状图标签 11px。
  static const double barLabel = 11;

  /// 日历星期行 11px。
  static const double calDow = 11;

  /// chip / 小字 11px。
  static const double chip = 11;

  /// 日历格内金额 9px。
  static const double calAmount = 9;

  /// 底部导航文字 10px。
  static const double tabLabel = 10;

  /// 账本「使用中」标签 10px。
  static const double tagCur = 10;

  /// 键盘数字 20px。
  static const double keyNumber = 20;

  /// 键盘功能键 16px。
  static const double keyFn = 16;

  /// 分段控件（大）标签 14px。
  static const double segLabel = 14;

  /// 预算输入框 24px。
  static const double budgetInput = 24;

  /// 常规字重。
  static const FontWeight regular = FontWeight.w400;

  /// 中等字重。
  static const FontWeight medium = FontWeight.w500;

  /// 半粗字重。
  static const FontWeight semiBold = FontWeight.w600;

  /// 粗体字重。
  static const FontWeight bold = FontWeight.w700;

  /// 金额数字字体（对齐原型 `Inter`，无资产时回落系统等宽数字）。
  static const String numberFontFamily = 'Inter';

  /// 构造 App 级 [TextTheme]（只定义本项目会用到的样式）。
  static TextTheme textTheme(Color ink) => TextTheme(
        headlineMedium: TextStyle(
          fontSize: pageTitle,
          fontWeight: semiBold,
          color: ink,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: cardTitle,
          fontWeight: semiBold,
          color: ink,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: body,
          fontWeight: medium,
          color: ink,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: body,
          fontWeight: regular,
          color: ink,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: txnNote,
          fontWeight: regular,
          color: ink,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: segLabel,
          fontWeight: medium,
          color: ink,
        ),
        labelMedium: TextStyle(
          fontSize: chip,
          fontWeight: medium,
          color: ink,
        ),
        labelSmall: TextStyle(
          fontSize: tabLabel,
          fontWeight: semiBold,
          color: ink,
        ),
      );

  /// 金额文本样式（数字用等宽字体族，避免跳动）。
  static TextStyle numberStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFamily: numberFontFamily,
        height: height,
        letterSpacing: letterSpacing,
      );
}
